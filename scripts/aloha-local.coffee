define ['jquery', 'cs!configs/aloha'], ($, AlohaConfig) ->
  $.browser = {}
  $.browser.msie = false
  $.fn.live = $.fn.on # (events, data, handler) -> @on(events, data, handler)

  AlohaConfig.settings.bundles.ghbook = '../../../bookish/scripts/aloha'
