component singleton {

    string function getName() {
        return 'noQuoteChar';
    }

    /**
     * Validate the targetValue does not contain a double-quote char
     */
    boolean function validate(
        required any validationResult,
        required any target,
        required string field,
        any targetValue,
        any validationData,
        struct rules
    ) {
        if(isNull(arguments.targetValue) || !find('"', arguments.targetValue)) {
            return true;
        }

        arguments.validationResult.addError(
            arguments.validationResult
                .newError(
                    argumentCollection = {
                        message       : '#arguments.field# must not contain a double-quote character',
                        field         : arguments.field,
                        validationType: getName(),
                        rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                        validationData: arguments.validationData
                    }
                )
                .setErrorMetadata({noQuoteChar: arguments.validationData})
        );
        return false;
    }

}
