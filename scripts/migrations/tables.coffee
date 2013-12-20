define ['jquery', 'require', 'gh-book/xhtml-file'], ($, req, XhtmlFile) ->
  (model) ->
    # We return a promise that is resolved when migration is complete.
    promise = $.Deferred()
    if model.get('mediaType') == XhtmlFile.prototype.mediaType
      # The model itself might not be loaded yet
      model.load().done () ->
        # Look for tables and repair.
        $body = $('<div>').append(model.get('body'))
        $captions = $body.find('table caption')
        if $captions.length
          $captions.remove()
          model.set
              body: $body.html()
        promise.resolve()
    else
      promise.resolve()
    return promise
