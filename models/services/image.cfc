/**
 * Service layer for interacting with ImageMagick
 *
 * Every public function validates its arguments first and throws ImageMagick.InputValidationException on a violation.
 * Exceptions carry what failed in their message and the technical cause (ex: ImageMagick's error output) in their detail -
 * ImageMagick.UploadValidationException messages are written to be shown to end users as is.
 */
component singleton accessors="true" {

    property name="imageLog"          inject="logbox:logger:ImageMagickHelpers";
    property name="validationManager" inject="ValidationManager@cbvalidation";
    property name="constraints"       inject="Constraints@ImageMagickHelpers";

    property name="cfmlEngine"         type="string";
    property name="extToMime"          type="struct";
    property name="extToFormat"        type="struct";
    property name="imageMagickPath"    type="string";
    property name="imageMagickTimeout" type="numeric";
    property name="limitArgs"          type="array";

    /**
     * Creates a new ImageMagick service
     *
     * @cfmlEngine         The current cfml engine (lucee/coldfusion/boxlang)
     * @imageMagickPath    Absolute path to the ImageMagick "magick" executable
     * @imageMagickTimeout Max seconds an ImageMagick call may run before ImageMagick stops it
     * @imageMagickLimits  ImageMagick -limit resource values applied to every call ex: {memory: '256MiB', width: '16KP'}
     *
     * @return ImageMagickHelpers.models.services.image
     */
    public image function init(
        required string cfmlEngine,
        required string imageMagickPath,
        required numeric imageMagickTimeout,
        struct imageMagickLimits = {}
    ) {
        variables.cfmlEngine         = arguments.cfmlEngine;
        variables.imageMagickPath    = arguments.imageMagickPath;
        variables.imageMagickTimeout = arguments.imageMagickTimeout;
        variables.limitArgs          = buildLimitArgs(arguments.imageMagickLimits, arguments.imageMagickTimeout);

        // Keys of both maps must match supportedExtensions in validators/constraints.cfc
        variables.extToMime = {
            png : "image/png",
            jpg : "image/jpeg",
            jpeg: "image/jpeg",
            webp: "image/webp",
            heic: "image/heic",
            gif : "image/gif",
            bmp : "image/bmp",
            tif : "image/tiff",
            tiff: "image/tiff",
            svg : "image/svg+xml",
            avif: "image/avif",
            ico : "image/vnd.microsoft.icon"
        };

        // ImageMagick's "identify -format %m" for each extension - confirms an upload's content is what its extension claims
        variables.extToFormat = {
            png : "PNG",
            jpg : "JPEG",
            jpeg: "JPEG",
            webp: "WEBP",
            heic: "HEIC",
            gif : "GIF",
            bmp : "BMP",
            tif : "TIFF",
            tiff: "TIFF",
            svg : "SVG",
            avif: "AVIF",
            ico : "ICO"
        };

        return this;
    }

    /* ==================================================================================================
     * Public API
     * ================================================================================================== */

    /**
     * Verify ImageMagick is installed and reachable at the configured path
     *
     * @throws ImageMagick.VerificationException When ImageMagick cannot be reached or does not return a version
     */
    public void function verifyImageMagick() {
        var result = {output: "", error: ""};
        try {
            result = runMagick(commandArgs = ["-version"], applyLimits = false);
        }
        catch(any e) {
            result.error = e.message;
        }

        if(!len(trim(result.output))) {
            imageLog.error("ImageMagick is not available at #getImageMagickPath()# | #result.error#");
            throw(
                type    = "ImageMagick.VerificationException",
                message = "ImageMagick is not available at #getImageMagickPath()#",
                detail  = result.error
            );
        }
    }

    /**
     * Check path is a valid, readable image and report the format ImageMagick detected for its first frame
     * (ex: PNG, JPEG, MVG) - based on the file's actual content, not its extension
     *
     * The image is fully decoded, so a file with a valid header but corrupt pixel data is rejected
     *
     * @path Full path to the image to check
     *
     * @return ImageMagick's uppercased format name for path
     *
     * @throws ImageMagick.InputValidationException When path is empty or does not exist
     * @throws ImageMagick.IdentifyException        When ImageMagick reports path is not a valid image
     */
    public string function identify(required string path) {
        validateArgs("identify", arguments);

        return runIdentify(path = arguments.path, format = "%m").ucase();
    }

    /**
     * Read the pixel dimensions of an image's first frame - from its header alone, so it's fast for any size image
     *
     * @path Full path to the image to check
     *
     * @return Struct of {width, height} in pixels
     *
     * @throws ImageMagick.InputValidationException When path is empty or does not exist
     * @throws ImageMagick.IdentifyException        When ImageMagick fails to report dimensions for path
     */
    public struct function getDimensions(required string path) {
        validateArgs("getDimensions", arguments);

        var info = inspect(arguments.path);
        return {width: info.width, height: info.height};
    }

    /**
     * Adjust quality and shrink-to-fit the source image, writing the result to outputPath
     * Only shrinks the image if it exceeds the resize bound - images smaller than resize are left at their original dimensions
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension, which determines its format
     * @quality    (Optional) 1-100 quality of image, defaults to 50
     * @resize     (Optional) Max width/height in pixels to shrink to, defaults to 1200
     * @strip      (Optional) Whether to strip metadata (EXIF, ICC profiles, etc) from the image, defaults to true
     * @autoOrient (Optional) Physically rotate/flip the image upright using its EXIF orientation tag, defaults to false
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputPath is empty, quality is not between 1 and 100, or resize is less than 1
     * @throws ImageMagick.ConversionException      When ImageMagick fails to produce the converted output
     */
    public void function convert(
        required string path,
        required string outputPath,
        numeric quality    = 50,
        numeric resize     = 1200,
        boolean strip      = true,
        boolean autoOrient = false
    ) {
        validateArgs("convert", arguments);

        var source = {width: 0, height: 0};
        try {
            source = inspect(arguments.path);
        }
        catch(ImageMagick.IdentifyException e) {
        }

        var temp = tempOutputs([arguments.outputPath]);

        writeOutputs(
            commandArgs = buildConvertArgs(
                path        = arguments.path,
                source      = source,
                outputPaths = temp.paths,
                quality     = arguments.quality,
                resize      = arguments.resize,
                strip       = arguments.strip,
                autoOrient  = arguments.autoOrient
            ),
            temp           = temp,
            outputPaths    = [arguments.outputPath],
            exceptionType  = "ImageMagick.ConversionException",
            failureMessage = "Failed to convert image #arguments.path# to #arguments.outputPath#"
        );
    }

    /**
     * Crop the source image to exact dimensions: scales it to fully cover the target box (preserving aspect ratio)
     * then crops the overflow from the center. Unlike resize()'s forced-dimensions mode, this never distorts the image.
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension, which determines its format
     * @width      Target width in pixels
     * @height     Target height in pixels
     * @strip      (Optional) Whether to strip metadata (EXIF, ICC profiles, etc) from the image, defaults to true
     * @autoOrient (Optional) Physically rotate/flip the image upright using its EXIF orientation tag before cropping, defaults to false
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputPath is empty, or width/height is less than 1
     * @throws ImageMagick.CropException            When ImageMagick fails to produce the cropped output
     */
    public void function crop(
        required string path,
        required string outputPath,
        required numeric width,
        required numeric height,
        boolean strip      = true,
        boolean autoOrient = false
    ) {
        validateArgs("crop", arguments);

        var temp = tempOutputs([arguments.outputPath]);

        writeOutputs(
            commandArgs = flattenArgs([
                jpegSizeHint(max(arguments.width, arguments.height)),
                arguments.path,
                orientAndStripArgs(arguments.autoOrient, arguments.strip),
                "-resize",
                "#arguments.width#x#arguments.height#^",
                "-gravity",
                "center",
                "-extent",
                "#arguments.width#x#arguments.height#",
                temp.paths[1]
            ]),
            temp           = temp,
            outputPaths    = [arguments.outputPath],
            exceptionType  = "ImageMagick.CropException",
            failureMessage = "Failed to crop image #arguments.path# to #arguments.outputPath#"
        );
    }

    /**
     * Physically rotate/flip the image according to its EXIF orientation tag and remove that tag, writing the result to outputPath
     * Photos uploaded directly from phone cameras are frequently stored sideways/upside-down with only an EXIF flag
     * marking the correct orientation
     *
     * @path       Full path to source image
     * @outputPath Full path to output file including extension, which determines its format
     *
     * @throws ImageMagick.InputValidationException When path does not exist or outputPath is empty
     * @throws ImageMagick.OrientException          When ImageMagick fails to produce the oriented output
     */
    public void function autoOrient(required string path, required string outputPath) {
        validateArgs("autoOrient", arguments);

        var temp = tempOutputs([arguments.outputPath]);

        writeOutputs(
            commandArgs    = [arguments.path, "-auto-orient", temp.paths[1]],
            temp           = temp,
            outputPaths    = [arguments.outputPath],
            exceptionType  = "ImageMagick.OrientException",
            failureMessage = "Failed to auto-orient image #arguments.path# to #arguments.outputPath#"
        );
    }

    /**
     * Resize the source image to one or more output sizes, decoding the source only once
     *
     * If both width and height are provided for an output, the image is forced to those exact dimensions (aspect ratio ignored)
     * If only one of width/height is provided, the image is scaled to that dimension with aspect ratio preserved
     * Each output is written under the source's filename in its resizeDir, intentionally overwriting any file already there
     *
     * @path       Full path to source image
     * @outputs    Array of structs of resize destination and width/height of resized image ex: [{resizeDir: '../', width: 100}, {resizeDir: '../', height: 200}, {resizeDir: '../', width: 100, height: 200}]
     * @strip      (Optional) Whether to strip metadata (EXIF, ICC profiles, etc) from the image, defaults to true
     * @autoOrient (Optional) Physically rotate/flip the image upright using its EXIF orientation tag before resizing, defaults to false
     *
     * @return Array of full paths to the resized output files, in outputs order
     *
     * @throws ImageMagick.InputValidationException When path does not exist, outputs is empty, two outputs share a resizeDir, or an output entry is missing resizeDir, is missing both width and height, or has a width/height less than 1
     * @throws ImageMagick.ResizeException          When ImageMagick fails to produce one of the resized outputs
     */
    public array function resize(
        required string path,
        required array outputs,
        boolean strip      = true,
        boolean autoOrient = false
    ) {
        // Normalize before validating so fileExistsValidator checks the same path used to build outputs below
        arguments.path = normalizePath(arguments.path);

        validateArgs("resize", arguments);

        // Build every output up front so we fail before resizing anything
        var fileName        = listLast(arguments.path, "/");
        var preparedOutputs = arguments.outputs.map((output) => buildResizeOutput(output, fileName));
        var outputPaths     = preparedOutputs.map((prepared) => prepared.outputPath);

        ensureUniqueOutputs(
            outputPaths,
            "Each resize output must use a different resizeDir - they all write the source filename"
        );

        // Each output resizes its own clone of the decoded source, so the source is only read once
        var temp       = tempOutputs(outputPaths);
        var resizeArgs = [];
        preparedOutputs.each((prepared, index) => {
            resizeArgs.append(
                [
                    "(",
                    "+clone",
                    "-resize",
                    prepared.geometry,
                    "-write",
                    temp.paths[index],
                    "+delete",
                    ")"
                ],
                true
            );
        });

        var largestDimension = preparedOutputs.reduce((largest, prepared) => max(largest, prepared.maxDimension), 0);

        writeOutputs(
            commandArgs = flattenArgs([
                jpegSizeHint(largestDimension),
                arguments.path,
                orientAndStripArgs(arguments.autoOrient, arguments.strip),
                resizeArgs,
                "null:"
            ]),
            temp           = temp,
            outputPaths    = outputPaths,
            exceptionType  = "ImageMagick.ResizeException",
            failureMessage = "Failed to resize image #arguments.path#"
        );

        return outputPaths;
    }

    /**
     * Validate an image uploaded under formField and convert it to each requested output
     *
     * 1. Upload it to its own temp directory, check its extension and file size, and rename it to a UUID
     * 2. Read its header to check it's a real image of the type its extension claims, within maxPixels
     * 3. Convert its first frame to every output from a single decode, all named with the same new UUID
     *
     * The temp directory is always removed. If any output fails, no output is written.
     *
     * @formField   The form field the image was uploaded under
     * @outputs     Array of structs of upload destination and conversion type ex: [{uploadDir: uploadPath, type: 'webp'}]
     * @extensions  (Optional) Comma-delimited list of allowed source file extensions, defaults to 'png,jpg,jpeg,webp,heic'
     * @strip       (Optional) Whether to strip metadata (EXIF, ICC profiles, etc) from each converted output, defaults to true
     * @autoOrient  (Optional) Rotate/flip each output upright using the upload's EXIF orientation tag, defaults to false
     * @maxPixels   (Optional) Max width x height of the upload in pixels, defaults to 100000000 (100 megapixels)
     * @maxFileSize (Optional) Max size of the uploaded file in bytes, defaults to 26214400 (25MB)
     * @quality     (Optional) 1-100 quality of each output, defaults to 50
     * @resize      (Optional) Max width/height in pixels to shrink each output to, defaults to 1200
     *
     * @return The converted files' shared UUID filename (without extension)
     *
     * @throws ImageMagick.InputValidationException  When formField is empty, outputs is empty, an output entry is missing uploadDir or type, two outputs share an uploadDir and type, an extension or type is not supported, maxPixels/maxFileSize is not a positive number, resize is less than 1, or quality is not between 1 and 100
     * @throws ImageMagick.UploadValidationException When no file is uploaded, the upload's extension is not in extensions, it exceeds maxFileSize, it is not a valid image, its content does not match its extension, it exceeds maxPixels, or an output fails to convert
     */
    public string function validateUpload(
        required string formField,
        required array outputs,
        string extensions   = "png,jpg,jpeg,webp,heic",
        boolean strip       = true,
        boolean autoOrient  = false,
        numeric maxPixels   = 100000000,
        numeric maxFileSize = 26214400,
        numeric quality     = 50,
        numeric resize      = 1200
    ) {
        validateArgs("validateUpload", arguments);

        // Build every output path up front so we fail before uploading anything
        var newName     = createUUID().replace("-", "", "all");
        var outputPaths = arguments.outputs.map((output) => "#normalizePath(output.uploadDir)#/#newName#.#output.type.trim().lcase()#");

        ensureUniqueOutputs(outputPaths, "Each upload output must have a different uploadDir and type combination");

        // Each upload gets its own temp directory, so concurrent uploads can never collide with or see each other's files
        var tempDir = "#normalizePath(getTempDirectory())#/imagemagick-upload-#lCase(createUUID())#";
        directoryCreate(tempDir);

        try {
            var tempPath = uploadToTemp(
                formField         = arguments.formField,
                destination       = tempDir,
                fileName          = newName,
                allowedExtensions = listToArray(arguments.extensions, ",").map((ext) => ext.trim().lcase()),
                maxFileSize       = arguments.maxFileSize
            );

            var source = checkUploadedImage(path = tempPath, maxPixels = arguments.maxPixels);

            convertUpload(
                path        = tempPath,
                source      = source,
                outputPaths = outputPaths,
                quality     = arguments.quality,
                resize      = arguments.resize,
                strip       = arguments.strip,
                autoOrient  = arguments.autoOrient
            );
        }
        finally {
            if(directoryExists(tempDir)) {
                directoryDelete(tempDir, true);
            }
        }

        return newName;
    }

    /**
     * Step 1 - upload the form field into destination, check its extension and size, then rename it to fileName
     * The extension and size are checked before ImageMagick ever reads the file
     *
     * @formField         The form field the image was uploaded under
     * @destination       The upload's own temp directory
     * @fileName          Name to give the file, without extension
     * @allowedExtensions Array of trimmed, lowercased extensions already validated against extToMime
     * @maxFileSize       Max size of the uploaded file in bytes
     *
     * @return Full path to the renamed upload
     *
     * @throws ImageMagick.UploadValidationException When no file is uploaded, its extension is not allowed, or it exceeds maxFileSize
     */
    private string function uploadToTemp(
        required string formField,
        required string destination,
        required string fileName,
        required array allowedExtensions,
        required numeric maxFileSize
    ) {
        var mimeTypes  = arguments.allowedExtensions.map((ext) => getExtToMime()[ext]).toList(",");
        var uploadArgs = {
            destination: arguments.destination,
            fileField  : arguments.formField,
            strict     : true
        };

        // Lucee and Adobe/BoxLang name these cffile attributes differently
        if(getCfmlEngine() == "lucee") {
            uploadArgs.accept     = mimeTypes;
            uploadArgs.onConflict = "makeUnique";
        }
        else {
            uploadArgs.nameConflict = "makeUnique";
        }

        // BoxLang takes an upload's MIME type from Java's guess by file extension, which has none for some image types
        // (ex: .heic) - so it would reject them. The extension and the content ImageMagick detects are checked below instead
        if(getCfmlEngine() == "coldfusion") {
            uploadArgs.accept   = mimeTypes;
            uploadArgs.mimeType = mimeTypes;
        }

        // Result must be local - this service is a singleton, so an unscoped result would be shared across concurrent requests
        var upload = {};
        try {
            cffile(
                action              = "upload",
                attributeCollection = uploadArgs,
                result              = "local.upload"
            );
        }
        catch(any e) {
            rejectUpload(message = "No valid image was uploaded.", detail = e.message);
        }

        var extension = upload.serverFileExt.lcase();
        if(!arrayFind(arguments.allowedExtensions, extension)) {
            rejectUpload(
                message = "File is not an allowed image type.",
                detail  = "Extension #extension# is not in #arguments.allowedExtensions.toList(", ")#"
            );
        }

        if(upload.fileSize > arguments.maxFileSize) {
            rejectUpload(
                message = "File exceeds the maximum allowed size of #inUnits(arguments.maxFileSize, 1048576)#MB.",
                detail  = "Upload is #upload.fileSize# bytes, the maximum is #arguments.maxFileSize#"
            );
        }

        // Rename to a UUID before ImageMagick sees the file - the client's filename may contain characters
        // ImageMagick interprets in input paths, ex: * and ? are globbed against the directory
        var tempPath = "#arguments.destination#/#arguments.fileName#.#extension#";
        fileMove("#upload.serverDirectory#/#upload.serverFile#", tempPath);

        return tempPath;
    }

    /**
     * Step 2 - read the upload's header to check it's a real image of the type its extension claims, within maxPixels
     * Only the header is read, so an oversized image is rejected before anything decodes it
     *
     * @path      Full path to the renamed upload
     * @maxPixels Max width x height of the upload in pixels
     *
     * @return Struct of {format, width, height} read from the upload's header
     *
     * @throws ImageMagick.UploadValidationException When it is not a valid image, its content does not match its extension, or it exceeds maxPixels
     */
    private struct function checkUploadedImage(required string path, required numeric maxPixels) {
        var extension = listLast(arguments.path, ".");

        var info = {};
        try {
            info = inspect(arguments.path);
        }
        catch(any e) {
            rejectUpload(message = "File could not be read as a valid image.", detail = "#e.message# | #e.detail#");
        }

        // ImageMagick detects the format from the file's content, so this catches a spoofed extension
        if(info.format != getExtToFormat()[extension]) {
            rejectUpload(
                message = "File contents do not match its .#extension# extension.",
                detail  = "ImageMagick detected #info.format#, expected #getExtToFormat()[extension]#"
            );
        }

        if(info.width * info.height > arguments.maxPixels) {
            rejectUpload(
                message = "Image is too large - it can be at most #inUnits(arguments.maxPixels, 1000000)# megapixels.",
                detail  = "Upload is #info.width#x#info.height#, the maximum is #arguments.maxPixels# pixels"
            );
        }

        return info;
    }

    /**
     * Step 3 - convert the upload to every output from a single decode
     * A corrupt image body that passed the header read in step 2 fails here
     * Only the first frame is read - the one step 2 checked against maxPixels - so an animated or multi-image upload
     * can't decode more than that, and every output is a single image (a single-frame format would otherwise be
     * written as one numbered file per frame)
     *
     * @path        Full path to the renamed upload
     * @source      Upload's header info from step 2 ex: {format: 'JPEG', width: 4032, height: 3024}
     * @outputPaths Full paths to write, the format of each is determined by its extension
     * @quality     1-100 quality of each output
     * @resize      Max width/height in pixels to shrink each output to
     * @strip       Whether to strip metadata
     * @autoOrient  Whether to rotate/flip the image upright using its EXIF orientation tag
     *
     * @throws ImageMagick.UploadValidationException When an output fails to convert
     */
    private void function convertUpload(
        required string path,
        required struct source,
        required array outputPaths,
        required numeric quality,
        required numeric resize,
        required boolean strip,
        required boolean autoOrient
    ) {
        var temp = tempOutputs(arguments.outputPaths);

        try {
            writeOutputs(
                commandArgs = buildConvertArgs(
                    path        = "#arguments.path#[0]",
                    source      = arguments.source,
                    outputPaths = temp.paths,
                    quality     = arguments.quality,
                    resize      = arguments.resize,
                    strip       = arguments.strip,
                    autoOrient  = arguments.autoOrient
                ),
                temp           = temp,
                outputPaths    = arguments.outputPaths,
                exceptionType  = "ImageMagick.ConversionException",
                failureMessage = "Failed to convert image upload"
            );
        }
        catch(any e) {
            rejectUpload(message = "Image could not be processed.", detail = "#e.message# | #e.detail#");
        }
    }

    /**
     * Throw an upload rejection - message is shown to end users, detail holds the technical cause
     *
     * @message User-facing reason the upload was rejected
     * @detail  Technical cause, for logs and developers
     *
     * @throws ImageMagick.UploadValidationException Always
     */
    private void function rejectUpload(required string message, string detail = "") {
        throw(
            type    = "ImageMagick.UploadValidationException",
            message = arguments.message,
            detail  = arguments.detail
        );
    }

    /**
     * Run the ImageMagick executable with the given arguments
     *
     * @commandArgs Arguments to pass after the tool and resource limits
     * @tool        (Optional) ImageMagick tool to run ex: 'identify', defaults to running magick itself
     * @applyLimits (Optional) Whether to apply the configured resource limits, defaults to true
     *
     * @return Struct of {output, error} - ImageMagick's stdout and stderr
     *
     * @throws ImageMagick.ExecuteException When cfexecute fails or times out - on Lucee, also when ImageMagick exits non-zero
     */
    private struct function runMagick(
        required array commandArgs,
        string tool         = "",
        boolean applyLimits = true
    ) {
        var fullArgs = [];
        if(len(arguments.tool)) {
            fullArgs.append(arguments.tool);
        }
        if(arguments.applyLimits) {
            fullArgs.append(getLimitArgs(), true);
        }
        fullArgs.append(arguments.commandArgs, true);

        var result      = "";
        var errorResult = "";

        try {
            // Wait a few seconds past ImageMagick's own time limit so it stops itself first,
            // instead of cfexecute giving up on a process that may keep running and writing outputs
            cfexecute(
                name          = getImageMagickPath(),
                arguments     = fullArgs,
                variable      = "local.result",
                errorVariable = "local.errorResult",
                timeout       = getImageMagickTimeout() + 5
            );
        }
        catch(any e) {
            throw(
                type    = "ImageMagick.ExecuteException",
                message = len(trim(e.detail)) ? "#e.message# | #trim(e.detail)#" : e.message
            );
        }

        return {output: local.result ?: "", error: local.errorResult ?: ""};
    }

    /**
     * Run identify with a -format string against an image's first frame
     *
     * @path   Full path to the image, already validated
     * @format identify -format string ex: '%m'
     * @ping   (Optional) Read only the header instead of decoding the whole image, defaults to false
     *
     * @return identify's trimmed output
     *
     * @throws ImageMagick.IdentifyException When ImageMagick cannot read path
     */
    private string function runIdentify(
        required string path,
        required string format,
        boolean ping = false
    ) {
        var commandArgs = arguments.ping ? ["-ping"] : [];
        commandArgs.append(
            [
                "-format",
                arguments.format,
                "#arguments.path#[0]"
            ],
            true
        );

        var result = {output: "", error: ""};
        try {
            result = runMagick(commandArgs = commandArgs, tool = "identify");
        }
        catch(any e) {
            result.error = e.message;
        }

        if(!len(trim(result.output))) {
            imageLog.warn("ImageMagick could not read #arguments.path# | #result.error#");
            throw(
                type    = "ImageMagick.IdentifyException",
                message = "#arguments.path# is not a valid image",
                detail  = result.error
            );
        }

        return trim(result.output);
    }

    /**
     * Read the format and dimensions of an image's first frame from its header alone, without decoding its pixels
     *
     * @path Full path to the image, already validated
     *
     * @return Struct of {format, width, height}
     *
     * @throws ImageMagick.IdentifyException When ImageMagick cannot read path's header
     */
    private struct function inspect(required string path) {
        var output = runIdentify(
            path   = arguments.path,
            format = "%m %w %h",
            ping   = true
        );
        var parts = listToArray(output, " ");

        if(parts.len() != 3 || !isNumeric(parts[2]) || !isNumeric(parts[3])) {
            throw(
                type    = "ImageMagick.IdentifyException",
                message = "ImageMagick did not report the format and dimensions of #arguments.path#",
                detail  = output
            );
        }

        return {
            format: parts[1].ucase(),
            width : val(parts[2]),
            height: val(parts[3])
        };
    }

    /**
     * Pick where ImageMagick writes each output - a new temp directory that writeOutputs() moves the results out of
     * Each keeps its output's filename, whose extension determines the format ImageMagick writes
     *
     * @outputPaths Full output paths about to be written
     *
     * @return Struct of {directory, paths} - paths in outputPaths order
     */
    private struct function tempOutputs(required array outputPaths) {
        var directory = "#normalizePath(getTempDirectory())#/imagemagick-output-#lCase(createUUID())#";
        return {
            directory: directory,
            paths    : arguments.outputPaths.map((outputPath, index) => "#directory#/#index#-#listLast(outputPath, "/\")#")
        };
    }

    /**
     * Run an ImageMagick command that writes into a temp directory, then move each result to its output path
     *
     * 1. Run ImageMagick, writing every output into the temp directory
     * 2. Check every output was written and its output directory exists - if not, throw without touching any output path
     * 3. Move each result to its output path, replacing any file already there
     * 4. Always remove the temp directory
     *
     * An output path is only ever replaced by a good result, so a failed run never leaves a missing or stale file there -
     * even when the output path is the source itself. If a move fails (ex: permissions), results already moved stay in place.
     *
     * @commandArgs    Arguments to pass to magick, writing every path in temp.paths
     * @temp           Where ImageMagick writes, from tempOutputs() ex: {directory, paths}
     * @outputPaths    Full paths to move each result to, in temp.paths order
     * @exceptionType  Exception type to throw on failure
     * @failureMessage What failed, used as the exception message
     *
     * @throws exceptionType When ImageMagick fails, does not write every output, an output directory does not exist, or a result cannot be moved into place
     */
    private void function writeOutputs(
        required array commandArgs,
        required struct temp,
        required array outputPaths,
        required string exceptionType,
        required string failureMessage
    ) {
        var tempPaths = arguments.temp.paths;
        directoryCreate(arguments.temp.directory);

        var failure = "";
        try {
            // 1. Run ImageMagick, writing every output into the temp directory
            var result = runMagick(arguments.commandArgs);

            // 2. Check every output was written - fileMove onto an existing directory would put the result inside it, so those fail too
            // BoxLang's fileMove creates missing parent directories instead of failing, so check those explicitly
            var missingPaths       = arguments.outputPaths.filter((outputPath, index) => !fileExists(tempPaths[index]));
            var directoryPaths     = arguments.outputPaths.filter((outputPath) => directoryExists(outputPath));
            var missingDirectories = arguments.outputPaths.filter((outputPath) => !directoryExists(getDirectoryFromPath(outputPath)));

            if(missingPaths.len()) {
                failure = "ImageMagick did not create #missingPaths.toList(", ")# | #result.error#";
            }
            else if(directoryPaths.len()) {
                failure = "Cannot replace directory #directoryPaths.toList(", ")# with a file";
            }
            else if(missingDirectories.len()) {
                failure = "Output directory does not exist for #missingDirectories.toList(", ")#";
            }
            else {
                // 3. Move each result to its output path, replacing any file already there
                arguments.outputPaths.each((outputPath, index) => {
                    if(fileExists(outputPath)) {
                        fileDelete(outputPath);
                    }
                    fileMove(tempPaths[index], outputPath);
                });
            }
        }
        catch(any e) {
            failure = e.message;
        }
        finally {
            // 4. Always remove the temp directory
            if(directoryExists(arguments.temp.directory)) {
                directoryDelete(arguments.temp.directory, true);
            }
        }

        if(len(failure)) {
            imageLog.error("#arguments.failureMessage# | #failure#");
            throw(
                type    = arguments.exceptionType,
                message = arguments.failureMessage,
                detail  = failure
            );
        }
    }

    /**
     * Build the -limit arguments applied to every call
     * ImageMagick enforces its own time limit too, so a timed out call stops working instead of running on in the background
     *
     * @limits  ImageMagick -limit resource values ex: {memory: '256MiB', width: '16KP'}
     * @timeout Seconds to use as the time limit when limits has none
     *
     * @return Array of -limit arguments
     */
    private array function buildLimitArgs(required struct limits, required numeric timeout) {
        var allLimits = duplicate(arguments.limits);
        if(!allLimits.keyExists("time")) {
            allLimits.time = arguments.timeout;
        }

        var limitArgs = [];
        allLimits.each((resource, value) => {
            limitArgs.append(["-limit", lCase(resource), "#value#"], true);
        });
        return limitArgs;
    }

    /**
     * Build the arguments to adjust quality and shrink-to-fit path, writing it to each of outputPaths from a single decode
     *
     * @path        Full path to source image
     * @source      Source's header info ex: {format: 'JPEG', width: 4032, height: 3024}
     * @outputPaths Full paths to write, the format of each is determined by its extension
     * @quality     1-100 quality of image
     * @resize      Max width/height in pixels to shrink to
     * @strip       Whether to strip metadata
     * @autoOrient  Whether to rotate/flip the image upright using its EXIF orientation tag
     *
     * @return Arguments to pass to writeOutputs()
     */
    private array function buildConvertArgs(
        required string path,
        required struct source,
        required array outputPaths,
        required numeric quality,
        required numeric resize,
        required boolean strip,
        required boolean autoOrient
    ) {
        // magick writes its final argument - every earlier output is written mid-pipeline with -write
        var lastIndex = arguments.outputPaths.len();
        var writeArgs = [];
        arguments.outputPaths.each((outputPath, index) => {
            if(index < lastIndex) {
                writeArgs.append(["-write", outputPath], true);
            }
        });

        return flattenArgs([
            jpegSizeHint(arguments.resize, arguments.source),
            arguments.path,
            orientAndStripArgs(arguments.autoOrient, arguments.strip),
            "-quality",
            arguments.quality,
            "-resize",
            "#arguments.resize#x#arguments.resize#>",
            writeArgs,
            arguments.outputPaths[lastIndex]
        ]);
    }

    /**
     * Build a resize() output's ImageMagick geometry string and destination path
     *
     * @output   The output struct, already validated ex: {resizeDir: '../', width: 100, height: 200}
     * @fileName Source image filename to use for the destination file
     *
     * @return Struct of {outputPath, geometry, maxDimension}
     */
    private struct function buildResizeOutput(required struct output, required string fileName) {
        var hasWidth  = arguments.output.keyExists("width") && len(arguments.output.width);
        var hasHeight = arguments.output.keyExists("height") && len(arguments.output.height);
        var geometry  = "";

        if(hasWidth && hasHeight) {
            // ! forces the exact dimensions, ignoring aspect ratio
            geometry = "#arguments.output.width#x#arguments.output.height#!";
        }
        else if(hasWidth) {
            geometry = "#arguments.output.width#";
        }
        else {
            geometry = "x#arguments.output.height#";
        }

        return {
            outputPath  : "#normalizePath(arguments.output.resizeDir)#/#arguments.fileName#",
            geometry    : geometry,
            maxDimension: max(hasWidth ? arguments.output.width : 0, hasHeight ? arguments.output.height : 0)
        };
    }

    /**
     * Read hint letting the JPEG decoder skip straight to a reduced scale instead of decoding every pixel
     * Requests at least 2x the target so resampling quality is unaffected - ignored by other formats
     * The decoder upscales (up to 2x) a source smaller than the hint in either dimension, so when the source's
     * dimensions are known the hint is skipped for those - a shrink-only resize (ex: 1200x1200>) would otherwise keep the upscale
     *
     * @maxDimension Largest target width/height in pixels the command will resize to
     * @source       (Optional) Source's dimensions ex: {width: 4032, height: 3024}
     *
     * @return Arguments to place before the input path
     */
    private array function jpegSizeHint(required numeric maxDimension, struct source = {}) {
        var size = ceiling(arguments.maxDimension * 2);
        if(arguments.source.keyExists("width") && min(arguments.source.width, arguments.source.height) < size) {
            return [];
        }
        return ["-define", "jpeg:size=#size#x#size#"];
    }

    /**
     * Operators applied right after the source is read
     * Auto-orient must run before -strip, which removes the EXIF orientation tag
     *
     * @autoOrient Whether to rotate/flip the image upright using its EXIF orientation tag
     * @strip      Whether to strip metadata
     *
     * @return Arguments to place directly after the input path
     */
    private array function orientAndStripArgs(required boolean autoOrient, required boolean strip) {
        var args = [];
        if(arguments.autoOrient) {
            args.append("-auto-orient");
        }
        if(arguments.strip) {
            args.append("-strip");
        }
        return args;
    }

    /**
     * Flatten a mix of strings and arrays of strings into a single ImageMagick argument array
     *
     * @parts Strings and/or arrays of strings, in command order
     *
     * @return Flat array of argument strings
     */
    private array function flattenArgs(required array parts) {
        var flat = [];
        arguments.parts.each((part) => {
            if(isArray(part)) {
                flat.append(part, true);
            }
            else {
                flat.append("#part#");
            }
        });
        return flat;
    }

    /**
     * Validate argumentCollection of the calling function against its named cbvalidation constraints
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
            throw(type = "ImageMagick.InputValidationException", message = result.getAllErrors().toList("; "));
        }
    }

    /**
     * Throw when two outputs would be written to the same path - the later one would silently overwrite the earlier
     * Compared as canonical paths, so differently spelled paths to the same file match (ex: /images/. and /images)
     * Compared case-insensitively since struct keys are, which also catches same-directory differences in case on Windows
     *
     * @outputPaths Full output paths about to be written
     * @message     Error message to throw with
     *
     * @throws ImageMagick.InputValidationException When outputPaths contains duplicates
     */
    private void function ensureUniqueOutputs(required array outputPaths, required string message) {
        var seen = {};
        arguments.outputPaths.each((outputPath) => {
            seen[createObject("java", "java.io.File").init(outputPath).getCanonicalPath()] = true;
        });

        if(structCount(seen) != arguments.outputPaths.len()) {
            throw(type = "ImageMagick.InputValidationException", message = arguments.message);
        }
    }

    /**
     * Normalize a path to forward slashes without a trailing slash
     *
     * @path File or directory path
     *
     * @return Normalized path
     */
    private string function normalizePath(required string path) {
        return arguments.path.replace("\", "/", "all").reReplace("/$", "");
    }

    /**
     * Express value in larger units for a user-facing message, rounded to 2 decimals ex: inUnits(26214400, 1048576) -> 25
     *
     * @value Value in base units ex: bytes, pixels
     * @unit  Size of the larger unit in base units ex: 1048576 for MB
     *
     * @return Rounded value as a string
     */
    private string function inUnits(required numeric value, required numeric unit) {
        return "#round(arguments.value / arguments.unit * 100) / 100#";
    }

}
