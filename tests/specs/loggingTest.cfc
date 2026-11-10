component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("Logging", () => {
            beforeEach(() => {
                setup();
            });

            it("Logs to the module's own log file instead of the app's logs", () => {
                var imageLog = imageService.getImageLog();

                expect(imageLog.getCategory()).toBe("ImageMagickHelpers");

                // A logger with its own appenders never passes messages on to the app's root logger
                expect(imageLog.getAppenders().keyList()).toBe("ImageMagickHelpers");
            });
        });
    }

}
