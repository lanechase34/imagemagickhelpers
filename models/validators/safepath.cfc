component singleton {

    string function getName() {
        return 'safePath';
    }

    /**
     * Validate the targetValue cannot be resolved by ImageMagick or the OS as anything other than a
     * plain local filesystem path - rejects values ImageMagick would treat as a delegate/coder (ex:
     * "https:", "label:", "mpr:", "|command") or that the OS would treat as a UNC/network path
     * (ex: "\\host\share\file"), both of which allow SSRF, local file disclosure, or command
     * execution when passed through to ImageMagick even though no shell is involved
     */
    boolean function validate(
        required any validationResult,
        required any target,
        required string field,
        any targetValue,
        any validationData,
        struct rules
    ) {
        if(isNull(arguments.targetValue) || !len(trim(arguments.targetValue)) || !isUnsafePath(arguments.targetValue)) {
            return true;
        }

        arguments.validationResult.addError(
            arguments.validationResult
                .newError(
                    argumentCollection = {
                        message       : '#arguments.field# must not be a network path, pipe, or protocol/coder prefix',
                        field         : arguments.field,
                        validationType: getName(),
                        rejectedValue : (isSimpleValue(arguments.targetValue) ? arguments.targetValue : ''),
                        validationData: arguments.validationData
                    }
                )
                .setErrorMetadata({safePath: arguments.validationData})
        );
        return false;
    }

    /**
     * True when value looks like a UNC/protocol-relative path ("\\host\share", "//host/share"), a pipe
     * delegate ("|command"), or an ImageMagick coder/protocol prefix ("https:", "label:", "mpr:", ...)
     * Single-letter Windows drive prefixes ("C:\...") are intentionally allowed through
     */
    boolean function isUnsafePath(required string value) {
        return reFind('^(\\\\|//)', arguments.value) > 0
        || reFind('^\|', arguments.value) > 0
        || reFind('^[A-Za-z][A-Za-z0-9+.-]+:', arguments.value) > 0;
    }

}
