define ['jquery', 'cs!configs/aloha'], ($, AlohaConfig) ->

  $.extend AlohaConfig.settings.bundles,
    ghbook: '../../../bookish/scripts/aloha'
