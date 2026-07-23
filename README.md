# ImageMagick Helpers

Helper service layer for interacting with ImageMagick in CFML

## Minimum Requirements

- ImageMagick >= 7
- Lucee >= 6
- Adobe ColdFusion >= 2025
- Boxlang >= 1.15

## Installation

Ensure you either set the `IMAGEMAGICKPATH` in your .env to the path of the magick executable **OR** in your ColdBox settings structure

```env
IMAGEMAGICKPATH=/usr/bin/magick
```

Check this is the correct path and your CFML server can execute this by running the `verifyImageMagick()` function

## Usage

Instantiate the helper service via the wirebox DSL `Helpers@ImageMagick`

```cfc
property name="imageService" inject="Helpers@ImageMagick";
```

## Examples

Convert an image to webp, stripping metadata, and capping it at 1600px on its longest side:

```cfc
imageService.convert(
    path       = '/tmp/uploads/photo.jpg',
    outputPath = '/var/www/images/photo.webp',
    quality    = 75,
    resize     = 1600
);
```

Generate a few resized versions of the same source image in one call:

```cfc
var resizedPaths = imageService.resize(
    path    = '/tmp/uploads/photo.jpg',
    outputs = [
        {resizeDir: '/var/www/images/small', width: 100},
        {resizeDir: '/var/www/images/banner', width: 1200, height: 400}
    ]
);
```

Validate and convert a real multipart upload in a handler action:

```cfc
function uploadPhoto(event, rc, prc) {
    var fileName = imageService.validateUpload(
        formField  = 'file',
        outputs    = [
            {uploadDir: '/var/www/images/original', type: 'jpg'},
            {uploadDir: '/var/www/images/webp', type: 'webp'}
        ],
        extensions = 'png,jpg,jpeg'
    );
}
```

Every function validates its arguments and throws a typed `ImageMagick.*Exception` (e.g. `ImageMagick.ConversionException`, `ImageMagick.UploadValidationException`) on failure - wrap calls in `try`/`catch` where you need to handle those.

For the full list of functions, their arguments, return values, and exceptions, see [docs/functions.md](docs/functions.md).
