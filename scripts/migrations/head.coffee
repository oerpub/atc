define ['gh-book/xhtml-file'], (XhtmlFile) ->
    return (model) ->
      # We return a promise that is resolved when migration is complete.
      promise = $.Deferred()
      if model.get('mediaType') == XhtmlFile.prototype.mediaType
        model.fetch().done () ->
          orig = model.get('_original')
          if orig and /<head>undefined<\/head>/.test(orig)
            # Re-parse it
            attrs = model.parse({
              content: orig.replace(/<head>undefined<\/head>/, '')
            })
            model.set
              head: attrs.head
              body: attrs.body
            promise.resolve("completed")
          else
            promise.resolve("skipped")
        .fail () ->
          promise.reject()
      else
        # Not an xhtml module, We're done.
        promise.resolve("skipped")
      return promise
