define [
  'jquery'
  'underscore'
  'backbone'
  'cs!models/content/inherits/base'
], ($, _, Backbone, BaseModel) ->

  # Backbone Collection used to store a container's contents
  class Container extends Backbone.Collection
    initialize: () ->
      @titles = []

    findMatch: (model) ->
      return _.find @titles, (obj) ->
        return model.id is obj.id or model.cid is obj.id

    getTitle: (model) ->
      if model.unique
        return model.get('title')

      return @findMatch(model)?.title or model.get('title')

    setTitle: (model, title) ->
      if model.unique
        model.set('title', title)
      else
        match = @findMatch(model)

        if match
          match.title = title
        else
          @titles.push
            id: model.id or model.cid
            mediaType: model.mediaType
            title: title

        model.trigger('change', model, {})

      return @


  return class ContainerModel extends BaseModel
    mediaType: 'application/vnd.org.cnx.folder'
    accept: []
    unique: true
    branch: true
    expanded: false

    accepts: (mediaType) ->
      if (typeof mediaType is 'string')
        return _.indexOf(@accept, mediaType) is not -1

      return @accept

    initialize: (attrs) ->
      super(attrs)
      # Ensure there is always a Collection in `contents`
      @get('contents') || @set('contents', new Container(), {parse:true})

      contents = @get('contents')

      # When something is added/removed from a Folder or Book mark the Folder/Book as Dirty
      contents.on 'add remove', (model, collection, options) => @_markDirty(options)
      contents.on 'reset',      (collection, options)        => @_markDirty(options)
      contents.on 'change',     (model, options)             =>
        if !options.parse
          @_markDirty(options, true) # force==true because changing the overridden title does not actually mark the model as changed

      @load()

    _loadComplex: (promise) ->
      # This container is not considered loaded until the ALL content container
      # has finished loading.
      # Weird.
      # TODO: Untangle this dependency later
      newPromise = new $.Deferred()

      # Since this is a nested require and `.parse()` depends on all content being loaded
      # We need to squirrel `cs!collections/content` onto the object so parse can use it
      require ['cs!collections/content'], (allContent) =>
        @_ALL_CONTENT_HACK = allContent
        allContent.load().done () =>
          newPromise.resolve(@)

      return newPromise

    getChildren: () -> @get('contents')

    addChild: (models, options) ->
      @getChildren().add(models, options)

    parse: (json) ->
      contents = json.body or json.contents
      titles = []
      if contents
        if not _.isArray(contents)
          contents = parseHTML(contents)
          # Only books can contain overridden titles.
          titles = contents

      else throw 'BUG: Container must contain either a contents or a body'

      # Look up each entry in Contents
      contentsModels = _.map contents, (item) =>
        @_ALL_CONTENT_HACK.get({id: item.id})

      container = @getChildren()
      if container
        container.reset(contentsModels, {parse:true})
        delete json.contents
      else
        container = new Container(contentsModels)
        json.contents = container

      # Set the titles (for a book)
      container.titles = titles

      return json

    # Change the content view when editing this
    contentView: (callback) ->
      require ['cs!views/workspace/content/search-results'], (View) =>
        view = new View({collection: @getChildren()})
        callback(view)

    # Change the sidebar view when editing this
    sidebarView: (callback) ->
      require ['cs!views/workspace/sidebar/toc'], (View) =>
        view = new View
          collection: @getChildren()
          model: @
        callback(view)
