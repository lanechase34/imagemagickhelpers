component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('getDimensions()', () => {
            beforeEach(() => {
                setup();
            });

            it('Reads the dimensions of a heic image', () => {
                var dimensions = imageService.getDimensions(expandPath('/tests/resources/heic_example.heic'));
                expect(dimensions.width).toBe(1280);
                expect(dimensions.height).toBe(720);
            });

            it('Reads the dimensions of a jpg image', () => {
                var dimensions = imageService.getDimensions(expandPath('/tests/resources/jpg_example.jpg'));
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it('Reads the dimensions of a jpeg image', () => {
                var dimensions = imageService.getDimensions(expandPath('/tests/resources/jpeg_example.jpeg'));
                expect(dimensions.width).toBe(200);
                expect(dimensions.height).toBe(200);
            });

            it('Reads the dimensions of a png image', () => {
                var dimensions = imageService.getDimensions(expandPath('/tests/resources/png_example.png'));
                expect(dimensions.width).toBe(510);
                expect(dimensions.height).toBe(361);
            });

            it('Throws for a file that is not actually a valid image', () => {
                expect(() => imageService.getDimensions(expandPath('/tests/resources/invalid_example.jpg'))).toThrow('ImageMagick.IdentifyException');
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.getDimensions('')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.getDimensions(expandPath('/tests/resources/does_not_exist.jpg'))).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.getDimensions('#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp')).toThrow('ImageMagick.InputValidationException');
            });
        });
    }

}
