component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

    this.loadColdBox   = true;
    this.unloadColdBox = false;

    function beforeAll() {
        super.beforeAll();
        application.wirebox.autowire(this);

        /**
         * Create a temp dir for testing
         */
        tempDir = expandPath("temp/#createUUID()#");
        directoryCreate(tempDir);
    }

    function afterAll() {
        super.afterAll();

        /**
         * Delete temp dir
         */
        directoryDelete(tempDir, true);
    }

    /**
     * Creates a fresh, empty directory under tempDir for a single test to resize into
     */
    public string function newDir() {
        var dir = tempDir & "/" & createUUID();
        directoryCreate(dir);
        return dir;
    }

    /**
     * Counts the service's temp directories matching pattern, to confirm they're cleaned up
     *
     * @pattern Directory name filter ex: 'imagemagick-output-*'
     */
    public numeric function countTempDirs(required string pattern) {
        return directoryList(
            getTempDirectory(),
            false,
            "name",
            arguments.pattern
        ).len();
    }

    /**
     * Reads the EXIF orientation ImageMagick reports for an image's first frame
     * Returns 'Undefined' when the image has no orientation metadata (ex: it was stripped)
     */
    public string function getOrientation(required string path) {
        var result = "";

        cfexecute(
            name      = getInstance("Helpers@ImageMagick").getImageMagickPath(),
            arguments = [
                "identify",
                "-format",
                "%[orientation]",
                "#arguments.path#[0]"
            ],
            variable = "local.result",
            timeout  = 30
        );

        return trim(result);
    }

    /**
     * Counts the frames ImageMagick reads from an image ex: 2 for a two-frame animated gif
     */
    public numeric function getFrameCount(required string path) {
        var result = "";

        cfexecute(
            name      = getInstance("Helpers@ImageMagick").getImageMagickPath(),
            arguments = [
                "identify",
                "-ping",
                "-format",
                "%n\n",
                arguments.path
            ],
            variable = "local.result",
            timeout  = 30
        );

        // %n is printed once per frame
        return val(listFirst(trim(result), chr(10)));
    }

    /**
     * Whether the configured ImageMagick build can write format - ex: many builds read HEIC but can't write it
     *
     * @format ImageMagick format name ex: 'HEIC'
     */
    public boolean function canWrite(required string format) {
        var result = "";

        cfexecute(
            name      = getInstance("Helpers@ImageMagick").getImageMagickPath(),
            arguments = ["-list", "format"],
            variable  = "local.result",
            timeout   = 30
        );

        // Each line is the format, an optional * for native blob support, its module, then its mode
        // ex: "     HEIC  HEIC      r--   High Efficiency Image Format"
        return reFindNoCase("(^|\n)\s*#arguments.format#\*?\s+\S+\s+rw", result) > 0;
    }

    /**
     * POSTs a real multipart upload to the coldbox endpoint to validate the function validateUpload which expects the formfield
     *
     * @filePath Full path to the file to upload
     * @outputs  Array of {uploadDir, type} structs, same shape validateUpload() expects
     * @fields   (Optional) Struct of optional validateUpload() arguments to post ex: {extensions: 'png', autoOrient: true}
     */
    public struct function postUpload(
        required string filePath,
        required array outputs,
        struct fields = {}
    ) {
        var uploadUrl = "http://127.0.0.1:60299/tests/index.cfm/upload";

        cfhttp(
            url     = uploadUrl,
            method  = "POST",
            result  = "local.httpResult",
            timeout = 30
        ) {
            cfhttpparam(
                type  = "formfield",
                name  = "outputs",
                value = serializeJSON(arguments.outputs)
            );
            for(var name in arguments.fields) {
                cfhttpparam(
                    type  = "formfield",
                    name  = name,
                    value = arguments.fields[name]
                );
            }
            cfhttpparam(
                type = "file",
                name = "file",
                file = arguments.filePath
            );
        }

        return deserializeJSON(httpResult.fileContent);
    }

}
