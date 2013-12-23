define [
  'jquery'
  'marionette'
  'cs!collections/content'
  'cs!session'
  'cs!gh-book/remote-updater'
  'hbs!gh-book/auth-template'
  'difflib'
  'diffview'
  'cs!configs/github'
  'bootstrapModal'
  'bootstrapCollapse'
], ($, Marionette, allContent, session, remoteUpdater, authTemplate, difflib, diffview, config) ->

  return class GithubAuthView extends Marionette.ItemView
    template: authTemplate

    events:
      'click #sign-in-ok': 'signIn'
      'click #sign-in': 'signInModal'
      'click #sign-out': 'signOut'
      'click #save-content': 'saveContent'
      'click #fork-content': 'forkContent'
      'submit #login-form': 'signIn'
      'click #show-diffs': 'showDiffsModal'
      'click #edit-repo': 'editRepoModal'
      'submit #edit-repo-form': 'editRepo'
      'click [data-select-repo]': 'selectRepo'

    initialize: () ->
      # When a model has changed (triggered `dirty`) update the Save button
      @listenTo allContent, 'change:_isDirty', (model, value, options) =>
        if value
          @setDirty()
        else
          # This element may have been the only one to have the dirty bit set, and it was just cleared

          # Recalculate the dirty bit
          @isDirty = allContent.some (model) -> model.isDirty()

          @render()
      # Update the Save button when new Folder/Book/Module is created (added to `allContent`)
      @listenTo allContent, 'add remove', (model, collection, options) =>
        @setDirty() if not (options.loading or options.parse)

      @listenTo allContent, 'reset', (collection, options) =>
        # Clear the dirty bit since allContent has been reparsed
        @isDirty = allContent.some (model) -> model.isDirty()


      @listenTo @model, 'change', () => @render()

      # Bind a function to the window if the user tries to navigate away from this page
      $(window).on 'beforeunload', () =>
        return 'You have unsaved changes. Are you sure you want to leave this page?' if @isDirty

      # Since this View is reloaded all the time (whenever a route change occurs)
      # re-set the `isDirty` bit.
      @isDirty = allContent.some (model) -> model.isDirty()

    templateHelpers: () ->
      return {
        defaultRepo: config.defaultRepo
        repoHistory: @model.getHistory()
        isDirty: @isDirty
        isAuthenticated: !! (@model.get('password') or @model.get('token'))
      }


    setDirty: () ->
      @isDirty = true
      @render()

    signInModal: () ->
      $modal = @$el.find('#sign-in-modal')

      # The hidden event on #login-advanced should not propagate
      $modal.find('#login-advanced').on 'hidden', (e) => e.stopPropagation()

      # attach a close listener
      $modal.on 'hidden', () => @trigger 'close'

      # Show the modal
      $modal.modal {show:true}

    # Show a diff of all unsaved models
    showDiffsModal: () ->
      $modal = @$el.find('#diffs-modal')

      $body = $modal.find('.modal-body').empty()

      changedModels = allContent.filter (model) -> model.isDirty()

      for model in changedModels

        if model.isBinary
          $body.append("<div>Binary File: #{model.id}</div>")

        else

          # get the baseText and newText values from the two textboxes, and split them into lines
          base = difflib.stringAsLines(model.get('_original') or '')
          newtxt = difflib.stringAsLines(model.serialize())

          # create a SequenceMatcher instance that diffs the two sets of lines
          sm = new difflib.SequenceMatcher(base, newtxt)

          # get the opcodes from the SequenceMatcher instance
          # opcodes is a list of 3-tuples describing what changes should be made to the base text
          # in order to yield the new text
          opcodes = sm.get_opcodes()

          diffoutputdiv = $('<div></div>').appendTo($body)
          contextSize = 3

          # build the diff view and add it to the current DOM
          diffoutputdiv.append diffview.buildView
            baseTextLines: base
            newTextLines: newtxt
            opcodes: opcodes

            # set the display titles for each resource
            baseTextName: "#{model.get('title') or ''} #{model.id}"
            newTextName: 'changes'
            contextSize: contextSize
            viewType: 1 # inline

      $modal.modal {show:true}


    forkContent: () ->

      if not (@model.get('password') or @model.get('token'))
        alert 'Please Sign In before trying to fork a book'
        return

      @model.getClient().getLogin().done (login) =>
        @model.getRepo()?.fork().done () =>
          @model.set 'repoUser', login

    

    signIn: (e) ->
      # Prevent form submission
      e.preventDefault()

      # Set the username and password in the `Auth` model
      attrs =
        id:       @$el.find('#github-id').val()
        token:    @$el.find('#github-token').val()
        password: @$el.find('#github-password').val()

      if not (attrs.password or attrs.token)
        alert 'We are terribly sorry but github recently changed so you must login to use their API.\nPlease refresh and provide a password or an OAuth token.'
      else
        # Test login first, this also updates login details on the session
        session.authenticate(attrs).done () =>
          @render()

          # The 1st time the editor loads up it waits for the modal to close
          # but `render` will hide the modal without triggering 'close'
          @trigger 'close'
        .fail (err) =>
          alert 'Login failed. Did you use the correct credentials?'

    signOut: () ->
      settings =
        auth:     undefined
        id:       undefined
        password: undefined
        token:    undefined
      @model.set settings, {unset:true}

      @render()

    # Save the collection of media in a single batch
    saveContent: () ->
      $saveBtn = @$('#save-content')
      $saveBtn.addClass('disabled saving')
      promise = allContent.save()
      promise.always () =>
        $saveBtn.removeClass('disabled saving')
      promise.done () =>
        @isDirty = false
        @render()


    # Show the "Edit Settings" modal
    editRepoModal: () ->
      $modal = @$el.find('#edit-repo-modal')

      # Show the modal
      $modal.modal {show:true}

    selectRepo: (e) ->
      # Prevent form submission
      e.preventDefault()

      data = $(e.target).data('selectRepo')

      repoUser = data.repoUser
      repoName = data.repoName

      @_selectRepo(repoUser, repoName)

    # Edit the current repo settings
    editRepo: (e) ->
      # Prevent form submission
      e.preventDefault()

      repoUser = @$el.find('#repo-user').val()
      repoName = @$el.find('#repo-name').val()

      @_selectRepo(repoUser, repoName)

    _selectRepo: (repoUser, repoName) ->
      # Wait until the remoteUpdater has stopped so the settings object does not
      # switch mid-way while updating
      auth = @
      remoteUpdater.stop().always () ->

        branchName = '' # means default branch

        # First check validity of the new repo details. Do this by attempting
        # to read META-INFO/container.xml, which should exist for all real
        # books.
        repo = session.getClient().getRepo(repoUser, repoName)
        branch = branchName and repo.getBranch(branchName) or repo.getDefaultBranch()
        branch.read('META-INF/container.xml').fail () ->
          auth.$el.find('[data-repo-missing]').show()
          auth.editRepoModal()
        .then () ->
          # Silently clear the settings first. This forces a reload even if
          # the user leaves the settings unchanged.  The reason for
          # **forcing** a reload is because this modal is also shown when
          # there is a connection problem loading the workspace.
          auth.model.set {repoUser:'', repoName:'', branch:''}, {silent:true}

          auth.model.setRepo repoUser, repoName, branchName

          remoteUpdater.start().done () =>
            auth.trigger 'close'
            auth.model.trigger 'settings-changed'
