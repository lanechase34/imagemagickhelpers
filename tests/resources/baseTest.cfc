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

}
