import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<File> preparePrescriptionImage(File file, int turns) async {
  final path = await compute(_prepareImage, <Object>[file.path, turns % 4]);
  return File(path);
}

String _prepareImage(List<Object> input) {
  final file = File(input[0] as String);
  final turns = input[1] as int;
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) throw const FormatException('تعذر فتح الصورة');
  final upright = img.bakeOrientation(decoded);
  final rotated = turns == 0
      ? upright
      : img.copyRotate(upright, angle: turns * 90);
  if (rotated.width > rotated.height) {
    throw const FormatException('دوّر الصورة لتكون عمودية.');
  }
  // Preserve the original and give OCR exactly the approved orientation.
  final output = File(
    '${file.parent.path}/prescription_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  output.writeAsBytesSync(img.encodePng(rotated));
  return output.path;
}
