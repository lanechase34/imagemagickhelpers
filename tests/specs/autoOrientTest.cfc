component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("autoOrient()", () => {
            beforeEach(() => {
                setup();
            });

            it("Physically rotates an image with an EXIF orientation tag and normalizes its dimensions", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                // oriented_example.jpg is 300x200 with EXIF Orientation=6 (rotate 90 CW) -
                // once physically applied, the stored pixel dimensions swap to 200x300
                imageService.autoOrient(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath
                );

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(300);
            });

            it("Does not rotate a HEIC twice - the HEIC decoder already applies its rotation", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                // oriented_example.heic is laid out like an iPhone portrait photo: a 300x200 coded image with an irot
                // rotation and EXIF Orientation=6. The decoder applies irot, so a second turn from the EXIF tag
                // would leave it sideways at 300x200
                imageService.autoOrient(
                    path       = expandPath("/tests/resources/oriented_example.heic"),
                    outputPath = outputPath
                );

                expect(imageService.getDimensions(outputPath)).toBe({width: 200, height: 300});
                expect(getOrientation(outputPath)).toBe("TopLeft");
            });

            it("Leaves an image with no EXIF orientation tag dimensionally unchanged", () => {
                var outputPath = tempDir & "/" & createUUID() & ".png";

                imageService.autoOrient(path = expandPath("/tests/resources/png_example.png"), outputPath = outputPath);

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(510);
                expect(dimensions.height).toBe(361);
            });

            it("Throws when the output directory does not exist", () => {
                expect(() => imageService.autoOrient(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/does_not_exist_subdir/out.jpg"
                )).toThrow("ImageMagick.OrientException");
            });
        });
    }

}
