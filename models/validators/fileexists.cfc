component singleton {

    property name="safePath" inject="safePathValidator@ImageMagick";

    string function getName() {
        return 'fileExists';
    }

    /**
     * Validate the file exists
     *
     * Values that look like a UNC/network path (ex: "\\host\share\file") are rejected
     */
    boolean function validate(
        required any validationResult,
        required any target,
        required string field,
        any targetValue,
        any validationData,
        struct rules
    ) {
        if(isNull(arguments.targetValue) || !len(trim(arguments.targetValue))) {
            return true;
        }

        if(safePath.isUnsafePath(arguments.targetValue)) {
            arguments.validationResult.addError(
                arguments.validationResult
                    .newError(
                        argumentCollection = {
                            message       : '#arguments.field# does not exist',
                            field         : arguments.field,
                            validationType: getName(),
                            rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                            validationData: arguments.validationData
                        }
                    )
                    .setErrorMetadata({fileExists: arguments.validationData})
            );
            return false;
        }

        if(fileExists(arguments.targetValue)) {
            return true;
        }

        arguments.validationResult.addError(
            arguments.validationResult
                .newError(
                    argumentCollection = {
                        message       : '#arguments.field# does not exist',
                        field         : arguments.field,
                        validationType: getName(),
                        rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                        validationData: arguments.validationData
                    }
                )
                .setErrorMetadata({fileExists: arguments.validationData})
        );
        return false;
    }

}
