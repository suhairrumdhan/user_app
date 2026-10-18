import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PendingOrderConflict implements Exception {
  const PendingOrderConflict(this.request);
  final Map<String, dynamic> request;
  @override
  String toString() => 'توجد محاولة إرسال سابقة تحتاج تأكيد نتيجتها.';
}

/// A lost reply must not turn the next tap (or app restart) into a new order.
class PendingOrderCommands {
  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};
  static final Map<String, String> _bodies = {};

  static Future<Map<String, dynamic>> execute({
    required String key,
    required Map<String, dynamic> request,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
    required bool Function(Object) isDefinitiveFailure,
  }) async {
    final body = jsonEncode(
      Map<String, dynamic>.from(request)..remove('operationId'),
    );
    final previous = _inFlight[key];
    if (previous != null) {
      if (_bodies[key] != body) {
        throw StateError('انتظر انتهاء العملية الحالية قبل تغيير البيانات.');
      }
      return previous;
    }
    final completion = _executeAfter(key, request, send, isDefinitiveFailure);
    _inFlight[key] = completion;
    _bodies[key] = body;
    try {
      return await completion;
    } finally {
      _inFlight.remove(key);
      _bodies.remove(key);
    }
  }

  static Future<Map<String, dynamic>> _executeAfter(
    String key,
    Map<String, dynamic> request,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
    bool Function(Object) isDefinitiveFailure,
  ) async {
    final root = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${root.path}/pending-order-commands',
    ).create(recursive: true);
    final name = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    final file = File('${directory.path}/$name.json');
    var actual = request;
    if (await file.exists()) {
      actual = Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
      final oldBody = Map<String, dynamic>.from(actual)..remove('operationId');
      final newBody = Map<String, dynamic>.from(request)..remove('operationId');
      if (jsonEncode(oldBody) != jsonEncode(newBody)) {
        throw PendingOrderConflict(actual);
      }
    } else {
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(request), flush: true);
      await temporary.rename(file.path);
    }
    Future<void> clear() async {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Keeping the original operation is safe: its next replay is idempotent.
      }
    }

    try {
      final result = await send(actual);
      await clear();
      return result;
    } catch (error) {
      if (isDefinitiveFailure(error)) await clear();
      rethrow;
    }
  }
}
