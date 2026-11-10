component singleton {

    // Re-usable constraints

    variables.pathConstraint = {
        required                         : true,
        "fileExistsValidator@ImageMagick": {},
        "noQuotesValidator@ImageMagick"  : {},
        "safePathValidator@ImageMagick"  : {}
    };

    variables.outputPathConstraint = {
        required                       : true,
        "noQuotesValidator@ImageMagick": {},
        "safePathValidator@ImageMagick": {}
    };

    variables.directoryConstraint = {
        required                              : true,
        "directoryExistsValidator@ImageMagick": {},
        "noQuotesValidator@ImageMagick"       : {},
        "safePathValidator@ImageMagick"       : {}
    };

    // Every extension the service can map to a mime type and detected format
    variables.supportedExtensions = "png,jpg,jpeg,webp,heic,gif,bmp,tif,tiff,svg,avif,ico";

    variables.positiveNumericConstraint = {type: "numeric", discrete: "gt:0"};

    // 0 is ImageMagick's "undefined" quality, which falls back to its default (ex: 92 for JPEG) - so the lowest is 1
    variables.qualityConstraint = {type: "numeric", range: "1..100"};

    // Width/height in pixels - ImageMagick can't size an image to less than 1px
    variables.dimensionConstraint         = {type: "numeric", discrete: "gte:1"};
    variables.requiredDimensionConstraint = {
        required: true,
        type    : "numeric",
        discrete: "gte:1"
    };

    // Rules defined by the function's name
    variables.rules = {
        identify     : {path: variables.pathConstraint},
        getDimensions: {path: variables.pathConstraint},
        convert      : {
            path      : variables.pathConstraint,
            outputPath: variables.outputPathConstraint,
            quality   : variables.qualityConstraint,
            resize    : variables.dimensionConstraint,
            strip     : {type: "boolean"},
            autoOrient: {type: "boolean"}
        },
        crop: {
            path      : variables.pathConstraint,
            outputPath: variables.outputPathConstraint,
            width     : variables.requiredDimensionConstraint,
            height    : variables.requiredDimensionConstraint,
            strip     : {type: "boolean"},
            autoOrient: {type: "boolean"}
        },
        autoOrient: {path: variables.pathConstraint, outputPath: variables.outputPathConstraint},
        resize    : {
            path      : variables.pathConstraint,
            strip     : {type: "boolean"},
            autoOrient: {type: "boolean"},
            outputs   : {
                required : true,
                type     : "array",
                size     : "1..10",
                arrayItem: {
                    type       : "struct",
                    constraints: {
                        resizeDir: variables.directoryConstraint,
                        width    : {
                            "atLeastOneOfValidator@ImageMagick": {otherField: "height"},
                            type                               : "numeric",
                            discrete                           : "gte:1"
                        },
                        height: variables.dimensionConstraint
                    }
                }
            }
        },
        validateUpload: {
            formField  : {required: true},
            extensions : {required: true, "supportedExtensionsValidator@ImageMagick": variables.supportedExtensions},
            strip      : {type: "boolean"},
            autoOrient : {type: "boolean"},
            maxPixels  : variables.positiveNumericConstraint,
            maxFileSize: variables.positiveNumericConstraint,
            quality    : variables.qualityConstraint,
            resize     : variables.dimensionConstraint,
            outputs    : {
                required : true,
                type     : "array",
                size     : "1..10",
                arrayItem: {
                    type       : "struct",
                    constraints: {
                        uploadDir: variables.directoryConstraint,
                        type     : {
                            required                                  : true,
                            "supportedExtensionsValidator@ImageMagick": variables.supportedExtensions
                        }
                    }
                }
            }
        }
    };

    /**
     * Get the constraints based on the function name from the variables.rule struct
     *
     * @functionName The function's name - which has a corresponding rule defined
     */
    public struct function get(required string functionName) {
        if(!structKeyExists(variables.rules, arguments.functionName)) {
            throw(
                type    = "ImageMagick.InputValidationException",
                message = "No constraints defined for function #arguments.functionName#"
            );
        }
        return variables.rules[arguments.functionName];
    }

}
