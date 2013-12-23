define [
  'backbone'
  'cs!collections/media-types'
  'cs!collections/content'
  'cs!mixins/loadable'
  'cs!models/utils'
  'cs!gh-book/xhtml-file'
  'cs!gh-book/toc-node'
  'cs!gh-book/toc-pointer-node'
  'cs!gh-book/uuid'
  'hbs!templates/gh-book/defaults/opf'
  'hbs!templates/gh-book/defaults/nav'
], (
  Backbone,
  mediaTypes,
  allContent,
  loadable,
  Utils,
  XhtmlFile,
  TocNode,
  TocPointerNode,
  uuid,
  defaultOpf,
  defaultNav) ->

  SAVE_DELAY = 10 # ms

  # Mix in the loadable
  return class PackageFile extends (TocNode.extend loadable)
    serializer = new XMLSerializer()

    mediaType: 'application/oebps-package+xml'
    accept: [XhtmlFile::mediaType, TocNode::mediaType]

    branch: true # This element will show up in the sidebar listing

    initialize: (options) ->
      options.root = @


      @$xml = $($.parseXML defaultOpf(options))

      # Give the content an id if it does not already have one
      if not @id
        @setNew()
        @id = "content/#{uuid(@get('title'))}.opf"

     # For TocNode, let it know this is the root
      super options

      # Contains all entries in the OPF file (including images)
      @manifest = new Backbone.Collection()
      # Contains all items in the ToC (including internal nodes like "Chapter 3")
      @tocNodes = new Backbone.Collection()
      @tocNodes.add @

      # Use the `parse:true` option instead of `loading:true` because
      # Backbone sets this option when a model is being parsed.
      # This way we can ignore firing events when Backbone is parsing as well as
      # when we are internally updating models.
      setNavModel = (options) =>
        if not options.doNotReparse
          options.doNotReparse = true
          @navModel.set 'body', @_serializeNavModel(), options

          # if we're updating the nav the spine also probably needs to be updated
          @_buildSpine()

      @tocNodes.on 'add', (model, collection, options) =>
        if not options.doNotReparse
          # Keep track of local changes if there is a remote conflict
          @_localNavAdded[model.id] = model


      # If a node was added-to/removed-from a TocNode ensure it is/is-not in the set of `tocNodes`
      # TODO: This may be redundant and may be able to be removed
      @tocNodes.on 'tree:add',    (model, collection, options) => @tocNodes.add model, options
      @tocNodes.on 'tree:remove', (model, collection, options) => @tocNodes.remove model, options

      # When the book title changes update the OPF XML
      # TODO: use the value of `@get('title')` when serializing instead.
      @on 'change:title', (model, value, options) =>
        $title = @$xml.find('title')
        if value != $title.text()
          $title.text(value)
          @_save()

      # When a title changes on one of the nodes in the ToC:
      #
      # 1. remember the change
      # 2. try to autosave
      # 3. if a remote conflict occurse the remembered change will be replayed (see `onReloaded`)
      @tocNodes.on 'change:title', (model, value, options) =>
        return if not model.previousAttributes()['title'] # skip if we are parsing the file
        return if @ == model # Ignore if changing the OPF title
        # the `change:title` event "trickles up" through the nodes (probably should not)
        # so only save once.
        if @_localTitlesChanged[model.id] != value
          @_localTitlesChanged[model.id] = value
          @_save()

      @getChildren().on 'add remove tree:change tree:add tree:remove', (model, collection, options) =>
        setNavModel(options)
      @getChildren().on 'change reset', (collection, options) =>
        # HACK: `?` is because `inherits/container.add` calls `trigger('change')`
        setNavModel(options)

      @manifest.on 'add', (model, collection, options) => @_addItem(model, options)

      # These store the added items since last successful save.
      # If this file was remotely updated then, when resolving conflicts,
      # these items will be added back into the newly-updated OPF manifest
      @_localAddedItems = {}
      @_localNavAdded = {}
      @_localTitlesChanged = {}

      # save opf files on creation
      @_save() if @_isNew

    # return null so `TocPointerNode.getRoot()` returns the OPF file instead of the EPUBContainer for new books
    # HACK because when a new book is added to EPUBComtainer the parent is set.
    # Then, in toc-branch, goEdit uses model.getRoot() to determine what to render in the sidebar
    getParent: () -> null

    # Add an `<item>` to the OPF.
    # Called from `@manifest.add` and `@resolveSaveConflict`
    _addItem: (model, options={}, force=true) ->
      $manifest = @$xml.find('manifest')

      relPath = Utils.relativePath(@id, model.id)

      # Check if the item is not already in the manifest
      return if $manifest.find("item[href='#{relPath}']")[0]

      # Create a new `<item>` in the manifest
      item = @$xml[0].createElementNS('http://www.idpf.org/2007/opf', 'item')
      $item = $(item)
      $item.attr
        href:         relPath
        id:           relPath # TODO: escape the slashes so it is a valid id
        'media-type': model.mediaType
        properties:  "mathml scripted"

      if options.properties
        $item.attr 'properties', options.properties
        delete options.properties

      $manifest.append($item)
      # TODO: Depending on the type add it to the spine for EPUB2

      @_markDirty(options, force)

      # Push it to the set of items that were added since last save.
      # This is useful when the OPF file was remotely updated
      @_localAddedItems[model.id] = model

    # Called on "autosave".
    # Only save the navModel and new files (and all the OPF files).
    # Delay the save and if more than one thing changed during SAVE_DELAY
    # only save once.
    #
    # Reason for SAVE_DELAY: a "move" is 2 operations, `remove` followed by `add`
    _save: ->

      # this is a new book, set some default elements
      if not @navModel
        #create the default nav file
        @navModel = new XhtmlFile {title: @get('title'), extension: '-nav.html'}
        @navModel.set('body', defaultNav())

        # add the new navModel to our opf and the allcontent container
        @_addItem(@navModel, {properties: 'nav'})
        allContent.add(@navModel)

        #create empty module for the book
        module = new XhtmlFile {title: 'module1'}
        allContent.add(module)
        @addChild(module) # for the nav file
        @_addItem(module) # for this opf file


      clearTimeout(@_savingTimeout)
      @_savingTimeout = setTimeout (() =>
        allContent.save(@navModel, false, true) # include-resources, include-new-files
        delete @_savingTimeout
      ), SAVE_DELAY

    # A book is not loaded until the navModel is loaded.
    # Once the navModel is loaded, "autosave" whenever it changes.
    _loadComplex: (fetchPromise) ->
      fetchPromise
      .then () =>
        # Clear that anything on the model has changed
        @changed = {}
        return @navModel.load()
      .then () =>
        @_parseNavModel()
        @listenTo @navModel, 'change:body', (model, value, options) =>
          @_parseNavModel() if not options.doNotReparse

        # Autosave whenever something in the ToC changes (not the dirty bits)
        @listenTo @navModel, 'change', (model, options) =>
          return if options.parse
          if not _.isEmpty _.omit model.changedAttributes(), ['_isDirty', '_hasRemoteChanges', '_original', 'dateLastModifiedUTC']
            # Delay the save a little bit because a move is a remove + add
            # which would otherwise cause 2 saves
            @_save()


    _parseNavModel: () ->
      $body = $(@navModel.get 'body')
      $body = $('<div></div>').append $body


      # Generate a tree of the ToC
      recBuildTree = (collection, $rootOl, contextPath) =>
        $rootOl.children('li').each (i, li) =>
          $li = $(li)

          # Remember attributes (like `class` and `data-`)
          attributes = Utils.elementAttributes $li

          # If the node contains a `<span>` then it is a container node
          # If the node contains a `<a>` then we currently only support them as leaves
          $a = $li.children('a')
          $span = $li.children('span')
          $ol = $li.children('ol')
          if $a[0]
            # Look up the href and add the piece of content
            title = $a.text()
            href = $a.attr('href')

            path = Utils.resolvePath(contextPath, href)
            contentModel = allContent.get(path)
            # Because of remotely adding a new file and reloading files async
            # it may be the case that the navigation document
            # (containing a link to the new XhtmlFile)
            # reloads before the OPF file reloads (containing the <item> which updates allContent)
            # so we cannot assume the model is already in `allContent`
            #
            # In that case, just add a "shallow" model to allContent
            if not contentModel
              contentModel = allContent.model
                mediaType: XhtmlFile::mediaType
                id: path
              allContent.add(contentModel)

            # Set all the titles of models in the workspace based on the nav tree
            # XhtmlModel titles are not saved anyway.
            contentModel.set 'title', title, {parse:true} # if not contentModel.get('title')

            model = @newNode {title: title, htmlAttributes: attributes, model: contentModel}

            collection.add model, {doNotReparse:true}

          else if $span[0]
            model = new TocNode {title: $span.text(), htmlAttributes: attributes, root: @}

            # Recurse and then add the node. that way we reduce the number of notifications
            recBuildTree(model.getChildren(), $ol, contextPath) if $ol[0]
            collection.add model, {doNotReparse:true}

          else throw 'ERROR: Invalid Navigation Tree Structure'

          # Add the model to the tocNodes so we can listen to changes and update the ToC HTML
          @tocNodes.add model, {doNotReparse:true}


      $root = $body.find('nav > ol')
      @tocNodes.reset [@], {doNotReparse:true}
      @getChildren().reset([], {doNotReparse:true})
      recBuildTree(@getChildren(), $root, @navModel.id)

    _buildSpine: ->
      
      start = @serialize()
      spine = @$xml.find('spine').empty()

      update = (model) =>
        if model.mediaType == XhtmlFile::mediaType
          $('<itemref />')
            .attr('idref', Utils.relativePath(@id, model.id))
            .appendTo(spine)
         
        if model.getChildren?().first()
          model.getChildren().forEach update
      
      @getChildren().forEach update

      @_markDirty({}) if start != @serialize()

    _serializeNavModel: () ->
      $body = $(@navModel.get 'body')
      $wrapper = $('<div></div>').append $body
      $nav = $wrapper.find 'nav'
      $nav.empty()

      $navOl = $('<ol></ol>')

      recBuildList = ($rootOl, model) =>
        $li = $('<li></li>')
        $rootOl.append $li

        switch model.mediaType
          when XhtmlFile::mediaType
            path = Utils.relativePath(@navModel.id, model.id)
            $node = $('<a></a>')
            .attr('href', path)
            # Use `.toJSON().title` instead of `.get('title')` to support
            # TocPointerNodes which inherit their title if it is not overridden
            .text(model.toJSON().title)
          else
            $node = $('<span></span>')
            $li.attr(model.htmlAttributes or {})

        title = model.getTitle?() or model.get 'title'
        $node.html(title)
        $li.append $node

        if model.getChildren?().first()
          $ol = $('<ol></ol>')
          # recursively add children
          model.getChildren().forEach (child) => recBuildList($ol, child)
          $li.append $ol

      @getChildren().forEach (child) => recBuildList($navOl, child)
      $nav.append($navOl)
      # Trim the HTML and put newlines between elements
      html =  $wrapper.html()
      html = html.replace(/></g, '>\n<')
      return html


    parse: (json) ->
      xmlStr = json.content

      # If the parse is a result of a write then update the sha.
      # The parse is a result of a GitHub.write if there is no `.content`
      return {} if not json.content

      @$xml = $($.parseXML xmlStr)

      # If we were unable to parse the XML then trigger an error
      return model.trigger 'error', 'INVALID_OPF' if not @$xml[0]

      # For the structure of the TOC file see `OPF_TEMPLATE`
      # An epub must contain an IDREF to the dublincore element that has the
      # identification information. The `identifer` fallback is there to handle
      # books created while a misspelling was in place.
      IdAttr = @$xml[0].firstChild.getAttribute('unique-identifier') or
        @$xml[0].firstChild.getAttribute('unique-identifer')

      # Use querySelectorAll (because firefox breaks with jquery) to find the
      # value of the referenced unique identifier.
      bookIds = @$xml[0].querySelectorAll("##{IdAttr}")
      bookId = bookIds.length and $(bookIds[0]).text() or ''

      # Explicitly use querySelectorAll, because firefox fails to find the
      # title if you just use jQuery.find().
      titles = @$xml[0].querySelectorAll('title')
      title = titles.length and $(titles[0]).text() or ''

      # The manifest contains all the items in the spine
      # but the spine element says which order they are in

      @$xml.find('package > manifest > item').each (i, item) =>
        $item = $(item)

        # Add it to the set of all content and construct the correct model based on the mimetype
        mediaType = $item.attr 'media-type'
        relPath = $item.attr 'href'
        absPath = Utils.resolvePath(@id, relPath)

        # Try to get the navModel if it already exists in `allContent`.
        # Otherwise create it
        model = allContent.get(absPath)
        if not model
          model = allContent.model
            # Set the path to the file to be relative to the OPF file
            id: absPath
            mediaType: mediaType
            properties: $item.attr 'properties'

        # Add it to the manifest and then do a batch add to `allContent`
        # at the end so the views do not re-sort on every add.
        @manifest.add model, {loading:true}

        # If we stumbled upon the special navigation document
        # then remember it.
        if 'nav' == $item.attr('properties')
          @navModel = model
          @_monkeypatch_navModel(@navModel)

      # Add all the models in one batch so views do not re-sort on every add.
      allContent.add @manifest.models, {loading:true}

      # Ignore the spine because it is defined by the navTree in EPUB3.
      # **TODO:** Fall back on `toc.ncx` and then the `spine` to create a navTree if one does not exist
      return {
        title: title
        bookId: bookId
      }

    serialize: () ->
      serializer.serializeToString(@$xml[0])

    # Resolves conflicts between changes to this model and the remotely-changed
    # new attributes on this model.
    onReloaded: () ->
      for model in _.values(@_localAddedItems)
        @_addItem(model, {}, false)

      isDirty = not _.isEmpty(@_localAddedItems)
      return isDirty


    onSaved: () ->
      super()
      @_localAddedItems = {}
      @_localTitlesChanged = {}

    # FIXME HACK, horrible Hack.
    # When a remote commit occurs, all models that were changed are reloaded.
    # The order they are reloaded is non-deterministic and a "Book"
    # is actually represented by 2 files: the OPF and the navigation HTML.
    # This patch ensures the navigation file is updated.
    _monkeypatch_navModel: () ->

      # Resolves conflicts between changes to this model and the remotely-changed
      # new attributes on this model.
      onReloaded = () =>
        @_parseNavModel()
        _.each @_localNavAdded, (model, path) => @addChild(model)

        isDirty = not _.isEmpty(@_localNavAdded)

        # Merge in the local title changes for items still in the ToC
        _.each @_localTitlesChanged, (title, id) =>
          model = @tocNodes.get(id)
          model?.set('title', title, {parse:true})

        isDirty = isDirty or not _.isEmpty(@_localTitlesChanged)

        return isDirty

      onSaved = () =>
        # Call 'Saveable.onSave' (super)
        XhtmlFile::onSaved.bind(@navModel)()

        @_localNavAdded = {}
        @_localTitlesChanged = {}

      @navModel.onReloaded = onReloaded
      @navModel.onSaved = onSaved

    # Override the tree's removeMe (which just asks the parent to remove the child)
    removeMe: ->
      require ['cs!gh-book/epub-container'], (EpubContainer) =>
        EpubContainer::instance().removeChild(@)
        allContent.save()

    newNode: (options) ->
      model = options.model
      node = @tocNodes.get model.id
      if !node
        node = new TocPointerNode {root:@, model:model}
        #@tocNodes.add node
      return node

    # Do not change the contentView when the book opens
    contentView: null

    # Change the sidebar view when editing this
    sidebarView: (callback) ->
      require ['cs!views/workspace/sidebar/toc'], (View) =>
        view = new View
          collection: @getChildren()
          model: @
        callback(view)
