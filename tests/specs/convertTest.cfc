component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('convert()', () => {
            beforeEach(() => {
                setup();
            });

            it('Converts an image, leaving dimensions unchanged when under the resize bound', () => {
                var outputPath = tempDir & '/' & createUUID() & '.jpg';

                imageService.convert(path = expandPath('/tests/resources/jpg_example.jpg'), outputPath = outputPath);

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it('Shrinks an image that exceeds the resize bound, preserving aspect ratio', () => {
                var outputPath = tempDir & '/' & createUUID() & '.png';

                imageService.convert(
                    path       = expandPath('/tests/resources/png_example.png'),
                    outputPath = outputPath,
                    resize     = 100
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(71);
            });

            it('Converts with a custom quality', () => {
                var outputPath = tempDir & '/' & createUUID() & '.jpg';

                imageService.convert(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = outputPath,
                    quality    = 10
                );

                expect(fileExists(outputPath)).toBeTrue();
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.convert(path = '', outputPath = tempDir & '/out.jpg')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.convert(
                    path       = expandPath('/tests/resources/does_not_exist.jpg'),
                    outputPath = tempDir & '/out.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.convert(
                    path       = '#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp',
                    outputPath = tempDir & '/out.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an empty outputPath', () => {
                expect(() => imageService.convert(path = expandPath('/tests/resources/jpg_example.jpg'), outputPath = '')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an outputPath containing a double-quote character', () => {
                expect(() => imageService.convert(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = '#tempDir#/out"; rm -rf /tmp.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a quality outside the 0-100 range', () => {
                expect(() => imageService.convert(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = tempDir & '/out.jpg',
                    quality    = 101
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a non-positive resize', () => {
                expect(() => imageService.convert(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = tempDir & '/out.jpg',
                    resize     = 0
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when ImageMagick fails to produce the output file', () => {
                expect(() => imageService.convert(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = tempDir & '/does_not_exist_subdir/out.jpg'
                )).toThrow('ImageMagick.ConversionException');
            });
        });
    }

}
