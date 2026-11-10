component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("convert()", () => {
            beforeEach(() => {
                setup();
            });

            it("Converts an image, leaving dimensions unchanged when under the resize bound", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(path = expandPath("/tests/resources/jpg_example.jpg"), outputPath = outputPath);

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it("Shrinks an image that exceeds the resize bound, preserving aspect ratio", () => {
                var outputPath = tempDir & "/" & createUUID() & ".png";

                imageService.convert(
                    path       = expandPath("/tests/resources/png_example.png"),
                    outputPath = outputPath,
                    resize     = 100
                );

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(71);
            });

            it("Writes the format given by outputPath's extension, decoding heic sources", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                // heic_example.heic is 1280x720 - also over the default 1200 resize bound
                imageService.convert(path = expandPath("/tests/resources/heic_example.heic"), outputPath = outputPath);

                expect(imageService.identify(outputPath)).toBe("JPEG");
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(1200);
                expect(dimensions.height).toBe(675);
            });

            it("Applies the requested quality", () => {
                var lowPath  = tempDir & "/" & createUUID() & ".jpg";
                var highPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(
                    path       = expandPath("/tests/resources/png_example.png"),
                    outputPath = lowPath,
                    quality    = 10
                );
                imageService.convert(
                    path       = expandPath("/tests/resources/png_example.png"),
                    outputPath = highPath,
                    quality    = 90
                );

                expect(getFileInfo(lowPath).size).toBeLT(getFileInfo(highPath).size);
            });

            // oriented_example.jpg is 300x200 with EXIF Orientation=6 (rotate 90 CW)
            it("By default, strips metadata without rotating", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath
                );

                expect(getOrientation(outputPath)).toBe("Undefined");
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(300);
                expect(dimensions.height).toBe(200);
            });

            it("Rotates an image upright using its EXIF orientation tag when autoOrient is true", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath,
                    autoOrient = true
                );

                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(300);
            });

            it("Preserves EXIF metadata when strip is false", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath,
                    strip      = false
                );

                expect(getOrientation(outputPath)).toBe("RightTop");
            });

            it("Rotates upright and resets the orientation tag when autoOrient is true and strip is false", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";

                imageService.convert(
                    path       = expandPath("/tests/resources/oriented_example.jpg"),
                    outputPath = outputPath,
                    autoOrient = true,
                    strip      = false
                );

                // Metadata is kept, but the tag must no longer ask viewers to rotate the already-rotated pixels
                expect(getOrientation(outputPath)).toBe("TopLeft");
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(300);
            });

            it("Throws for a quality outside the 1-100 range", () => {
                expect(() => imageService.convert(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/out.jpg",
                    quality    = 101
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws for a resize under 1px", () => {
                expect(() => imageService.convert(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/out.jpg",
                    resize     = 0
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Throws instead of reporting success when a failed conversion would leave a stale file at outputPath", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";
                fileWrite(outputPath, "stale output from an earlier run");
                // Compare against what landed on disk, not the literal, so how the engine writes text doesn't affect the check
                var staleContents = fileRead(outputPath);

                expect(() => imageService.convert(
                    path       = expandPath("/tests/resources/invalid_example.jpg"),
                    outputPath = outputPath
                )).toThrow("ImageMagick.ConversionException");

                // A failed run never touches outputPath, so the earlier file is left as it was
                expect(fileRead(outputPath)).toBe(staleContents);
            });

            it("Converts an image in place when outputPath is the source", () => {
                var path = tempDir & "/" & createUUID() & ".png";
                fileCopy(expandPath("/tests/resources/png_example.png"), path);

                imageService.convert(path = path, outputPath = path, resize = 100);

                var dimensions = imageService.getDimensions(path);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(71);
            });

            it("Replaces a file already at outputPath", () => {
                var outputPath = tempDir & "/" & createUUID() & ".jpg";
                fileWrite(outputPath, "output from an earlier run");

                imageService.convert(path = expandPath("/tests/resources/png_example.png"), outputPath = outputPath);

                expect(imageService.identify(outputPath)).toBe("JPEG");
            });

            it("Removes its temp output directory whether the conversion succeeds or fails", () => {
                var before = countTempDirs("imagemagick-output-*");

                imageService.convert(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/" & createUUID() & ".jpg"
                );
                expect(() => imageService.convert(
                    path       = expandPath("/tests/resources/invalid_example.jpg"),
                    outputPath = tempDir & "/" & createUUID() & ".jpg"
                )).toThrow("ImageMagick.ConversionException");

                expect(countTempDirs("imagemagick-output-*")).toBe(before);
            });

            it("Keeps ImageMagick's own error in the exception detail", () => {
                // Lucee throws a generic "Error invoking external process" on a non-zero exit, with ImageMagick's error only in its detail
                var error = {};
                try {
                    imageService.convert(
                        path       = expandPath("/tests/resources/invalid_example.jpg"),
                        outputPath = tempDir & "/" & createUUID() & ".jpg"
                    );
                }
                catch(ImageMagick.ConversionException e) {
                    error = e;
                }

                // ImageMagick names the file it failed to read
                expect(error.detail ?: "").toInclude("invalid_example.jpg");
            });

            it("Throws when the output directory does not exist", () => {
                expect(() => imageService.convert(
                    path       = expandPath("/tests/resources/jpg_example.jpg"),
                    outputPath = tempDir & "/does_not_exist_subdir/out.jpg"
                )).toThrow("ImageMagick.ConversionException");
            });
        });
    }

}
