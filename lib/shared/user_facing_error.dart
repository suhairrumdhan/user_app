String userFacingError(Object? error, {String fallback = 'تعذر إتمام العملية. حاول مرة أخرى.'}) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('socket') || lower.contains('network') || lower.contains('host lookup') || lower.contains('unavailable')) {
    return 'تعذر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
  }
  if (lower.contains('timeout') || lower.contains('deadline-exceeded')) {
    return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
  }
  if (lower.contains('permission-denied') || lower.contains('unauthorized')) {
    return 'لا توجد صلاحية لتنفيذ هذه العملية.';
  }
  if (raw.contains('الصنف غير موجود في المخزون') || lower.contains('insufficient stock')) {
    return 'الصنف غير متوفر في المخزون. حدّث الأصناف وحاول مرة أخرى.';
  }
  var message = raw.replaceFirst(RegExp(r'^(Exception|StateError|Bad state|FormatException):\s*'), '').trim();
  if (!RegExp(r'[\u0600-\u06ff]').hasMatch(message) ||
      RegExp(r'(Exception|Error:|https?://|firebase|firestore|stack|\[[a-z]+/)', caseSensitive: false).hasMatch(message)) {
    return fallback;
  }
  message = message.replaceAll(RegExp(r'\b[A-Za-z0-9_-]{20,}\b'), '').trim();
  return message.isEmpty ? fallback : message;
}
