component singleton {

    string function getName() {
        return 'atLeastOneOf';
    }

    /**
     * Validate that at least either this field or the other named field is present
     * Fails only when both this field and the other named field are absent
     * Attach to one of the two related fields, with validationData set to {otherField: "..."} naming the field it pairs with
     * Ex: attached to "width" with validationData={otherField: "height"} fails only when neither width nor height is present
     */
    boolean function validate(
        required any validationResult,
        required any target,
        required string field,
        any targetValue,
        any validationData,
        struct rules
    ) {
        var hasThis  = !isNull(arguments.targetValue) && len(arguments.targetValue);
        var otherKey = arguments.validationData.otherField;

        var otherValue = invoke(arguments.target, 'get' & otherKey);
        var hasOther   = !isNull(otherValue) && len(otherValue);

        if(hasThis || hasOther) {
            return true;
        }

        arguments.validationResult.addError(
            arguments.validationResult
                .newError(
                    argumentCollection = {
                        message       : 'Must specify #arguments.field#, #otherKey#, or both',
                        field         : arguments.field,
                        validationType: getName(),
                        rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                        validationData: arguments.validationData
                    }
                )
                .setErrorMetadata({atLeastOneOf: arguments.validationData})
        );
        return false;
    }

}
