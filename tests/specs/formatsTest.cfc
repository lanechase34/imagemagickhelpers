component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        // Every source format runs through every function. Expected sizes are ImageMagick's, rounded to whole pixels
        var sources = [
            {
                label    : "png",
                file     : "png_example.png",
                format   : "PNG",
                size     : {width: 510, height: 361},
                converted: {width: 150, height: 106},
                byWidth  : {width: 100, height: 71},
                byHeight : {width: 71, height: 50},
                uploaded : {width: 510, height: 361}
            },
            {
                label    : "jpg",
                file     : "jpg_example.jpg",
                format   : "JPEG",
                size     : {width: 200, height: 200},
                converted: {width: 150, height: 150},
                byWidth  : {width: 100, height: 100},
                byHeight : {width: 50, height: 50},
                uploaded : {width: 200, height: 200}
            },
            {
                label    : "jpeg",
                file     : "jpeg_example.jpeg",
                format   : "JPEG",
                size     : {width: 200, height: 200},
                converted: {width: 150, height: 150},
                byWidth  : {width: 100, height: 100},
                byHeight : {width: 50, height: 50},
                uploaded : {width: 200, height: 200}
            },
            // Laid out like an iPhone portrait photo - a 300x200 coded image the decoder rotates upright to 200x300
            {
                label    : "heic",
                file     : "oriented_example.heic",
                format   : "HEIC",
                size     : {width: 200, height: 300},
                converted: {width: 100, height: 150},
                byWidth  : {width: 100, height: 150},
                byHeight : {width: 33, height: 50},
                uploaded : {width: 200, height: 300}
            }
        ];

        // Output types every source is converted to, and the format ImageMagick should detect for each
        var outputFormats = {jpg: "JPEG", png: "PNG", webp: "WEBP"};

        sources.each((source) => {
            var spec           = duplicate(source);
            spec.outputFormats = outputFormats;

            describe("A #source.label# source", () => {
                it(
                    title = "identify() and getDimensions() read it",
                    data  = spec,
                    body  = (data) => {
                        var path = expandPath("/tests/resources/#data.file#");

                        expect(imageService.identify(path)).toBe(data.format);
                        expect(imageService.getDimensions(path)).toBe(data.size);
                    }
                );

                it(
                    title = "convert() writes it as jpg, png, and webp",
                    data  = spec,
                    body  = (data) => {
                        data.outputFormats.each((type, format) => {
                            var outputPath = tempDir & "/" & createUUID() & "." & type;

                            imageService.convert(
                                path       = expandPath("/tests/resources/#data.file#"),
                                outputPath = outputPath,
                                resize     = 150
                            );

                            expect(imageService.identify(outputPath)).toBe(format, "#type# output format");
                            expect(imageService.getDimensions(outputPath)).toBe(data.converted, "#type# output size");
                        });
                    }
                );

                it(
                    title = "crop() crops it to exact dimensions",
                    data  = spec,
                    body  = (data) => {
                        var outputPath = tempDir & "/" & createUUID() & ".jpg";

                        imageService.crop(
                            path       = expandPath("/tests/resources/#data.file#"),
                            outputPath = outputPath,
                            width      = 120,
                            height     = 80
                        );

                        expect(imageService.getDimensions(outputPath)).toBe({width: 120, height: 80});
                    }
                );

                it(
                    title = "autoOrient() writes it at the same size",
                    data  = spec,
                    body  = (data) => {
                        var outputPath = tempDir & "/" & createUUID() & ".jpg";

                        imageService.autoOrient(
                            path       = expandPath("/tests/resources/#data.file#"),
                            outputPath = outputPath
                        );

                        expect(imageService.getDimensions(outputPath)).toBe(data.size);
                    }
                );

                it(
                    title = "resize() writes it by width and by height, in its own format",
                    data  = spec,
                    body  = (data) => {
                        var runResize = () => imageService.resize(
                            path    = expandPath("/tests/resources/#data.file#"),
                            outputs = [
                                {resizeDir: newDir(), width: 100},
                                {resizeDir: newDir(), height: 50}
                            ]
                        );

                        // resize() keeps the source's filename and so its format - a build that can't write it fails
                        if(!canWrite(data.format)) {
                            expect(runResize).toThrow("ImageMagick.ResizeException");
                            return;
                        }

                        var results = runResize();
                        expect(imageService.identify(results[1])).toBe(data.format);
                        expect(imageService.getDimensions(results[1])).toBe(data.byWidth);
                        expect(imageService.getDimensions(results[2])).toBe(data.byHeight);
                    }
                );

                it(
                    title = "validateUpload() accepts it and converts it to jpg, png, and webp",
                    data  = spec,
                    body  = (data) => {
                        var uploadDir = newDir();
                        var outputs   = data.outputFormats
                            .keyArray()
                            .map((type) => {
                                return {uploadDir: uploadDir, type: type};
                            });
                        var response = postUpload(
                            filePath = expandPath("/tests/resources/#data.file#"),
                            outputs  = outputs
                        );

                        expect(response.success).toBeTrue("#response.message ?: ""# | #response.detail ?: ""#");
                        data.outputFormats.each((type, format) => {
                            var outputPath = uploadDir & "/" & response.filename & "." & type;

                            expect(imageService.identify(outputPath)).toBe(format, "#type# output format");
                            expect(imageService.getDimensions(outputPath)).toBe(data.uploaded, "#type# output size");
                        });
                    }
                );
            });
        });
    }

}
