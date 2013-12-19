define ['jquery', 'gh-book/xhtml-file'], ($, XhtmlFile) ->
  migrateXhtmlFile: (callback) ->
    return (model) ->
      # We return a promise that is resolved when migration is complete.
      promise = $.Deferred()
      if model.get('mediaType') == XhtmlFile.prototype.mediaType
        # The model itself might not be loaded yet, but instead of calling
        # load(), just fetch() it, thereby avoiding the loading of images
        # we don't care about.
        model.fetch().done () ->
          # Load content into a separate document instance
          parser = new DOMParser()
          html = model.get('body')
          html = "<body>#{html}</body>" if not /<body/.test html
          html = "<html>#{html}</html>" if not /<html/.test html

          doc = parser.parseFromString(html, 'text/xml')
          $body = $(doc)
          $body.find('body *[xmlns="http://www.w3.org/1999/xhtml"]').removeAttr('xmlns')

          # DOMParser does not properly throw an exception, but at least chrome
          # and firefox adds a parsererror element to the page.
          if $body.find('parsererror').length
            promise.reject()
            return

          # Call callback here, pass the jquery wrapped doc. Callback modified
          # it in place as required, and returns true if a migration was done.
          serializer = new XMLSerializer()
          if callback($body)
            model.set
                body: serializer.serializeToString(doc)

          promise.resolve()
        .fail () ->
          promise.reject()
      else
        # Not an xhtml module, We're done.
        promise.resolve()
      return promise
