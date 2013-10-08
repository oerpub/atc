define [
  'underscore'
  'jquery'
  'backbone'
  'cs!models/content/module'
  'cs!gh-book/xhtml-file'
  'gh-book/googlejsapi'
], (_, $, Backbone, ModuleModel, XhtmlModel) ->

  GDOC_TO_HTML_URL = 'http://testing.oerpub.org/gdoc2html' # eventually `http://remix.oerpub.org/gdoc2html`
  gdocsURL = (id) -> "https://docs.google.com/document/d/#{id}/export?format=html&confirm=no_antivirus"

  # the cannonical example of how to use google picker includes three functions
  # newPicker(), createPicker(), and pickerCallback(). and so do we except ours
  # includes promises.

  gdocPickerDeferred = undefined

  newPicker = () ->
    google.load('picker', '1', {"callback" : createPicker})
    gdocPickerDeferred = $.Deferred()
    return gdocPickerDeferred.promise()

  createPicker = () ->
    picker = new google.picker.PickerBuilder().
      addView(google.picker.ViewId.DOCUMENTS).
      setCallback(pickerCallback).
      build()
    picker.setVisible(true);
    return picker

  pickerCallback = (data) ->
    # action can be { "cancel", "picked", "received", "loaded", "uploadProgress", "uploadScheduled", "uploadStateChange" }
    if data.action is google.picker.Action.PICKED
        gdocPickerDeferred.resolve(data)
    else if data.action is google.picker.Action.CANCEL
        gdocPickerDeferred.reject()
        console.warn "GOOGLE DOC IMPORT: picker dialog was cancelled"

  getGoogleDocHtml = (data) ->
    gdocResourceId = data.docs[0].id
    htmlUrl = gdocsURL(gdocResourceId)
    gdocHtmlPromise = $.get(htmlUrl)
    gdocHtmlPromise.fail ->
      console.warn "GOOGLE DOC IMPORT: failed to get google doc htmlform google"
    return gdocHtmlPromise

  transformGoogleDocHtml = (html) ->
    gdocTransformPromise = $.ajax(
      dataType: "json"
      type: "POST"
      async: true
      url: GDOC_TO_HTML_URL
      data:
        html: html
        textbook_html: 0
        copy_images: 0
    )
    gdocTransformPromise.fail ->
      console.warn "GOOGLE DOC IMPORT: failed to transform google doc html via remix service"
    return gdocTransformPromise

  # The `Content` model contains the following members:
  #
  # * `title` - an HTML title of the content
  # * `language` - the main language (eg `en-us`)
  # * `subjects` - an array of strings (eg `['Mathematics', 'Business']`)
  # * `keywords` - an array of keywords (eg `['constant', 'boltzmann constant']`)
  # * `authors` - an `Collection` of `User`s that are attributed as authors
  return class GoogleDocXhtmlModel extends XhtmlModel

    title: 'Google Document Import'

    # **NOTE:** The mediaType (`application/xhtml+xml`) is inherited from XhtmlModel 
    # because a successful import will 'appear' as a XHTML document.
    # This mediaType is used in the OPF manifest

    # In order to add this type to the Add dropdown for a Book (OPF File)
    # this model must have a unique mediaType (not `application/xhtml+xml`)
    # This is used to register with `media-types` and is in the 
    # list of types `opf-file` accepts as a child (so it shows up in the filtered dropdown)
    uniqueMediaType: 'application/vnd.org.cnx.gdoc-import'

    _loadComplex: (fetchPromise) ->
      # **NOTE:** `fetchPromise` is not used because this type can only be created as a new object
      #           (the fetchPromise is already resolved)
      gdocImportPromise = @_importGoogleDoc()
      return gdocImportPromise

    # Saves the fetched and converted Document into this model for saving
    _injectHtml: (bodyhtml) ->
      # bodyhtml is "<body>...</body>"
      @set 'body', bodyhtml

    _cleanupFailedImport: () ->
      return

    _importGoogleDoc: () ->
      promise = newPicker()                   # 1. Open the picker dialog
      .then((data) =>
        # alert "google doc selected"
        getGoogleDocHtml data                 # 2. Get the HTML from Google
      ).then((html) =>
        # alert "got html for google doc"
        transformGoogleDocHtml html           # 3. Send the HTML to the transform service
      ).then((json) =>
        # alert "transformed google doc html via remix service"
        @_injectHtml json.html                # 4. Inject the cleaned HTML into the Model
      ).fail(() =>
        console.warn "GOOGLE DOC IMPORT: was not successful"
        @_cleanupFailedImport()
      )
      promise
