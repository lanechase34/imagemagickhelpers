component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("crop()", () => {
            beforeEach(() => {
                setup();
            });

            it("Scales to cover and trims overflow from the center when the aspect ratio differs", () => {
                var outputPath = tempDir & "/" & createUUID() & ".png";

                // png_example.png is 510x361
                imageService.crop(
                    path       = expandPath("/tests/resources/png_example.png"),
                    outputPath = outputPath,
                    width      = 200,
                    height     = 200
                );

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it("Upscales an image smaller than the target dimensions to exactly cover them", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.crop(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = outputPath,
                    width      = 400,
                    height     = 300
                );

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(400);
                expect(dimensions.height).toBe(300);
            });

            it("Strips EXIF metadata by default and preserves it when strip is false", () => {
                var strippedPath  = tempDir & "/" & createUUID() & ".jpg";
                var preservedPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.crop(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = strippedPath,
                    width      = 100,
                    height     = 100
                );
                imageService.crop(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = preservedPath,
                    width      = 100,
                    height     = 100,
                    strip      = false
                );

                expect(getOrientation(strippedPath)).toBe("Undefined");
                expect(getOrientation(preservedPath)).toBe("RightTop");
            });

            it("Rotates the image upright before cropping when autoOrient is true", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                // Keeping metadata shows the orientation tag was applied and reset, rather than just stripped
                imageService.crop(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath,
                    width      = 100,
                    height     = 100,
                    strip      = false,
                    autoOrient = true
                );

                expect(getOrientation(outputPath)).toBe("TopLeft");
            });

            it("Throws for a width or height under 1px", () => {
                expect(() => imageService.crop(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/out.jpg",
                    width      = 0,
                    height     = 100
                )).toThrow("ImageMagick.InputValidationException");
                expect(() => imageService.crop(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/out.jpg",
                    width      = 100,
                    height     = -1
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws when the output directory does not exist", () => {
                expect(() => imageService.crop(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/does_not_exist_subdir/out.jpg",
                    width      = 100,
                    height     = 100
                )).toThrow("ImageMagick.CropException");
            });
        });
    }

}
