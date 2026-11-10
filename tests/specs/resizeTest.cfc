component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("resize()", () => {
            beforeEach(() => {
                setup();
            });

            it("Resizes each output by its own width/height rules, returning paths in outputs order", () => {
                var widthDir  = newDir();
                var heightDir = newDir();
                var forcedDir = newDir();

                // png_example.png is 510x361
                var results = imageService.resize(
                    path    = expandPath("/tests/resources/png_example.png"),
                    outputs = [
                        {resizeDir: widthDir, width: 100},
                        {resizeDir: heightDir & "/", height: 100},
                        {
                            resizeDir: forcedDir,
                            width    : 50,
                            height   : 50
                        }
                    ]
                );

                // resize() normalizes resizeDir to forward slashes and strips a trailing slash before building the output path
                expect(results).toBe([
                    widthDir.replace("\", "/", "all") & "/png_example.png",
                    heightDir.replace("\", "/", "all") & "/png_example.png",
                    forcedDir.replace("\", "/", "all") & "/png_example.png"
                ]);

                // Width only and height only preserve aspect ratio
                expect(imageService.getDimensions(results[1])).toBe({width: 100, height: 71});
                expect(imageService.getDimensions(results[2])).toBe({width: 141, height: 100});

                // Both forces exact dimensions, ignoring aspect ratio
                expect(imageService.getDimensions(results[3])).toBe({width: 50, height: 50});
            });

            it("Handles a source path using backslashes", () => {
                var backslashed = replace(
                    expandPath("/tests/resources/jpg_example.jpg"),
                    "/",
                    "\",
                    "all"
                );
                var results = imageService.resize(path = backslashed, outputs = [{resizeDir: newDir(), width: 60}]);

                expect(fileExists(results[1])).toBeTrue();
            });

            it("Strips EXIF metadata by default and preserves it when strip is false", () => {
                var stripped = imageService.resize(
                    path    = expandPath("/tests/resources/oriented_example.jpg"),
                    outputs = [{resizeDir: newDir(), width: 100}]
                );
                var preserved = imageService.resize(
                    path    = expandPath("/tests/resources/oriented_example.jpg"),
                    outputs = [{resizeDir: newDir(), width: 100}],
                    strip   = false
                );

                expect(getOrientation(stripped[1])).toBe("Undefined");
                expect(getOrientation(preserved[1])).toBe("RightTop");
            });

            it("Rotates the image upright before resizing when autoOrient is true", () => {
                // oriented_example.jpg is 300x200 with EXIF Orientation=6 - upright it is 200x300
                var results = imageService.resize(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputs    = [{resizeDir: newDir(), width: 100}],
                    autoOrient = true
                );

                expect(imageService.getDimensions(results[1])).toBe({width: 100, height: 150});
            });

            it("Resizes in place when resizeDir is the source's own directory", () => {
                var dir  = newDir();
                var path = dir & "/png_example.png";
                fileCopy(expandPath("/tests/resources/png_example.png"), path);

                var results = imageService.resize(path = path, outputs = [{resizeDir: dir, width: 100}]);

                expect(results[1]).toBe(path.replace("\", "/", "all"));
                expect(imageService.getDimensions(path)).toBe({width: 100, height: 71});
            });

            it("Throws for an empty outputs array", () => {
                expect(() => imageService.resize(path = expandPath("/tests/resources/jpg_example.jpg"), outputs = [])).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws when an output is missing resizeDir", () => {
                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs = [{width: 100}]
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws when an output is missing both width and height", () => {
                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs = [{resizeDir: newDir()}]
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws when an output width or height is under 1px", () => {
                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs = [{resizeDir: newDir(), width: 0}]
                )).toThrow("ImageMagick.InputValidationException");
                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs = [{resizeDir: newDir(), height: -10}]
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws ImageMagick.ResizeException when ImageMagick fails to produce an output", () => {
                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/invalid_example.jpg"),
                    outputs = [{resizeDir: newDir(), width: 100}]
                )).toThrow("ImageMagick.ResizeException");
            });

            it("Writes no outputs when a later output fails", () => {
                var dirA = newDir();
                var dirB = newDir();

                // Pre-create a directory at the exact path dirB's output file would be moved to,
                // forcing that second output to fail while the first output succeeds
                directoryCreate(dirB & "/jpg_example.jpg");

                expect(() => imageService.resize(
                    path    = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs = [
                        {resizeDir: dirA, width: 100},
                        {resizeDir: dirB, width: 100}
                    ]
                )).toThrow("ImageMagick.ResizeException");

                expect(fileExists(dirA & "/jpg_example.jpg")).toBeFalse();
            });
        });
    }

}
