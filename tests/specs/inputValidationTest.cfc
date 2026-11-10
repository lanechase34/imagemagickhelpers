component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService  = getInstance("Helpers@ImageMagick");
        safePath      = getInstance("safePathValidator@ImageMagick");
        validImage    = expandPath("/tests/resources/jpg_example.jpg");
        unsafeLiteral = "|touch /tmp/pwned";
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        var unsafeValues = [
            {label: "empty", value: ""},
            {label: "containing a double-quote character", value: "/tmp/out""; rm -rf /tmp.jpg"},
            {
                label: "a UNC network path (SSRF/credential-leak via forced SMB auth)",
                value: "\\attacker.test\share\evil.jpg"
            },
            {label: "a protocol-relative network path", value: "//attacker.test/share/evil.jpg"},
            {label: "starting with a pipe (ImageMagick PIPE coder command execution)", value: "|touch /tmp/pwned"},
            {label: "an ImageMagick protocol prefix (SSRF via https: delegate)", value: "https://attacker.test/exfil"},
            {label: "an ImageMagick coder prefix (local file read via label:@)", value: "label:@/etc/passwd"}
        ];

        // Source paths and output directories must also exist - built as copies so unsafeValues stays untouched for outputPath
        var sourcePathCases = duplicate(unsafeValues);
        sourcePathCases.append({label: "a file that does not exist", value: expandPath("/tests/resources/does_not_exist.jpg")});

        var outputDirCases = duplicate(unsafeValues);
        outputDirCases.append({label: "a directory that does not exist", value: expandPath("/tests/temp/does_not_exist_dir")});

        describe("Source path validation", () => {
            sourcePathCases.each((testCase) => {
                it(
                    title = "Rejects a source path #testCase.label#",
                    data  = testCase,
                    body  = (data) => {
                        expect(() => imageService.identify(data.value)).toThrow("ImageMagick.InputValidationException");
                    }
                );
            });
        });

        describe("Output path validation", () => {
            unsafeValues.each((testCase) => {
                it(
                    title = "Rejects an outputPath #testCase.label#",
                    data  = testCase,
                    body  = (data) => {
                        expect(() => imageService.convert(path = validImage, outputPath = data.value)).toThrow("ImageMagick.InputValidationException");
                    }
                );
            });

            it("Does not mistake a Windows drive letter for a coder prefix", () => {
                expect(safePath.isUnsafePath("C:\images\out.jpg")).toBeFalse();
                expect(safePath.isUnsafePath("c:/images/out.jpg")).toBeFalse();
            });
        });

        describe("Output directory validation", () => {
            outputDirCases.each((testCase) => {
                it(
                    title = "Rejects a resizeDir #testCase.label#",
                    data  = testCase,
                    body  = (data) => {
                        expect(() => imageService.resize(path = validImage, outputs = [{resizeDir: data.value, width: 10}])).toThrow("ImageMagick.InputValidationException");
                    }
                );
            });
        });

        // Guards against a function or argument being added without its constraint bundle attached
        describe("Every function validates its path arguments", () => {
            // Assigned before iterating
            var pathArgCases = [
                {label: "identify() path", call: () => imageService.identify(unsafeLiteral)},
                {label: "getDimensions() path", call: () => imageService.getDimensions(unsafeLiteral)},
                {
                    label: "convert() path",
                    call : () => imageService.convert(path = unsafeLiteral, outputPath = tempDir & "/out.jpg")
                },
                {
                    label: "crop() path",
                    call : () => imageService.crop(
                        path       = unsafeLiteral,
                        outputPath = tempDir & "/out.jpg",
                        width      = 10,
                        height     = 10
                    )
                },
                {
                    label: "crop() outputPath",
                    call : () => imageService.crop(
                        path       = validImage,
                        outputPath = unsafeLiteral,
                        width      = 10,
                        height     = 10
                    )
                },
                {
                    label: "autoOrient() path",
                    call : () => imageService.autoOrient(path = unsafeLiteral, outputPath = tempDir & "/out.jpg")
                },
                {
                    label: "autoOrient() outputPath",
                    call : () => imageService.autoOrient(path = validImage, outputPath = unsafeLiteral)
                },
                {
                    label: "resize() path",
                    call : () => imageService.resize(path = unsafeLiteral, outputs = [{resizeDir: tempDir, width: 10}])
                },
                {
                    label: "validateUpload() uploadDir",
                    call : () => imageService.validateUpload(
                        formField = "file",
                        outputs   = [{uploadDir: unsafeLiteral, type: "jpg"}]
                    )
                }
            ];

            pathArgCases.each((testCase) => {
                it(
                    title = "Validates #testCase.label#",
                    data  = testCase,
                    body  = (data) => {
                        expect(data.call).toThrow("ImageMagick.InputValidationException");
                    }
                );
            });
        });

        // validateUpload() validates its arguments before touching the upload, so these need no real multipart request
        describe("Supported extensions", () => {
            it("Rejects an output type that is not a supported extension (path traversal / arbitrary coder via type)", () => {
                expect(() => imageService.validateUpload(
                    formField = "file",
                    outputs   = [{uploadDir: tempDir, type: "\..\..\evil.png"}]
                )).toThrow("ImageMagick.InputValidationException");
                expect(() => imageService.validateUpload(formField = "file", outputs = [{uploadDir: tempDir, type: "html"}])).toThrow("ImageMagick.InputValidationException");
            });

            it("Rejects an extensions list containing an unsupported extension", () => {
                expect(() => imageService.validateUpload(
                    formField  = "file",
                    outputs    = [{uploadDir: tempDir, type: "jpg"}],
                    extensions = "png,jfif"
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Rejects an empty extensions list", () => {
                expect(() => imageService.validateUpload(
                    formField  = "file",
                    outputs    = [{uploadDir: tempDir, type: "jpg"}],
                    extensions = ""
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Supports exactly the extensions the service can map to a mime type and detected format", () => {
                var supported = getInstance("Constraints@ImageMagickHelpers").get("validateUpload").extensions[
                    "supportedExtensionsValidator@ImageMagick"
                ];
                var sortList = (list) => {
                    var items = listToArray(lCase(list));
                    arraySort(items, "text");
                    return items.toList();
                };

                expect(sortList(supported)).toBe(sortList(imageService.getExtToMime().keyList()));
                expect(sortList(supported)).toBe(sortList(imageService.getExtToFormat().keyList()));
            });
        });

        describe("Duplicate outputs", () => {
            it("Rejects two resize outputs sharing a resizeDir, which would overwrite each other", () => {
                expect(() => imageService.resize(
                    path    = validImage,
                    outputs = [
                        {resizeDir: tempDir, width: 10},
                        {resizeDir: tempDir & "/", height: 10}
                    ]
                )).toThrow("ImageMagick.InputValidationException");
            });

            it("Rejects two upload outputs sharing an uploadDir and type", () => {
                expect(() => imageService.validateUpload(
                    formField = "file",
                    outputs   = [
                        {uploadDir: tempDir, type: "jpg"},
                        {uploadDir: tempDir, type: "JPG"}
                    ]
                )).toThrow("ImageMagick.InputValidationException");
            });
        });
    }

}
