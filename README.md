# ImageMagick Helpers

Helper service layer for interacting with ImageMagick in CFML

This is a ColdBox module - it must be installed into a ColdBox application, which provides the WireBox injection, LogBox logging and cbvalidation it relies on.

## Minimum Requirements

- ColdBox >= 8
- ImageMagick >= 7
- Lucee >= 6
- Adobe ColdFusion >= 2025 (with the `zip` package installed - `cfpm install zip` - which LogBox's RollingFileAppender needs to rotate this module's log file)
- Boxlang >= 1.15

## Installation

Install it into your ColdBox application with CommandBox:

```bash
box install ImageMagickHelpers
```

Ensure you either set the `IMAGEMAGICKPATH` in your .env to the path of the magick executable **OR** in your ColdBox settings structure

```env
IMAGEMAGICKPATH=/usr/bin/magick
```

Check this is the correct path and your CFML server can execute this by running the `verifyImageMagick()` function

## Configuration

Override any of the module's settings in your ColdBox config's `moduleSettings`:

```cfc
moduleSettings = {
    ImageMagickHelpers: {
        imageMagickPath   : '/usr/bin/magick',
        imageMagickTimeout: 30, // Max seconds to wait on a single ImageMagick call
        // ImageMagick -limit resources applied to every call - guards against decompression bombs and runaway conversions
        imageMagickLimits : {
            memory: '256MiB',
            map   : '512MiB',
            disk  : '1GiB',
            width : '16KP',
            height: '16KP'
            // time defaults to imageMagickTimeout
        },
        logDirectory      : '/logs', // Directory for the module's own log file
        expandLogDirectory: true // Whether logDirectory is run through expandPath() - set false for an absolute path
    }
};
```

See the [ImageMagick `-limit` docs](https://imagemagick.org/script/command-line-options.php#limit) for every resource and unit. Images that need more than `memory` spill over to `map`, then `disk`, before ImageMagick gives up.

If your ColdBox config's environment methods (ex: `development()`) set `moduleSettings`, add to it (`moduleSettings.ImageMagickHelpers = {...}`) rather than assigning a new struct, or they replace the settings from `configure()`.

## Logging

The module writes its warnings and errors to its own rolling log file, `imagemagickhelpers.log` in `logDirectory`, through your app's LogBox. They are kept out of your app's logs.

By default `logDirectory` is run through `expandPath()`, so `/logs` is the `logs` folder under your web root. To keep the log next to your app's own log files instead, set `logDirectory` to that directory's absolute path and `expandLogDirectory` to `false` - `expandPath()` would otherwise resolve the absolute path under the web root too:

```cfc
moduleSettings = {
    ImageMagickHelpers: {
        logDirectory      : '/var/log/myapp',
        expandLogDirectory: false
    }
};
```

## Supported Formats

Sources and outputs can be `png`, `jpg`, `jpeg`, `webp`, `heic`, `gif`, `bmp`, `tif`, `tiff`, `svg`, `avif`, or `ico` - as long as your ImageMagick build has the delegate for that format. Run `magick -list format` to check: the mode column shows `r` for formats it can read and `w` for formats it can write.

Many builds can read HEIC but not write it. Convert HEIC sources (ex: iPhone photos) to a format like `webp` or `jpg` - `resize()` writes each output in its source's format, so it can only resize a HEIC source when your build can write HEIC.

## Usage

Instantiate the helper service via the wirebox DSL `Helpers@ImageMagick`

```cfc
property name="imageService" inject="Helpers@ImageMagick";
```

## Examples

Convert an image to webp, rotating it upright from its EXIF orientation, stripping metadata, and capping it at 1600px on its longest side:

```cfc
imageService.convert(
    path       = '/tmp/uploads/photo.jpg',
    outputPath = '/var/www/images/photo.webp',
    quality    = 75,
    resize     = 1600,
    autoOrient = true
);
```

Metadata (EXIF, GPS, ICC profiles) is stripped by default by `convert()`, `crop()`, `resize()`, and `validateUpload()` - pass `strip = false` to keep it. Each of them also takes `autoOrient = true` to rotate phone photos upright before the metadata is gone.

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
        extensions = 'png,jpg,jpeg,heic',
        autoOrient = true
    );
}
```

Each upload is handled in its own UUID-named temp directory under a UUID filename, checked against its extension, a file size limit (`maxFileSize`, 25MB by default), and a pixel limit (`maxPixels`, 100 megapixels by default) before it's ever decoded, and converted to every output from a single decode - at `quality` (50 by default), shrunk to fit `resize` (1200px by default). Set those to the final size you need instead of running `convert()` on the output afterwards, which would lose quality to a second lossy save. Only the first frame of an animated or multi-image upload is kept. A rejected upload throws `ImageMagick.UploadValidationException` with a `message` safe to show your users, and the technical cause in its `detail`.

Every function validates its arguments and throws a typed `ImageMagick.*Exception` (e.g. `ImageMagick.ConversionException`, `ImageMagick.UploadValidationException`) on failure - wrap calls in `try`/`catch` where you need to handle those.

For the full list of functions, their arguments, return values, and exceptions, see [docs/functions.md](https://github.com/lanechase34/imagemagickhelpers/blob/master/docs/functions.md).
