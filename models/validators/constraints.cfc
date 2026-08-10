component singleton {

    // Re-usable constraints

    variables.pathConstraint = {
        required                         : true,
        'fileExistsValidator@ImageMagick': {},
        'noQuotesValidator@ImageMagick'  : {},
        'safePathValidator@ImageMagick'  : {}
    };

    variables.outputPathConstraint = {
        required                       : true,
        'noQuotesValidator@ImageMagick': {},
        'safePathValidator@ImageMagick': {}
    };

    variables.positiveNumericConstraint = {
        required: true,
        type    : 'numeric',
        discrete: 'gt:0'
    };

    // Rules defined by the function's name
    variables.rules = {
        identify     : {path: variables.pathConstraint},
        getDimensions: {path: variables.pathConstraint},
        convert      : {
            path      : variables.pathConstraint,
            outputPath: variables.outputPathConstraint,
            quality   : {type: 'numeric', range: '0..100'},
            resize    : {type: 'numeric', discrete: 'gt:0'},
            strip     : {type: 'boolean'}
        },
        crop: {
            path      : variables.pathConstraint,
            outputPath: variables.outputPathConstraint,
            width     : variables.positiveNumericConstraint,
            height    : variables.positiveNumericConstraint,
            strip     : {type: 'boolean'}
        },
        autoOrient: {path: variables.pathConstraint, outputPath: variables.outputPathConstraint},
        resize    : {
            path   : variables.pathConstraint,
            strip  : {type: 'boolean'},
            outputs: {
                required : true,
                type     : 'array',
                size     : '1..10',
                arrayItem: {
                    type       : 'struct',
                    constraints: {
                        resizeDir: {
                            required                              : true,
                            'directoryExistsValidator@ImageMagick': {},
                            'noQuotesValidator@ImageMagick'       : {},
                            'safePathValidator@ImageMagick'       : {}
                        },
                        width: {
                            'atLeastOneOfValidator@ImageMagick': {otherField: 'height'},
                            type                               : 'numeric',
                            discrete                           : 'gt:0'
                        },
                        height: {type: 'numeric', discrete: 'gt:0'}
                    }
                }
            }
        },
        validateUpload: {
            formField: {required: true},
            strip    : {type: 'boolean'},
            outputs  : {
                required : true,
                type     : 'array',
                size     : '1..10',
                arrayItem: {
                    type       : 'struct',
                    constraints: {
                        uploadDir: {
                            required                              : true,
                            'directoryExistsValidator@ImageMagick': {},
                            'noQuotesValidator@ImageMagick'       : {},
                            'safePathValidator@ImageMagick'       : {}
                        },
                        type: {required: true}
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
                type    = 'ImageMagick.InputValidationException',
                message = 'No constraints defined for function #arguments.functionName#'
            );
        }
        return variables.rules[arguments.functionName];
    }

}
