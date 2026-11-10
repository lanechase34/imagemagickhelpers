component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("validateUpload()", () => {
            beforeEach(() => {
                setup();
            });

            it("Validates a real .jpeg upload and converts it under a new UUID filename", () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/jpeg_example.jpeg"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}]
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                expect(len(response.filename)).toBe(32);
                expect(fileExists(uploadDir & "/" & response.filename & ".jpg")).toBeTrue();
            });

            it("Converts a single upload to multiple output types", () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/png_example.png"),
                    outputs  = [
                        {uploadDir: uploadDir, type: "jpg"},
                        {uploadDir: uploadDir, type: "webp"}
                    ]
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                expect(imageService.identify(uploadDir & "/" & response.filename & ".jpg")).toBe("JPEG");
                expect(imageService.identify(uploadDir & "/" & response.filename & ".webp")).toBe("WEBP");
            });

            it("Allows whitespace and mixed case in the extensions list", () => {
                var response = postUpload(
                    filePath = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}],
                    fields   = {extensions: "png, JPG"}
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
            });

            it("Removes its temp directories whether the upload succeeds or is rejected", () => {
                var beforeUploads = countTempDirs("imagemagick-upload-*");
                var beforeOutputs = countTempDirs("imagemagick-output-*");

                postUpload(
                    filePath = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}]
                );
                postUpload(
                    filePath = expandPath("/tests/resources/invalid_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}]
                );

                expect(countTempDirs("imagemagick-upload-*")).toBe(beforeUploads);
                expect(countTempDirs("imagemagick-output-*")).toBe(beforeOutputs);
            });

            // oriented_example.jpg is 300x200 with EXIF Orientation=6 (rotate 90 CW)
            it("By default, strips metadata without rotating", () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/oriented_example.jpg"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}]
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                var outputPath = uploadDir & "/" & response.filename & ".jpg";
                expect(getOrientation(outputPath)).toBe("Undefined");
                expect(imageService.getDimensions(outputPath)).toBe({width: 300, height: 200});
            });

            it("Passes strip and autoOrient through to each conversion", () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/oriented_example.jpg"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}],
                    fields   = {strip: false, autoOrient: true}
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                var outputPath = uploadDir & "/" & response.filename & ".jpg";
                expect(getOrientation(outputPath)).toBe("TopLeft");
                expect(imageService.getDimensions(outputPath)).toBe({width: 200, height: 300});
            });

            // oriented_example.heic is laid out like an iPhone portrait photo: a 300x200 coded image with an irot
            // rotation and EXIF Orientation=6. The decoder applies irot, so it's 200x300 with or without autoOrient
            it("Outputs a rotated HEIC upright, without rotating it twice when autoOrient is true", () => {
                var uploadDir = newDir();
                var plain     = postUpload(
                    filePath = expandPath("/tests/resources/oriented_example.heic"),
                    outputs  = [{uploadDir: uploadDir, type: "webp"}]
                );
                var oriented = postUpload(
                    filePath = expandPath("/tests/resources/oriented_example.heic"),
                    outputs  = [{uploadDir: uploadDir, type: "webp"}],
                    fields   = {autoOrient: true}
                );

                expect(plain.success).toBeTrue("#plain.message ?: ""# | #plain.detail ?: ""#");
                expect(oriented.success).toBeTrue("#oriented.message ?: ""# | #oriented.detail ?: ""#");
                var plainPath    = uploadDir & "/" & plain.filename & ".webp";
                var orientedPath = uploadDir & "/" & oriented.filename & ".webp";
                expect(imageService.getDimensions(plainPath)).toBe({width: 200, height: 300});
                expect(imageService.getDimensions(orientedPath)).toBe({width: 200, height: 300});
            });

            it("Resets a HEIC's EXIF orientation tag when keeping metadata, so viewers don't rotate it again", () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/oriented_example.heic"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}],
                    fields   = {strip: false, autoOrient: true}
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                var outputPath = uploadDir & "/" & response.filename & ".jpg";
                expect(getOrientation(outputPath)).toBe("TopLeft");
                expect(imageService.getDimensions(outputPath)).toBe({width: 200, height: 300});
            });

            it("Passes quality and resize through to each conversion", () => {
                // png_example.png is 510x361
                var uploadDir = newDir();
                var low       = postUpload(
                    filePath = expandPath("/tests/resources/png_example.png"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}],
                    fields   = {quality: 10, resize: 100}
                );
                var high = postUpload(
                    filePath = expandPath("/tests/resources/png_example.png"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}],
                    fields   = {quality: 90, resize: 100}
                );

                expect(low.success).toBeTrue("#low.message ?: ""# | #low.detail ?: ""#");
                expect(high.success).toBeTrue("#high.message ?: ""# | #high.detail ?: ""#");
                var lowPath  = uploadDir & "/" & low.filename & ".jpg";
                var highPath = uploadDir & "/" & high.filename & ".jpg";
                expect(imageService.getDimensions(lowPath)).toBe({width: 100, height: 71});
                expect(getFileInfo(lowPath).size).toBeLT(getFileInfo(highPath).size);
            });

            it("Keeps only the first frame of an animated upload", () => {
                // animated_example.gif has two 40x30 frames - a jpg output would otherwise be written as one file per frame
                expect(getFrameCount(expandPath("/tests/resources/animated_example.gif"))).toBe(2);
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/animated_example.gif"),
                    outputs  = [
                        {uploadDir: uploadDir, type: "gif"},
                        {uploadDir: uploadDir, type: "jpg"}
                    ],
                    fields = {extensions: "gif"}
                );

                expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                expect(directoryList(uploadDir, false, "name").len()).toBe(2);
                expect(getFrameCount(uploadDir & "/" & response.filename & ".gif")).toBe(1);
                expect(imageService.getDimensions(uploadDir & "/" & response.filename & ".jpg")).toBe({width: 40, height: 30});
            });

            it("Rejects an upload with a disallowed extension", () => {
                var response = postUpload(
                    filePath = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}],
                    fields   = {extensions: "png"}
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe("ImageMagick.UploadValidationException");
            });

            it("Rejects an upload that is not actually a valid image", () => {
                var response = postUpload(
                    filePath = expandPath("/tests/resources/invalid_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe("ImageMagick.UploadValidationException");
            });

            it("Rejects an upload whose content format does not match its claimed extension (spoofed-extension bypass)", () => {
                // spoofed_example.png is real jpg_example.jpg bytes saved under a .png name - a real
                // image ImageMagick would identify as JPEG despite the extension claiming png, the same
                // extension/content mismatch a crafted MVG/SVG payload disguised as a raster image would rely on
                var response = postUpload(
                    filePath = expandPath("/tests/resources/spoofed_example.png"),
                    outputs  = [{uploadDir: newDir(), type: "png"}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe("ImageMagick.UploadValidationException");
            });

            it("Rejects an upload over maxFileSize", () => {
                var response = postUpload(
                    filePath = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs  = [{uploadDir: newDir(), type: "jpg"}],
                    fields   = {maxFileSize: 100}
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe("ImageMagick.UploadValidationException");
            });

            it("Rejects an upload over maxPixels before converting it", () => {
                // jpg_example.jpg is 200x200 = 40000 pixels
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath("/tests/resources/jpg_example.jpg"),
                    outputs  = [{uploadDir: uploadDir, type: "jpg"}],
                    fields   = {maxPixels: 39999}
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe("ImageMagick.UploadValidationException");
                expect(directoryList(uploadDir).len()).toBe(0);
            });
        });
    }

}
