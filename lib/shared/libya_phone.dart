class LibyaPhone {
  const LibyaPhone._();

  static String normalize(String value) {
    var text = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    text = text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    if (text.startsWith('00218')) text = '+218${text.substring(5)}';
    if (text.startsWith('+218')) text = '0${text.substring(4)}';
    if (text.startsWith('218') && text.length == 12)
      text = '0${text.substring(3)}';
    return text;
  }

  static String? validate(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty)
      return required ? 'رقم الهاتف مطلوب' : null;
    return isValid(value)
        ? null
        : 'أدخل رقمًا ليبيًا مثل 0912345678 أو +218912345678';
  }

  static bool isValid(String value) {
    final text = normalize(value);
    return RegExp(r'^09[1-5][0-9]{7}$').hasMatch(text);
  }
}
