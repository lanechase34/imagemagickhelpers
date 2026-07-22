component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('autoOrient()', () => {
            beforeEach(() => {
                setup();
            });

            it('Physically rotates an image with an EXIF orientation tag and normalizes its dimensions', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpg';

                // oriented_example.jpg is 300x200 with EXIF Orientation=6 (rotate 90 CW) -
                // once physically applied, the stored pixel dimensions swap to 200x300
                imageService.autoOrient(
                    path       = expandPath('/tests/resources/oriented_example.jpg'),
                    outputPath = outputPath
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(300);
            });

            it('Leaves an image with no EXIF orientation tag dimensionally unchanged', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.png';

                imageService.autoOrient(path = expandPath('/tests/resources/png_example.png'), outputPath = outputPath);

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(510);
                expect(dimensions.height).toBe(361);
            });

            it('Auto-orients a jpeg image', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpeg';

                imageService.autoOrient(
                    path       = expandPath('/tests/resources/jpeg_example.jpeg'),
                    outputPath = outputPath
                );

                expect(fileExists(outputPath)).toBeTrue();
            });

            it('Auto-orients a heic image', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpg';

                imageService.autoOrient(
                    path       = expandPath('/tests/resources/heic_example.heic'),
                    outputPath = outputPath
                );

                expect(fileExists(outputPath)).toBeTrue();
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.autoOrient(path = '', outputPath = expandPath(tempDir) & '/out.jpg')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.autoOrient(
                    path       = expandPath('/tests/resources/does_not_exist.jpg'),
                    outputPath = expandPath(tempDir) & '/out.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.autoOrient(
                    path       = '#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp',
                    outputPath = expandPath(tempDir) & '/out.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an empty outputPath', () => {
                expect(() => imageService.autoOrient(path = expandPath('/tests/resources/jpg_example.jpg'), outputPath = '')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an outputPath containing a double-quote character', () => {
                expect(() => imageService.autoOrient(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = '#expandPath(tempDir)#/out"; rm -rf /tmp.jpg'
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when ImageMagick fails to produce the output file', () => {
                expect(() => imageService.autoOrient(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = expandPath(tempDir) & '/does_not_exist_subdir/out.jpg'
                )).toThrow('ImageMagick.OrientException');
            });
        });
    }

}
