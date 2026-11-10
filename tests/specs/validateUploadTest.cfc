component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    /**
     * POSTs a real multipart upload to the coldbox endpoint to validate the function validateUpload which expects the formfield
     *
     * @filePath Full path to the file to upload
     * @outputs  Array of {uploadDir, type} structs, same shape validateUpload() expects
     * @fields   (Optional) Struct of optional validateUpload() arguments to post ex: {extensions: 'png', autoOrient: true}
     */
    private struct function postUpload(
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
