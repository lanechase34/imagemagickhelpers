component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('crop()', () => {
            beforeEach(() => {
                setup();
            });

            it('Crops a jpg image to exact target dimensions', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpg';

                imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = outputPath,
                    width      = 100,
                    height     = 150
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(150);
            });

            it('Crops a png image, scaling to cover and trimming overflow from the center when the aspect ratio differs', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.png';

                imageService.crop(
                    path       = expandPath('/tests/resources/png_example.png'),
                    outputPath = outputPath,
                    width      = 200,
                    height     = 200
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it('Crops a jpeg image', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpeg';

                imageService.crop(
                    path       = expandPath('/tests/resources/jpeg_example.jpeg'),
                    outputPath = outputPath,
                    width      = 180,
                    height     = 180
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(180);
                expect(dimensions.height).toBe(180);
            });

            it('Crops a heic image', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpg';

                imageService.crop(
                    path       = expandPath('/tests/resources/heic_example.heic'),
                    outputPath = outputPath,
                    width      = 300,
                    height     = 400
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(300);
                expect(dimensions.height).toBe(400);
            });

            it('Upscales an image smaller than the target dimensions to exactly cover them', () => {
                var outputPath = expandPath(tempDir) & '/' & createUUID() & '.jpg';

                imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = outputPath,
                    width      = 400,
                    height     = 300
                );

                expect(fileExists(outputPath)).toBeTrue();
                var dimensions = imageService.getDimensions(outputPath);
                expect(dimensions.width).toBe(400);
                expect(dimensions.height).toBe(300);
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.crop(
                    path       = '',
                    outputPath = expandPath(tempDir) & '/out.jpg',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/does_not_exist.jpg'),
                    outputPath = expandPath(tempDir) & '/out.jpg',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.crop(
                    path       = '#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp',
                    outputPath = expandPath(tempDir) & '/out.jpg',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an empty outputPath', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = '',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an outputPath containing a double-quote character', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = '#expandPath(tempDir)#/out"; rm -rf /tmp.jpg',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a non-positive width', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = expandPath(tempDir) & '/out.jpg',
                    width      = 0,
                    height     = 100
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a non-positive height', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = expandPath(tempDir) & '/out.jpg',
                    width      = 100,
                    height     = 0
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when ImageMagick fails to produce the output file', () => {
                expect(() => imageService.crop(
                    path       = expandPath('/tests/resources/jpg_example.jpg'),
                    outputPath = expandPath(tempDir) & '/does_not_exist_subdir/out.jpg',
                    width      = 100,
                    height     = 100
                )).toThrow('ImageMagick.CropException');
            });
        });
    }

}
