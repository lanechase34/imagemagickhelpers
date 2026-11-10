component singleton {

    string function getName() {
        return 'supportedExtensions';
    }

    /**
     * Validate every entry of the comma-delimited targetValue is one of the extensions in validationData
     * Entries are compared trimmed and case-insensitively, ex: ' PNG, jpg' passes against 'png,jpg,webp'
     * Also used for single values, ex: an output type, which are just a one entry list
     */
    boolean function validate(
        required any validationResult,
        required any target,
        required string field,
        any targetValue,
        any validationData,
        struct rules
    ) {
        if(isNull(arguments.targetValue)) {
            return true;
        }

        var supported   = arguments.validationData;
        var unsupported = [];
        if(isSimpleValue(arguments.targetValue)) {
            unsupported = listToArray(arguments.targetValue, ',').filter((ext) => !listFindNoCase(supported, ext.trim()));
        }
        else {
            unsupported = ['(not a string)'];
        }

        if(!unsupported.len()) {
            return true;
        }

        arguments.validationResult.addError(
            arguments.validationResult
                .newError(
                    argumentCollection = {
                        message       : '#arguments.field# contains unsupported extension(s) #unsupported.toList(', ')# - supported: #supported#',
                        field         : arguments.field,
                        validationType: getName(),
                        rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                        validationData: arguments.validationData
                    }
                )
                .setErrorMetadata({supportedExtensions: arguments.validationData})
        );
        return false;
    }

}
