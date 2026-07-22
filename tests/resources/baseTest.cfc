component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

    this.loadColdBox   = true;
    this.unloadColdBox = false;

    function beforeAll() {
        super.beforeAll();
        application.wirebox.autowire(this);

        /**
         * Create a temp dir for testing
         */
        tempDir = expandPath('temp/#createUUID()#');
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
        var dir = tempDir & '/' & createUUID();
        directoryCreate(dir);
        return dir;
    }

}
