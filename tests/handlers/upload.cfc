component {

    property name="imageService" inject="Helpers@ImageMagick";

    /**
      * Test only endpoint for validasteUpload() through a real multipart HTTP request
      */
    function uploadFile(event, rc, prc) {
        var result = {success: true};

        try {
            var outputs    = structKeyExists(rc, 'outputs') ? deserializeJSON(rc.outputs) : [];
            var extensions = structKeyExists(rc, 'extensions') ? rc.extensions : 'png,jpg,jpeg,webp,heic';

            result.filename = imageService.validateUpload(
                formField  = 'file',
                outputs    = outputs,
                extensions = extensions
            );
        }
        catch(any e) {
            result.success = false;
            result.type    = e.type;
            result.message = e.message;
        }

        event.renderData(type = 'json', data = result);
    }

}
