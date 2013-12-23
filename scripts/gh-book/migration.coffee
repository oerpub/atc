define [
  'jquery'
  'marionette'
  'cs!collections/content'
  'hbs!gh-book/migration-template'
], ($, Marionette, allContent, migrationTemplate) ->

  return class Migration extends Marionette.ItemView
    template: migrationTemplate

    initialize: (options) ->
      @task = options.task

    onShow: () ->
      # Lazily hiding the bits we don't need
      @$el.parents('.content-panel').first().find('#editor-title-text').hide()
      $loadingBar = @$el.find('#loading-bar')
      $loadingText = @$el.find('#loading-text')
      $log = @$el.find('#migrationlog')

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
              migrateModels = (queue) ->
                return if not queue.length
                model = queue.shift()

                # migrate the module. Pull in the requested task and pass
                # the module to it.
                $line = $("<p>Migrating #{model.id} ... <span> </span></p>")
                $log.append($line)
                resolve = (cls, tt) ->
                  migrated++
                  percentage = 100 * migrated / total
                  $loadingBar.attr('style', "width: #{percentage}%;")
                  @addClass(cls)
                  if tt
                    @find('span').popover
                      html: true
                      title: 'Error'
                      content: tt
                      placement: 'right'
                      trigger: 'hover'
                resolve = resolve.bind($line)

                f(model).done () ->
                  resolve('success')
                .fail (err) ->
                  resolve('fail', err)
                  $loadingBar.addClass('bar-danger')
                .always () ->
                  migrateModels(queue)

              # Start the migration
              migrateModels(allContent.slice())
        else
          $loadingText.html("Invalid migration task")
      else
        $loadingText.html("Choose a migration task")
