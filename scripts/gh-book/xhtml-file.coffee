define [
  'underscore'
  'jquery'
  'backbone'
  'jsSHA'
  'cs!gh-book/uuid'
  'cs!gh-book/binary-file'
  'cs!models/content/module'
  'cs!collections/content'
  'cs!models/utils'
], (_, $, Backbone, jsSHA, uuid, BinaryFile, ModuleModel, allContent, Utils) ->


  # An `<img src>` has the form `data:image/png;base64,.....`.
  # This method splits the src into a usable form and generates a resource path
  # using the hash of the bits.
  #
  # This is called twice:
  #
  # 1. When the body text is changed
  # 2. When the model is serialized
  #
  # The reason it is called twice is because Aloha strips the `data-src` attribute.
  # Since Aloha strips the data-src attribute the only data in the HTML is the
  # Base64-encoded string that represents the image.
  #
  # So, when the body text is changed a new BinaryFile is added to allContent
  # with the path `resources/[HASH][.EXTENSION] which will be PUT on save.
  #
  # And when serializing the XHTML file all `<img src="data:..."/>` elements are translated
  # to `<img src="../resources/[HASH][.EXTENSION]"/>`.
  imgDataSrcToAttributes = (src) ->
    [info, bits] = src.split(',')
    mediaType = info.split(';')[0].split(':')[1]

    # Github will render an image based on the file extension so add it to the id
    switch mediaType
      when 'image/png' then extension = '.png'
      when 'image/jpeg' then extension = '.jpg'
      when 'image/svg' then extension = '.svg'
      else extension = ''

    shaObj = new jsSHA(bits, 'TEXT')
    hash = shaObj.getHash('SHA-1', 'HEX')
    id = "resources/#{hash}#{extension}"
    return {
      id: id
      mediaType: mediaType
      base64Encoded: bits
    }

  xhtmlToDocument = (html) ->
    original = html # Keep a copy before modification
    parser = new DOMParser()

    # The html should be html5 coded xhtml. A doctype is not required, but
    # if the document has xhtml entities it won't parse correctly.
    # Add a doctype only if needed. Only consider first 1000 characters or so
    # of the document, since doctype should be early on, to avoid performance
    # hit when scanning large documents.
    if html.slice(0, 1000).toLowerCase().indexOf('<!doctype') < 0
      # If any entities beyond the allowed html5 ones are used, assume
      # legacy xhtml. The allowed entities are amp, lt, gt, quot and apos.
      # Here we use a negative lookahead assertion. You may have to call a perl
      # coder to explain it.
      if /&(?!(amp|lt|gt|quot|apos))\w+;/.test(html)
        # If the document has an xml declaration, insert right after that.
        # Otherwise insert the DOCTYPE declaration at the beginning.
        html = html.replace(
          /^(\s*<\?xml [^>]*>)?/,
          "$&\n<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>\n"
        )

    doc = parser.parseFromString(html, 'text/xml')

    if $(doc).find('parsererror').length
      # It's possible that the document wasn't valid xhtml. In that case, retry
      # as html. This isn't legal in ebooks, but we provide it here as a
      # convenience.

      # This works in Firefox and maybe a couple of others.
      doc = (new DOMParser).parseFromString(original, "text/html")

      # Chrome (as of version 28) does not support text/html, so we need
      # further hackery
      if doc == null
        # Remove any xml declarations, if this really was XML, we would
        # not be in this situation.
        original = original.replace(/^(\s*<\?xml [^>]*>)?/, '')
        doc = document.implementation.createHTMLDocument ""
        doc.documentElement.innerHTML = original

        # Chrome's XMLSerializer will serialize to HTML if you pass it an
        # HTMLDocument, so instead we clone the contents of the html document
        # and construct an xhtml document.
        xmldoc = document.implementation.createDocument(
          'http://www.w3.org/1999/xhtml', 'html', null)
        $(doc).find('html > *').clone().each (idx, node) ->
          xmldoc.documentElement.appendChild(node)
        return xmldoc
      else
        return doc
    else
      # Chrome litters the entire dom with duplicate ns attributes
      $(doc).find('html *[xmlns="http://www.w3.org/1999/xhtml"]').removeAttr('xmlns')
      return doc

  # The `Content` model contains the following members:
  #
  # * `title` - an HTML title of the content
  # * `language` - the main language (eg `en-us`)
  # * `subjects` - an array of strings (eg `['Mathematics', 'Business']`)
  # * `keywords` - an array of keywords (eg `['constant', 'boltzmann constant']`)
  # * `authors` - an `Collection` of `User`s that are attributed as authors
  return class XhtmlModel extends ModuleModel
    mediaType: 'application/xhtml+xml'

    defaults:
      title: 'Untitled'

    initialize: (options) ->
      super(options)

      # Give the content an id if it does not already have one
      if not @id
        @setNew()
        @id = "content/#{uuid(@get('title'))}#{options.extension || '.html'}"

      # Clear that the title on the model has changed
      # so it does not get saved unnecessarily.
      # The title of the XhtmlFile is not stored inside the file;
      # it is stored in the navigation file

      # Ignore Title changes for now. The canonical title is in the ToC
      # TODO: Re-enable after the sprint
      # @on 'change:title', (model, value, options) =>
      #   head = @get 'head'
      #   $head = jQuery("<div class='unwrap-me'>#{head}</div>")

      #   $head.children('title').text(value)
      #   @set 'head', $head.html(), options

      @on 'change:body', (model, value, options) =>
        return if options.imageupdate # Avoid loops

        doc = xhtmlToDocument(
            '<html><body>' + value + '</body></html>')
        $html = $(doc)

        $error = $html.find('parsererror')
        $images = $html.find('body img[src^="data:"]:not([data-src])')

        # "1. When the body text is changed" (see above)
        # -------------
        # For newly added images (ones without a `data-src` attribute)
        # Create a new BinaryFile
        if $error.length == 0 and $images.length > 0
          $images.each (i, img) =>
            $img = $(img)

            # 'data:image/png;base64,.....'
            src = $img.attr('src')
            attrs = imgDataSrcToAttributes(src)

            # If the resource is not already in allContent then add it
            if not allContent.get(attrs.id)
              imageModel = new BinaryFile(attrs)
              # Make sure the mediaType is set (This may be redundant)
              imageModel.mediaType = attrs.mediaType
              # Set the bits here so isDirty is set to true
              imageModel._markDirty({}, true)

              allContent.add(imageModel)

            # $img.attr('data-src', attrs.id) TODO: Aloha keeps stripping this attribute off.

          @set 'body', $html.find('body')[0].innerHTML?.trim(),
            imageupdate: true

    # Since the titles are purely cosmetic do not mark the model as dirty
    # TODO: Remove this after the sprint
    _markDirty: (options, force=false) ->
      changed = _.omit @changedAttributes(), 'title'
      super(options, force) if not _.isEmpty(changed)

    # This promise is resolved once the file is parsed so we know which images to load
    _imagesLoaded: new $.Deferred()
    _loadComplex: (originalPromise) ->
      return $.when(@_imagesLoaded, originalPromise)

    parse: (json) ->
      # If the parse is a result of a write then update the sha.
      # The parse is a result of a GitHub.write if there is no `.content`
      return {} if not json.content

      html = json.content
      html = "<body>#{html}</body>" if not /<body/.test html
      html = "<html>#{html}</html>" if not /<html/.test html

      # Parse to DOM tree
      doc = xhtmlToDocument(html)
      $html = $(doc)

      $head = $html.find('head')
      $body = $html.find('body')

      # Change the `src` attribute to be a `data-src` attribute if the URL is relative
      $body.find('img').each (i, img) ->
        $imgHolder = jQuery(img)
        src = $imgHolder.attr 'src'

        keepSrc = /^https?:/.test(src) or /^data:/.test(src)
        if not keepSrc
          $imgHolder.attr 'data-src', src
          $imgHolder.removeAttr 'src'

      @loadImages($html)

      attributes =
        head: $head[0]?.innerHTML?.trim() or ''
        body: $body[0]?.innerHTML?.trim() or ''

      # Set the title that is in the `<head>`
      # TODO: Re-enable after the sprint
      # title = $head.children('title').text()
      # attributes.title = title if title

      return attributes

    # Called both by `.parse()` and when making a clone.
    # Done when making a clone because the clone `isNew` so it will not fetch
    # the images.
    loadImages: ($html=null) ->
      if not $html
        doc = xhtmlToDocument(@get('body'))
        $html = $(doc)

      $images = $html.find('body img[data-src]')
      counter = $images.length
      allImages = []

      $images.each (i, img) =>
        $img = jQuery(img)
        deferred = $.Deferred()
        allImages.push(deferred)
        src = $img.attr 'data-src'
        path = Utils.resolvePath @id, src
        imageModel = allContent.get(path)
        if ! imageModel
          console.error "ERROR: Manifest missing image file #{path}"
          counter--
          # Set `parse:true` so the dirty flag for saving is not set
          if counter == 0
            @set 'body',
              $html.find('body')[0].innerHTML?.trim(),
              parse:true, loading:true
          deferred.resolve()
          return

        # Load the image file somehow (see below for my github.js changes)
        doneLoading = imageModel.load()
        .done (bytes, statusMessage, xhr) =>
          # Grab the mediaType from the response header (or look in the EPUB3 OPF file)
          mediaType = imageModel.mediaType # xhr.getResponseHeader('Content-Type').split(';')[0]

          encoded = imageModel.get 'base64Encoded'
          $img.attr('src', "data:#{mediaType};base64,#{encoded}")

          counter--
          # Set `parse:true` so the dirty flag for saving is not set
          if counter == 0
            @set 'body', $html.find('body')[0].innerHTML?.trim(),
              parse:true, loading:true
          deferred.resolve()
        .fail ->
          counter--
          $img.attr('src', 'path/to/failure.png')
          deferred.resolve()

      return $.when.apply(@, allImages).done => @_imagesLoaded.resolve()


    serialize: ->
      head = @get('head') or ''
      body = @get('body') or ''

      xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <head>#{head}</head>
          <body>#{body}</body>
        </html>"""

      doc = xhtmlToDocument(xml)
      $html = $(doc)

      # "2. When the model is serialized" (see above)
      # -------------
      $html.find('body img[src^="data:"]:not([data-src])').each (i, img) =>
        $img = $(img)
        src = $img.attr('src')
        attrs = imgDataSrcToAttributes(src)
        imgAbsolutePath = attrs.id
        # Create a relative path to src
        src = Utils.relativePath(@id, imgAbsolutePath)
        $img.attr 'src', src

      # Replace all the `img[data-src]` attributes with `img[src]`
      $html.find('body img[data-src]').each (i, img) ->
        $img = jQuery(img)
        src = $img.attr('data-src')
        $img.removeAttr('data-src')
        $img.attr('src', src)

      # HACK: For Collaborative edits of the ToC encourage elements to be on multiple lines
      # by inserting newlines between tags
      # headHtml = headHtml.replace(/></g, '>\n<')
      # bodyHtml = bodyHtml.replace(/></g, '>\n<')

      return (new XMLSerializer).serializeToString(doc)

    # Hook to merge local unsaved changes into the remotely-updated model
    onReloaded: (oldContent) ->
      if @get('_isDirty')
        useRemote = confirm("#{@get('title') or @id} was changed by someone else and by you. Do you want to change to the version saved by someone else?")
        if useRemote
          # All the work has already been done
          return false
        else
          # Reparse using the original content plus the new blob sha (leave it unchanged)
          # The {} matches what octokit would return.
          @set @parse({content:oldContent})
          return true
      else
        return false # Does **not** have local changes
