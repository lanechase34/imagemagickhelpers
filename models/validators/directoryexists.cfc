component singleton {

    property name="safePath" inject="safePathValidator@ImageMagick";

    string function getName() {
        return 'directoryExists';
    }

    /**
     * Validates the directory exists
     *
     * Values that look like a UNC/network path (ex: "\\host\share") are rejected
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
                    .setErrorMetadata({directoryExists: arguments.validationData})
            );
            return false;
        }

        if(directoryExists(arguments.targetValue)) {
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
                .setErrorMetadata({directoryExists: arguments.validationData})
        );
        return false;
    }

}
