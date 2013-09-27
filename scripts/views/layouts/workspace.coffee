define [
  'marionette'
  'hbs!templates/layouts/workspace'
], (Marionette, workspaceTemplate) ->

  # This layout looks as follows:
  #
  #     |    [menu: Home, Toolbar, Signin/Signout]    |
  #     | ------------------------------------------- |
  #     |                                             |
  #     | ----------- | --------- | ------------------|
  #     |          X  |        X  |                   |
  #     |             |           |                   |
  #     | [workspace] | [sidebar] | [content]         |
  #     |             |           |                   |
  #     | ----------- | --------- | ------------------|
  #
  # The `minimized` class is added to the `*-container`
  # element when the `X` is pressed.
  #
  # Collapsing the views this way is done because:
  #
  # - CSS transitions can be applied to move the view
  # - The controller only needs to show/close a view to change the current Book pane (`sidebar`)
  #   it does not need to know about the current expanded/collapsed state of the pane
  #
  return class Workspace extends Marionette.Layout
    template: workspaceTemplate

    regions:
      content: '#content'
      menu: '#menu'
      sidebar: '#sidebar'
      workspace: '#workspace'

    events:
      'click #workspace-container > .pickerswitch': 'toggleWorkspace'
      'click #sidebar-container > .pickerswitch': 'toggleToc'

    initialize: () ->
      @workspace.on 'show', =>
        @$('#workspace-container').removeClass('tocminimized').removeClass('wsminimized')

    toggleWorkspace: () -> @$('#workspace-container').toggleClass('wsminimized')
    toggleToc: () -> @$('#workspace-container').toggleClass('tocminimized')
    showWorkspace: (b=true) ->
      if b
        @$('#workspace-container').removeClass('wsminimized')
      else
        @$('#workspace-container').addClass('wsminimized')
    showToc: (b=true) ->
      if b
        @$('#workspace-container').removeClass('tocminimized')
      else
        @$('#workspace-container').addClass('tocminimized')
