component singleton accessors="true" hint="Service layer for interacting with ImageMagick" {

    property name="imageLog"          inject="logbox:logger:Image";
    property name="validationManager" inject="ValidationManager@cbvalidation";
    property name="constraints"       inject="Constraints@ImageMagickHelpers";

    property name="cfmlEngine"         type="string";
    property name="extToMime"          type="struct";
    property name="imageMagickPath"    type="string";
    property name="imageMagickTimeout" type="numeric";

    /**
     * Creates a new ImageMagick service
     *
     * @cfmlEngine         The current cfml engine (lucee/coldfusion/boxlang)
     * @imageMagickPath    Absolute path to the ImageMagick "magick" executable
     * @imageMagickTimeout Max seconds cfexecute will wait on an ImageMagick call before timing out
     *
     * @return imagemagickhelpers.models.services.image
     */
    public image function init(
        required string cfmlEngine,
        required string imageMagickPath,
        required numeric imageMagickTimeout
    ) {
        variables.cfmlEngine = arguments.cfmlEngine;
        variables.extToMime  = {
            png : 'image/png',
            jpg : 'image/jpeg',
            jpeg: 'image/jpeg',
            webp: 'image/webp',
            heic: 'image/heic',
            heif: 'image/heif',
            gif : 'image/gif',
            bmp : 'image/bmp',
            tif : 'image/tiff',
            tiff: 'image/tiff',
            svg : 'image/svg+xml',
            avif: 'image/avif',
            ico : 'image/vnd.microsoft.icon'
        };
        variables.imageMagickPath    = arguments.imageMagickPath;
        variables.imageMagickTimeout = arguments.imageMagickTimeout;
        return this;
    }

    /**
     * Validates argumentCollection of the calling function against its named cbvalidation constraints
     *
     * @functionName Name of the function whose constraints to validate against, must exist in validators/constraints.cfc
     * @args         The argumentCollection of the calling function
     *
     * @throws ImageMagick.InputValidationException When one or more constraints are violated
     */
    private void function validateArgs(required string functionName, required struct args) {
        var result = variables.validationManager.validate(
            target      = arguments.args,
            constraints = variables.constraints.get(arguments.functionName)
        );

        if(result.hasErrors()) {
            throw(type = 'ImageMagick.InputValidationException', message = result.getAllErrors().toList('; '));
        }
    }

    /**
     * Verify ImageMagick is installed and reachable at the configured path
     *
     * @throws ImageMagick.VerificationException When ImageMagick cannot be reached or does not return a version
     */
    public void function verifyImageMagick() {
        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "identify -version",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!len(trim(result))) {
                throw(
                    type    = 'ImageMagick.VerificationException',
                    message = 'ImageMagick did not return version information | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error verifying imageMagick | #e.message#');
            throw(
                type    = 'ImageMagick.VerificationException',
                message = 'Unable to verify ImageMagick is available | #e.message#'
            );
        }
    }

    /**
     * Uses ImageMagick identify to check whether path points to a valid, readable image
     *
     * @path Full path to the image to check
     *
     * @throws ImageMagick.InputValidationException When path is empty or does not exist
     * @throws ImageMagick.IdentifyException        When ImageMagick reports path is not a valid image
     */
    public void function validIdentify(required string path) {
        validateArgs('validIdentify', arguments);

        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "identify ""#arguments.path#""",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!len(trim(result))) {
                throw(
                    type    = 'ImageMagick.IdentifyException',
                    message = '#arguments.path# is not a valid image | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error validating identity of image | #e.message#');
            throw(
                type    = 'ImageMagick.IdentifyException',
                message = '#arguments.path# is not a valid image | #e.message#'
            );
        }
    }

    /**
     * Uses ImageMagick identify to read the pixel dimensions of an image's first frame
     *
     * @path Full path to the image to check
     *
     * @return Struct of {width, height} in pixels
     *
     * @throws ImageMagick.InputValidationException When path is empty or does not exist
     * @throws ImageMagick.IdentifyException        When ImageMagick fails to report dimensions for path
     */
    public struct function getDimensions(required string path) {
        validateArgs('getDimensions', arguments);

        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "identify -format ""%wx%h"" ""#arguments.path#[0]""",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!reFind('^[0-9]+x[0-9]+$', trim(result))) {
                throw(
                    type    = 'ImageMagick.IdentifyException',
                    message = 'ImageMagick failed to report dimensions for #arguments.path# | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error reading dimensions of image | #e.message#');
            throw(
                type    = 'ImageMagick.IdentifyException',
                message = 'Failed to read dimensions of #arguments.path# | #e.message#'
            );
        }

        return {width: val(listFirst(trim(result), 'x')), height: val(listLast(trim(result), 'x'))};
    }

    /**
     * Uses ImageMagick convert to strip metadata, adjust quality, and shrink-to-fit the source image, writing the result to outputPath
     * Only shrinks the image if it exceeds the resize bound - images smaller than resize are left at their original dimensions
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension
     * @quality    (Optional) 0-100 quality of image, defaults to 50
     * @resize     (Optional) Max width/height in pixels to shrink to, defaults to 1200
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputPath is empty, quality is not between 0 and 100, or resize is not a positive number
     * @throws ImageMagick.ConversionException      When ImageMagick fails to produce the converted output
     */
    public void function convert(
        required string path,
        required string outputPath,
        numeric quality = 50,
        numeric resize  = 1200
    ) {
        validateArgs('convert', arguments);

        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "convert -strip -quality #arguments.quality# ""#arguments.path#"" -resize ""#arguments.resize#x#arguments.resize#>"" ""#arguments.outputPath#""",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!fileExists(arguments.outputPath)) {
                throw(
                    type    = 'ImageMagick.ConversionException',
                    message = 'ImageMagick failed to create converted output at #arguments.outputPath# | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error converting image to #arguments.outputPath# | #e.message#');
            throw(
                type    = 'ImageMagick.ConversionException',
                message = 'Failed to convert image #arguments.path# to #arguments.outputPath# | #e.message#'
            );
        }
    }

    /**
     * Uses ImageMagick to crop the source image to exact dimensions: scales to fully cover the
     * target box (preserving aspect ratio) then crops the overflow from the center. Unlike
     * resize()'s forced-dimensions mode, this never distorts the image.
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension
     * @width      Target width in pixels
     * @height     Target height in pixels
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputPath is empty, or width/height is not a positive number
     * @throws ImageMagick.CropException            When ImageMagick fails to produce the cropped output
     */
    public void function crop(
        required string path,
        required string outputPath,
        required numeric width,
        required numeric height
    ) {
        validateArgs('crop', arguments);

        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "convert -strip ""#arguments.path#"" -resize ""#arguments.width#x#arguments.height#^"" -gravity center -extent ""#arguments.width#x#arguments.height#"" ""#arguments.outputPath#""",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!fileExists(arguments.outputPath)) {
                throw(
                    type    = 'ImageMagick.CropException',
                    message = 'ImageMagick failed to create cropped output at #arguments.outputPath# | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error cropping image to #arguments.outputPath# | #e.message#');
            throw(
                type    = 'ImageMagick.CropException',
                message = 'Failed to crop image #arguments.path# to #arguments.outputPath# | #e.message#'
            );
        }
    }

    /**
     * Uses ImageMagick to physically rotate/flip the image according to its EXIF orientation tag
     * and remove that tag, writing the result to outputPath. Photos uploaded directly from phone
     * cameras are frequently stored sideways/upside-down with only an EXIF flag marking the
     * correct orientation - most browsers and image libraries ignore that flag.
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension
     *
     * @throws ImageMagick.InputValidationException When path does not exist or outputPath is empty
     * @throws ImageMagick.OrientException          When ImageMagick fails to produce the oriented output
     */
    public void function autoOrient(required string path, required string outputPath) {
        validateArgs('autoOrient', arguments);

        var result      = '';
        var errorResult = '';

        try {
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = "convert ""#arguments.path#"" -auto-orient ""#arguments.outputPath#""",
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout()
            );

            if(!fileExists(arguments.outputPath)) {
                throw(
                    type    = 'ImageMagick.OrientException',
                    message = 'ImageMagick failed to create auto-oriented output at #arguments.outputPath# | #errorResult#'
                );
            }
        }
        catch(any e) {
            imageLog.error('Error auto-orienting image to #arguments.outputPath# | #e.message#');
            throw(
                type    = 'ImageMagick.OrientException',
                message = 'Failed to auto-orient image #arguments.path# to #arguments.outputPath# | #e.message#'
            );
        }
    }

    /**
     * Resize the incoming image to one or more output sizes
     *
     * If both width and height are provided for an output, the image is forced to those exact dimensions (aspect ratio ignored)
     * If only one of width/height is provided, the image is scaled to that dimension with aspect ratio preserved. 
     * If a resized output file already exists at the destination path, it is intentionally overwritten
     *
     * @path    Full path to source image
     * @outputs Array of structs of resize destination and width/height of resized image ex: [{resizeDir: '../', width: 100}, {resizeDir: '../', height: 200}, {resizeDir: '../', width: 100, height: 200}]
     *
     * @return Array of full paths to the successfully resized output files, in outputs order
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputs is empty, or an output entry is missing resizeDir, is missing both width and height, or has a non-positive width/height
     * @throws ImageMagick.ResizeException          When ImageMagick fails to produce one of the resized outputs
     */
    public array function resize(required string path, required array outputs) {
        // Normalize before validating so fileExistsValidator checks the same path used to build outputs below
        arguments.path = arguments.path.replace('\', '/', 'all');

        validateArgs('resize', arguments);

        // Extract the filename
        var normalizedPath = arguments.path;
        var fileName       = listLast(normalizedPath, '/');

        // Build every output's geometry string and destination path up front so we fail before resizing anything
        var preparedOutputs = arguments.outputs.map((output) => buildResizeOutput(output, fileName));

        var resizedPaths = [];

        try {
            preparedOutputs.each((prepared) => {
                var result      = '';
                var errorResult = '';

                cfexecute(
                    name          = getImageMagickPath(),
                    arguments     = "convert -strip ""#normalizedPath#"" -resize ""#prepared.geometry#"" ""#prepared.outputPath#""",
                    variable      = "local.result",
                    errorVariable = "local.errorResult",
                    timeout       = getImageMagickTimeout()
                );

                if(!fileExists(prepared.outputPath)) {
                    throw(
                        type    = 'ImageMagick.ResizeException',
                        message = 'ImageMagick failed to create resized output at #prepared.outputPath# | #errorResult#'
                    );
                }

                resizedPaths.append(prepared.outputPath);
            });
        }
        catch(any e) {
            imageLog.error('Error resizing image | #e.message#');

            // Remove any outputs that were already resized before the failure
            resizedPaths.each((resizedPath) => {
                if(fileExists(resizedPath)) {
                    fileDelete(resizedPath);
                }
            });

            throw(
                type    = 'ImageMagick.ResizeException',
                message = 'Failed to resize image #arguments.path# | #e.message#'
            );
        }

        return resizedPaths;
    }

    /**
     * Builds a resize() output's ImageMagick geometry string and destination path
     *
     * @output   The output struct, already validated ex: {resizeDir: '../', width: 100, height: 200}
     * @fileName Source image filename to use for the destination file
     *
     * @return Struct of {outputPath, geometry}
     */
    private struct function buildResizeOutput(required struct output, required string fileName) {
        var hasWidth  = arguments.output.keyExists('width') && len(arguments.output.width);
        var hasHeight = arguments.output.keyExists('height') && len(arguments.output.height);
        var geometry  = '';

        if(hasWidth && hasHeight) {
            geometry = '#arguments.output.width#x#arguments.output.height#!';
        }
        else if(hasWidth) {
            geometry = '#arguments.output.width#';
        }
        else {
            geometry = 'x#arguments.output.height#';
        }

        var resizeDir = arguments.output.resizeDir.replace('\', '/', 'all').reReplace('/$', '');

        return {outputPath: '#resizeDir#/#arguments.fileName#', geometry: geometry};
    }

    /**
     * Validate the incoming image upload
     * If valid, convert it to each requested output and move it to the corresponding upload directory
     *
     * @formField  The form field the image was uploaded under
     * @outputs    Array of structs of upload destination and conversion type ex: [{uploadDir: uploadPath, type: 'webp'}]
     * @extensions (Optional) Comma-delimited list of allowed source file extensions, defaults to 'png,jpg,jpeg,webp,heic'
     *
     * @return Filename - the converted file name's UUID (without extension)
     *
     * @throws ImageMagick.InputValidationException  When formField is empty, outputs is empty, or an output entry is missing uploadDir or type
     * @throws ImageMagick.UploadValidationException When no file is uploaded, the upload is not a valid image, the upload's extension is not in extensions, or an output fails to convert
     */
    public string function validateUpload(
        required string formField,
        required array outputs,
        string extensions = 'png,jpg,jpeg,webp,heic'
    ) {
        validateArgs('validateUpload', arguments);

        // Attempt file upload to temp directory
        try {
            var uploadArgs = {
                destination: getTempDirectory(),
                fileField  : arguments.formField,
                strict     : true
            };

            var mimeTypes = listToArray(arguments.extensions, ',')
                .map((ext) => getExtToMime()[ext.trim().lcase()])
                .toList(',');

            if(getCfmlEngine() == 'lucee') {
                uploadArgs.accept     = mimeTypes;
                uploadArgs.onConflict = 'makeUnique';
            }
            else {
                uploadArgs.mimeType     = mimeTypes;
                uploadArgs.nameConflict = 'makeUnique';
            }

            cffile(
                action              = "upload",
                attributeCollection = uploadArgs,
                accept              = mimeTypes,
                result              = "upload"
            );
        }
        catch(any e) {
            throw(type = 'ImageMagick.UploadValidationException', message = 'Invalid image upload | #e.message#');
        }

        // Get the uploaded temp path
        var tempPath = '#upload.serverdirectory#/#upload.serverfile#'.replace('\', '/', 'all');

        // Check if valid image
        try {
            validIdentify(tempPath);
        }
        catch(any e) {
            fileDelete(tempPath);
            throw(type = 'ImageMagick.UploadValidationException', message = 'Invalid image upload | #e.message#');
        }

        // Check if an allowed extension
        if(!listFindNoCase(arguments.extensions, upload.serverfileext)) {
            fileDelete(tempPath);
            throw(
                type    = 'ImageMagick.UploadValidationException',
                message = 'Invalid image upload: extension #upload.serverfileext# is not allowed'
            );
        }

        // Create UUID for uploaded file
        var newName = createUUID().replace('-', '', 'all');

        // For each output, attempt to convert and move to destination upload directory
        // Track what's been converted in case of failure
        var convertedPaths = [];
        try {
            arguments.outputs.each((output) => {
                var uploadDir  = output.uploadDir.replace('\', '/', 'all').reReplace('/$', '');
                var outputPath = '#uploadDir#/#newName#.#output.type#';

                convert(path = tempPath, outputPath = outputPath);

                convertedPaths.append(outputPath);
            });
        }
        catch(any e) {
            // Remove any outputs that were already converted before the failure
            convertedPaths.each((convertedPath) => {
                if(fileExists(convertedPath)) {
                    fileDelete(convertedPath);
                }
            });

            throw(
                type    = 'ImageMagick.UploadValidationException',
                message = 'Failed to process image upload | #e.message#'
            );
        }
        finally {
            // Delete the temp upload file
            if(fileExists(tempPath)) {
                fileDelete(tempPath);
            }
        }

        // Return the new name
        return newName;
    }

}
