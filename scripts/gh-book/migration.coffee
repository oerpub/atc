define [
  'marionette'
  'cs!collections/content'
  'hbs!gh-book/migration-template'
], (Marionette, allContent, migrationTemplate) ->

  return class Migration extends Marionette.ItemView
    template: migrationTemplate

    initialize: (options) ->
      @task = options.task

    onShow: () ->
      # Lazily hiding the bits we don't need
      @$el.parents('.content-panel').first().find('#editor-title-text').hide()
      $loadingBar = @$el.find('#loading-bar')
      $loadingText = @$el.find('#loading-text')

      if @task
        $loadingText.html("Running migration for #{@task}")
        # Check task for funny characters, because we're about to feed it
        # as a path into the coffeescript compiler.
        if /^[A-Za-z-_]+$/.test @task
          allContent.load().done () =>
            total = allContent.length
            migrated = 0

            # We iterate through all content. Tasks must check the type
            # of model passed to it. This allows us to write tasks that
            # migrate any type of content.
            require ["cs!migrations/#{@task}"], (f) ->
              allContent.forEach (model) ->
                # migrate the module. Pull in the requested task and pass
                # the module to it.
                f(model).done () ->
                  migrated++
                  percentage = 100 * migrated / total
                  $loadingBar.attr('style', "width: #{percentage}%;")
                .fail () ->
                  $loadingText.text('There was a problem migrating the book.')
        else
          $loadingText.html("Invalid migration task")
      else
        $loadingText.html("Choose a migration task")
