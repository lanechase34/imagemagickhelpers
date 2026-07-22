component singleton {

    string function getName() {
        return 'fileExists';
    }

    /**
     * Validate the file exists
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
