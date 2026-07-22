# ImageMagick Helpers

Helper service layer for interacting with ImageMagick in CFML.

## Minimum Requirements

- ImageMagick >= 7
- Lucee >= 6
- Adobe ColdFusion >= 2025
- Boxlang >= 1.15

## Installation

Ensure you either set the `IMAGEMAGICKPATH` in your .env to the path of the magick executable or in your ColdBox settings structure

Ex:

```
IMAGEMAGICKPATH=/usr/bin/magick
```

Check this is the correct path and your CFML server can execute this by running the `verifyImageMagick()` function

## Usage

Instantiate the objects via the wirebox DSL `Helpers@ImageMagick`

Ex:

```
property name="imageService" inject="Helpers@ImageMagick";
```
