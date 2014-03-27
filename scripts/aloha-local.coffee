define ['jquery', 'cs!configs/aloha'], ($, AlohaConfig) ->

  $.extend AlohaConfig.settings.bundles,
    ghbook: '../../../bookish/scripts/aloha'

  # Add plugins
  AlohaConfig.settings.plugins.load.push 'common/horizontalruler'
