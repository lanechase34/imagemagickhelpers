component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
    }

    function afterAll() {
        super.afterAll();
    }

    /**
     * POSTs a a real muiltipart upload to the coldbox endpoint to validate the function validateUpload which expects the formfield
     *
     * @filePath   Full path to the file to upload
     * @outputs    Array of {uploadDir, type} structs, same shape validateUpload() expects
     * @extensions (Optional) Comma-delimited list of allowed extensions
     */
    private struct function postUpload(
        required string filePath,
        required array outputs,
        string extensions
    ) {
        var uploadUrl = 'http://127.0.0.1:60299/tests/index.cfm/upload';

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
            if(structKeyExists(arguments, 'extensions')) {
                cfhttpparam(
                    type  = "formfield",
                    name  = "extensions",
                    value = arguments.extensions
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
        describe('validateUpload()', () => {
            beforeEach(() => {
                setup();
            });

            it('Validates and converts a real uploaded jpg', () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs  = [{uploadDir: uploadDir, type: 'jpg'}]
                );

                expect(response.success).toBeTrue();
                expect(len(response.filename)).toBe(32);
                expect(fileExists(uploadDir & '/' & response.filename & '.jpg')).toBeTrue();
            });

            it('Converts a single upload to multiple output types', () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath('/tests/resources/png_example.png'),
                    outputs  = [
                        {uploadDir: uploadDir, type: 'jpg'},
                        {uploadDir: uploadDir, type: 'webp'}
                    ]
                );

                expect(response.success).toBeTrue();
                expect(fileExists(uploadDir & '/' & response.filename & '.jpg')).toBeTrue();
                expect(fileExists(uploadDir & '/' & response.filename & '.webp')).toBeTrue();
            });

            it('Rejects an upload with a disallowed extension', () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath   = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs    = [{uploadDir: uploadDir, type: 'jpg'}],
                    extensions = 'png'
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe('ImageMagick.UploadValidationException');
            });

            it('Rejects an upload that is not actually a valid image', () => {
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath('/tests/resources/invalid_example.jpg'),
                    outputs  = [{uploadDir: uploadDir, type: 'jpg'}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe('ImageMagick.UploadValidationException');
            });

            it('Rejects an upload whose content format does not match its claimed extension (spoofed-extension bypass)', () => {
                // spoofed_example.png is real jpg_example.jpg bytes saved under a .png name - a real
                // image ImageMagick would identify as JPEG despite the extension claiming png, the same
                // extension/content mismatch a crafted MVG/SVG payload disguised as a raster image would rely on
                var uploadDir = newDir();
                var response  = postUpload(
                    filePath = expandPath('/tests/resources/spoofed_example.png'),
                    outputs  = [{uploadDir: uploadDir, type: 'png'}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe('ImageMagick.UploadValidationException');
            });

            it('Rejects an upload whose uploadDir is a UNC network path (SSRF/credential-leak via forced SMB auth)', () => {
                var response = postUpload(
                    filePath = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs  = [{uploadDir: '\\attacker.test\share', type: 'jpg'}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe('ImageMagick.InputValidationException');
            });

            it('Rejects an upload whose uploadDir starts with a pipe (ImageMagick PIPE coder command execution)', () => {
                var response = postUpload(
                    filePath = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs  = [{uploadDir: '|touch /tmp/pwned', type: 'jpg'}]
                );

                expect(response.success).toBeFalse();
                expect(response.type).toBe('ImageMagick.InputValidationException');
            });
        });
    }

}
