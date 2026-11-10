component {

    property name="imageService" inject="Helpers@ImageMagick";

    /**
      * Test only endpoint for validateUpload() through a real multipart HTTP request
      * Any optional validateUpload() argument posted as a form field is passed through, otherwise its default applies
      */
    function uploadFile(event, rc, prc) {
        var result = {success: true};

        try {
            var args = {formField: "file", outputs: structKeyExists(rc, "outputs") ? deserializeJSON(rc.outputs) : []};
            for(
                var name in [
                    "extensions",
                    "strip",
                    "autoOrient",
                    "maxPixels",
                    "maxFileSize",
                    "quality",
                    "resize"
                ]
            ) {
                if(structKeyExists(rc, name)) {
                    args[name] = rc[name];
                }
            }

            result.filename = imageService.validateUpload(argumentCollection = args);
        }
        catch(any e) {
            result.success = false;
            result.type    = e.type;
            result.message = e.message;
            result.detail  = e.detail;
        }

        event.renderData(type = "json", data = result);
    }

}
