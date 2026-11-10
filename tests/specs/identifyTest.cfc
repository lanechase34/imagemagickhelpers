component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("identify()", () => {
            beforeEach(() => {
                setup();
            });

            it("Returns the detected format of a jpg, png, and heic image", () => {
                expect(imageService.identify(expandPath("/tests/resources/jpg_example.jpg"))).toBe("JPEG");
                expect(imageService.identify(expandPath("/tests/resources/png_example.png"))).toBe("PNG");
                expect(imageService.identify(expandPath("/tests/resources/heic_example.heic"))).toBe("HEIC");
            });

            it("Identifies a file by its actual content rather than its (spoofed) extension", () => {
                // spoofed_example.png is real jpg_example.jpg bytes saved under a .png name
                expect(imageService.identify(expandPath("/tests/resources/spoofed_example.png"))).toBe("JPEG");
            });

            it("Throws for a file that is not actually a valid image", () => {
                expect(() => imageService.identify(expandPath("/tests/resources/invalid_example.jpg"))).toThrow("ImageMagick.IdentifyException");
            });
        });
    }

}
