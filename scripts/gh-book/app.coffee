define [
  'jquery'
  'underscore'
  'backbone'
  'marionette'
  'cs!helpers/logger'
  'cs!session'
  'cs!collections/content'
  'cs!collections/media-types'
  'cs!gh-book/epub-container'
  'cs!gh-book/xhtml-file'
  'cs!gh-book/opf-file'
  'cs!gh-book/binary-file'
  'cs!gh-book/auth'
  'cs!gh-book/remote-updater'
  'cs!gh-book/loading'
  'less!styles/main'
  'less!gh-book/gh-book'
], ($, _, Backbone, Marionette, logger, session, allContent, mediaTypes, EpubContainer, XhtmlFile, OpfFile, BinaryFile, WelcomeSignInView, remoteUpdater, LoadingView) ->

  # Stop logging.
  logger.stop()

  # Singleton that gets reloaded when the repo changes
  epubContainer = new EpubContainer()

  allContent.on 'add', (model, collection, options) ->
    return if options.loading

    # If the new model is a book then add it to epubContainer
    # Otherwise, add it to the manifest for all the books (Better safe than sorry)
    switch model.mediaType
      when OpfFile::mediaType
        epubContainer.addChild(model)
      else
        allContent.each (book) ->
          book.manifest?.add(model) # Only books have a manifest


  # The WelcomeSignInView is overloaded to show Various Dialogs.
  #
  # - SignIn
  # - Repo Settings
  #
  # When there is a failure show the Settings/SignIn Modal
  welcomeView = new WelcomeSignInView {model:session}



  # This is a utility that wraps a promise and alerts when the promise fails.
  onFail = (promise, message='There was a problem.') ->
    complete = 0
    total = 0

    promise.progress (msg) =>
      switch msg.type
        when 'start'  then total++
        when 'end'    then complete++
      console.log "Progress: #{complete}/#{total}: ", msg

    return promise.fail (err) =>
      repoUser = session.get('repoUser')
      repoName = session.get('repoName')
      branch = session.get('branch') or ''
      branch = "##{branch}" if branch

      # Show the WelcomeView's settings modal if there was a connection problem
      try
        App.main.show(welcomeView)
        welcomeView.editSettingsModal(message)
      catch err
        alert("#{message} Are you pointing to a valid book? Using github/#{repoUser}/#{repoName}#{branch}")


  App = new Marionette.Application()

  App.addRegions
    main: '#main'


  App.addInitializer (options) ->

    # Register media types for editing
    mediaTypes.add EpubContainer
    mediaTypes.add XhtmlFile
    mediaTypes.add OpfFile
    mediaTypes.add BinaryFile, {mediaType:'image/png'}
    mediaTypes.add BinaryFile, {mediaType:'image/jpeg'}


    # Views use anchors with hrefs so catch the click and send it to Backbone
    $(document).on 'click', 'a:not([data-bypass])', (e) ->
      external = new RegExp('^((f|ht)tps?:)?//')
      href = $(@).attr('href')

      e.preventDefault()

      if external.test(href)
        window.open(href, '_blank')
      else
        if href then Backbone.history.navigate(href, {trigger: true})


    # Populate the Session Model from localStorage
    STORED_KEYS = ['repoUser', 'repoName', 'branch', 'id', 'password', 'token']
    props = {}
    _.each STORED_KEYS, (key) ->
      value = window.sessionStorage.getItem key
      props[key] = value if value
    session.set props

    # On change, store info to localStorage
    session.on 'change', () =>
      # Update session storage
      for key in STORED_KEYS
        value =  session.get key
        if value
          window.sessionStorage.setItem key, value
        else
          window.sessionStorage.removeItem key, value



    # Github read/write and repo configuration

    writeFile = (path, text, commitText, isBase64) ->
      # .write expects the text to be base64 encoded so no need to convert it
      session.getBranch().write path, text, commitText, isBase64

    readFile = (path, isBinary) -> session.getBranch().read path, isBinary
    readDir =        (path) -> session.getBranch().contents   path


    Backbone.sync = (method, model, options) ->

      path = model.id or model.url?() or model.url

      console.log method, path
      ret = null
      switch method
        when 'read' then ret = readFile(path, model.isBinary)
        when 'update' then ret = writeFile(path, model.serialize(), 'Editor Save', model.isBinary)
        when 'create'
          # Create an id if this model has not been saved yet
          id = _uuid()
          model.set 'id', id
          ret = writeFile(path, model.serialize(), model.isBinary)
        else throw "Model sync method not supported: #{method}"

      ret.done (value) => options?.success?(value)
      ret.fail (error) => options?.error?(ret, error)
      return ret


  App.on 'start', () ->

    startRouting = () ->
      # Remove cyclic dependency. Controller depends on `App.main` region
      require ['cs!controllers/routing'], (controller) =>

        # Tell the controller which region to put all the views/layouts in
        controller.main = App.main

        # Custom routes to configure the Github User and Repo from the browser
        router = new class GithubRouter extends Backbone.Router

          setDefaultRepo = () ->
            if not session.get('repoName')
              DEFAULT_CONFIG =
                'repoUser': 'Connexions'
                'repoName': 'atc'
                'branch'  : 'sample-book'
              options = {}
              options.silent = true if not 'id' and not 'token'
              session.set DEFAULT_CONFIG, options


          routes:
            'repo/:repoUser/:repoName':         'configRepo'
            'repo/:repoUser/:repoName/:branch': 'configRepo'

            '':             'goDefault'
            'workspace':    'goWorkspace'
            'edit/:id':     'goEdit' # Edit an existing piece of content (id can be a URL-encoded path)

          _loadFirst: () ->
            setDefaultRepo()
            promise = onFail(remoteUpdater.start(), 'There was a problem starting the remote updater')
            .then () =>
              return onFail(epubContainer.load(), 'There was a problem loading the repo')

            App.main.show(new LoadingView {model:epubContainer, promise:promise})
            return promise

          configRepo: (repoUser, repoName, branch='') ->
            session.set
              repoUser: repoUser
              repoName: repoName
              branch:   branch

            # The app listens to session onChange events and will call .goDefault
            # It listens to 'change' because the auth view may also change the session


          # Delay the route handling until the initial content is loaded
          # TODO: Move this into the controller
          goWorkspace: () ->
            @_loadFirst().done () => controller.goWorkspace()
          goEdit: (id)    ->
            @_loadFirst().done () => controller.goEdit(id)
          goDefault: () ->
            @_loadFirst().done () => controller.goDefault()


        session.on 'change', () =>
          if not _.isEmpty _.pick(session.changed, ['repoUser', 'repoName', 'branch'])
            remoteUpdater.stop()
            onFail(epubContainer.reload(), 'There was a problem re-loading the repo')
            router.goDefault()


        Backbone.history.start
          pushState: false
          hashChange: true
          root: ''



    # If localStorage does not contain a password or OAuth token then show the SignIn modal.
    # Otherwise, load the workspace
    if session.get('password') or session.get('token')
      # Use the default book if one is not already set
      if not session.get 'repoName'
        session.set
          'repoUser': 'Connexions'
          'repoName': 'atc'
          'branch'  : 'sample-book'
      startRouting()
    else
      # The user has not logged in yet so pop up the modal
      welcomeView.once 'close', () =>
        # Use the default book if one is not already set
        if not session.get 'repoName'
          session.set
            'repoUser': 'Connexions'
            'repoName': 'atc'
            'branch'  : 'sample-book'
        startRouting()
      App.main.show(welcomeView)
      welcomeView.signInModal()

  return App
