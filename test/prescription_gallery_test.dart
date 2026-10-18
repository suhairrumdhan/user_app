import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:user_application/features/prescription/services/prescription_image_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user_application/features/prescription/services/file_utils.dart';

class _Picker extends FilePicker {
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Picker picker;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prescription-gallery-');
    picker = _Picker();
    FilePicker.platform = picker;
  });
  tearDown(() => directory.delete(recursive: true));
  test('canceling gallery selection returns no prescription', () async {
    expect(await FileUtils.pickImage(ImageSource.gallery), isNull);
  });
  test('selected image remains intact for OCR', () async {
    final file = File('${directory.path}/prescription.png');
    await file.writeAsBytes([137, 80, 78, 71, 1, 2, 3]);
    picker.result = FilePickerResult([
      PlatformFile(name: 'prescription.png', size: 7, path: file.path),
    ]);
    final selected = await FileUtils.pickImage(ImageSource.gallery);
    expect(await selected!.readAsBytes(), await file.readAsBytes());
  });
  test('empty selection file yields a human readable error', () async {
    final file = File('${directory.path}/empty.jpg');
    await file.create();
    picker.result = FilePickerResult([
      PlatformFile(name: 'empty.jpg', size: 0, path: file.path),
    ]);
    await expectLater(
      FileUtils.pickImage(ImageSource.gallery),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'تعذر فتح الصورة. حاول اختيارها مرة أخرى.',
        ),
      ),
    );
  });
  test(
    'landscape is rejected until rotated; OCR gets the approved image',
    () async {
      final original = File('${directory.path}/landscape.png');
      await original.writeAsBytes(
        img.encodePng(img.Image(width: 8, height: 4)),
      );
      await expectLater(
        preparePrescriptionImage(original, 0),
        throwsFormatException,
      );
      final rotated = await preparePrescriptionImage(original, 1);
      final decoded = img.decodeImage(await rotated.readAsBytes())!;
      expect(decoded.width, 4);
      expect(decoded.height, 8);
      expect(img.decodeImage(await original.readAsBytes())!.width, 8);
    },
  );
}
