import 'dart:typed_data';
import 'dart:ui' as ui;

/// Renders a solid-color square and encodes it as real PNG bytes at
/// [size]x[size] — `profile_setup_screen.dart`'s `_decodeDimensions` runs
/// the picked bytes through `ui.instantiateImageCodec`, a real image
/// decoder, so a widget test needs genuinely decodable image data (not
/// arbitrary bytes) to exercise the 400x400 minimum-resolution check in
/// either direction.
Future<Uint8List> fakeImageBytes(int size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFAA8866),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
