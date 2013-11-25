define [
  'underscore'
  'jquery'
  'backbone'
  'cs!models/content/module'
  'cs!gh-book/xhtml-file'
  'gh-book/googlejsapi'
], (_, $, Backbone, ModuleModel, XhtmlModel) ->

  # Picker Reference: https://developers.google.com/picker/docs/reference

  GDOC_TO_HTML_URL = 'http://testing.oerpub.org/gdoc2html' # eventually `http://remix.oerpub.org/gdoc2html`
  gdocsURL = (id) -> "https://docs.google.com/document/d/#{id}/export?format=html&confirm=no_antivirus"

  # Opens a new Modal Dialog allowing the user to pick a Google Doc to import
  newPicker = () ->
    promise = $.Deferred()

    google.load 'picker', '1',
      callback: () =>
        # Create a new Doc Picker Modal popup and re-ify the promise when
        # 1. a document is selected
        # 2. the dialog is canceled/closed
        builder = new google.picker.PickerBuilder()
        builder.addView(google.picker.ViewId.DOCUMENTS)
        builder.setCallback (data) ->
          switch data.action
            when google.picker.Action.PICKED then promise.resolve(data)
            when google.picker.Action.CANCEL then promise.reject('USER_CANCELLED')
            else
              promise.progress(data)
        picker = builder.build()
        picker.setVisible(true)
        return picker

    return promise.promise()

  # Retreive the HTML of the 1st Google Doc selected in the Picker
  getGoogleDocHtml = (data) ->
    resourceId = data.docs[0].id
    htmlUrl = gdocsURL(resourceId)
    promise = $.get(htmlUrl)
    return promise

  # Clean up HTML retrieved from Google to be used in the Editor.
  # Makes an AJAX call to a service that converts the HTML
  transformGoogleDocHtml = (html) ->
    promise = $.ajax
      url:      GDOC_TO_HTML_URL
      type:     'POST'
      dataType: 'json'
      async:    true
      data:
        html: html
        textbook_html: 0
        copy_images: 0

    return promise

  return class GoogleDocXhtmlModel extends XhtmlModel

    title: 'Google Document Import'

    # **NOTE:** The mediaType is inherited from XhtmlModel because a successful import will
    # 'appear' as a XHTML document.
    # This mediaType is used in the OPF manifest

    # In order to add this type to the Add dropdown for a Book (OPF File)
    # this model must have a unique mediaType (not `application/xhtml+xml`)
    # This is used to register with `media-types` and is in the
    # list of types `opf-file` accepts as a child (so it shows up in the filtered dropdown)
    uniqueMediaType: 'application/vnd.org.cnx.gdoc-import'

    # Saves the fetched and converted Document into this model for saving
    _injectHtml: (html) -> @set('body', html) # html is '<body>...</body>'

    # Pop up the Picker dialog when this Model is added to a book
    _loadComplex: (fetchPromise) ->
      # **NOTE:** `fetchPromise` is not used because this type can only be created as a new object
      #           (the fetchPromise is already resolved)

      promise = newPicker()                   # 1. Open the picker dialog
      .then (data) =>
        return getGoogleDocHtml(data)         # 2. Get the HTML from Google
        .then (html) =>
          return transformGoogleDocHtml(html) # 3. Send the HTML to the transform service
          .then (json) =>
            @_injectHtml(json.html)           # 4. Inject the cleaned HTML into the Model

      promise.fail =>
        console.warn('BUG: Import failed (maybe the user canceled it) and there is no cleanup code')

      return promise
