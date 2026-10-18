import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/shared/user_facing_error.dart';

void main() {
  test('technical errors become useful short messages', () {
    expect(userFacingError(Exception('الصنف غير موجود في المخزون: panadol')), 'الصنف غير متوفر في المخزون. حدّث الأصناف وحاول مرة أخرى.');
    expect(userFacingError(Exception('ClientException with SocketException: Failed host lookup')), 'تعذر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.');
    expect(userFacingError(Exception('يرجى إدخال رقم الهاتف')), 'يرجى إدخال رقم الهاتف');
    expect(userFacingError(Exception('Unhandled internal error at https://example.test')), 'تعذر إتمام العملية. حاول مرة أخرى.');
  });
}
