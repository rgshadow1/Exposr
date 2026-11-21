// Generates the web build's favicon and app icons from the Exposr logo.
//
//   dart run tool/generate_web_icons.dart
//
// The logo (assets/images/exposr_logo.png) is white on a transparent
// background, which is invisible on a light browser tab and see-through as an
// installed-app icon. So each icon here is the logo set on the same dark
// colour the Android and iOS launcher icons use (#131418, see
// `flutter_launcher_icons` in pubspec.yaml).
//
// Written to web/:
//   favicon.png                  64x64, with softly rounded corners
//   icons/Icon-192.png, Icon-512.png
//   icons/Icon-maskable-192.png, Icon-maskable-512.png
//
// `flutter_launcher_icons` can make web icons too, but it only resizes its
// source image, so it would leave these transparent.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// The tile colour: the same as `adaptive_icon_background` in pubspec.yaml.
final img.Color _background = img.ColorRgba8(0x13, 0x14, 0x18, 0xFF);

void main() {
  final logoFile = File('assets/images/exposr_logo.png');
  if (!logoFile.existsSync()) {
    stderr.writeln('Run this from the project root: assets/images/exposr_logo.png not found.');
    exit(1);
  }

  final source = img.decodePng(logoFile.readAsBytesSync())!;
  final emblem = _cropToContent(source);
  stdout.writeln(
      'Logo artwork: ${emblem.width}x${emblem.height} inside ${source.width}x${source.height}');

  // How much of the tile the logo's longer side fills.
  //  * "any" icons: a comfortable margin.
  //  * maskable icons: an operating system may crop to a circle covering the
  //    middle 80%, so the artwork stays well inside it.
  //  * the favicon: as large as it can be, because it is shown at 16-32px.
  _write('web/favicon.png', _tile(64, 0.80, corner: 0.20, emblem: emblem));
  _write('web/icons/Icon-192.png', _tile(192, 0.66, emblem: emblem));
  _write('web/icons/Icon-512.png', _tile(512, 0.66, emblem: emblem));
  _write('web/icons/Icon-maskable-192.png', _tile(192, 0.52, emblem: emblem));
  _write('web/icons/Icon-maskable-512.png', _tile(512, 0.52, emblem: emblem));
}

/// The logo without its transparent margin, so the margins here are the ones
/// chosen above and not whatever the source file happens to have.
img.Image _cropToContent(img.Image image) {
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  for (final pixel in image) {
    if (pixel.a > 8) {
      minX = math.min(minX, pixel.x);
      minY = math.min(minY, pixel.y);
      maxX = math.max(maxX, pixel.x);
      maxY = math.max(maxY, pixel.y);
    }
  }
  if (maxX < 0) throw StateError('The logo is completely transparent.');
  return img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// A [size] square: the dark colour with the logo centred on it.
///
/// With a [corner] (a fraction of the size) the tile's corners are rounded and
/// transparent; without one it is square and opaque, as an app icon should be.
img.Image _tile(int size, double fill, {required img.Image emblem, double corner = 0}) {
  // Drawn at four times the size and shrunk, so the edges are smooth.
  const supersample = 4;
  final big = size * supersample;

  final canvas = img.Image(width: big, height: big, numChannels: 4);
  if (corner > 0) {
    img.fillRect(
      canvas,
      x1: 0,
      y1: 0,
      x2: big - 1,
      y2: big - 1,
      color: _background,
      radius: big * corner,
    );
  } else {
    img.fill(canvas, color: _background);
  }

  final longSide = math.max(emblem.width, emblem.height);
  final scale = big * fill / longSide;
  final logo = img.copyResize(
    emblem,
    width: (emblem.width * scale).round(),
    height: (emblem.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    logo,
    dstX: (big - logo.width) ~/ 2,
    dstY: (big - logo.height) ~/ 2,
  );

  return img.copyResize(canvas,
      width: size, height: size, interpolation: img.Interpolation.average);
}

void _write(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln('$path  ${image.width}x${image.height}  ${File(path).lengthSync()} bytes');
}
