define ['jquery', 'cs!configs/aloha'], ($, AlohaConfig) ->

  $.extend AlohaConfig.settings.bundles,
    ghbook: '../../../bookish/scripts/aloha'

  # Add plugins
  AlohaConfig.settings.plugins.load.push 'common/dom-to-xhtml'
  AlohaConfig.settings.plugins.load.push 'common/horizontalruler'
  AlohaConfig.settings.plugins.load.push 'oer/workarea'

  $.extend AlohaConfig.settings,
    cleanup:
      extra: ($content) ->
        # Plug in extra cleanup steps

        # Remove added meta tags
        $content.find('meta').remove()

        # Remove webkit space preserving tags
        $content.find('span.Apple-converted-space').replaceWith ' '

        # Remove all style attributes
        $content.find('*[style]').each () ->
          $(@).removeAttr('style')

        # Remove font tags
        $content.find('font').each () ->
          $(@).replaceWith(@childNodes)
