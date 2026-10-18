import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/shared/libya_phone.dart';

void main() {
  test('Libyan local and international formats normalize consistently', () {
    for (final phone in [
      '0912345678',
      '+218912345678',
      '00218912345678',
      '218912345678',
      '٠٩١٢٣٤٥٦٧٨',
      '+218 91 234-5678',
    ]) {
      expect(LibyaPhone.validate(phone), isNull);
      expect(LibyaPhone.normalize(phone), '0912345678');
    }
    for (final phone in [
      '',
      '091234567',
      '09123456789',
      '+201234567890',
      'abc0912345678',
      '+2180912345678',
    ]) {
      expect(LibyaPhone.validate(phone), isNotNull);
    }
    expect(LibyaPhone.validate('', required: false), isNull);
  });
}
