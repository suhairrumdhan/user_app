/// Lexical identity only: no fuzzy brand families or therapeutic substitutions.
class MedicineIdentity {
  const MedicineIdentity._();
  static const forms = {
    'TAB': 'tab',
    'TABS': 'tab',
    'TABLET': 'tab',
    'TABLETS': 'tab',
    'CAP': 'cap',
    'CAPS': 'cap',
    'CAPSULE': 'cap',
    'CAPSULES': 'cap',
    'SYRUP': 'syrup',
    'SYP': 'syrup',
    'SUSP': 'susp',
    'SUSPENSION': 'susp',
    'DROP': 'drop',
    'DROPS': 'drop',
    'CREAM': 'cream',
    'OINT': 'ointment',
    'OINTMENT': 'ointment',
    'GEL': 'gel',
    'SPRAY': 'spray',
    'VIAL': 'vial',
    'VIALS': 'vial',
    'AMP': 'amp',
    'AMPOULE': 'amp',
    'AMPOULES': 'amp',
    'INJ': 'inj',
    'INJECTION': 'inj',
    'INJECTABLE': 'inj',
    'SACH': 'sach',
    'SACHET': 'sach',
    'SACHETS': 'sach',
    'SUPP': 'supp',
    'SUPPOSITORY': 'supp',
    'SUPPOSITORIES': 'supp',
    'SOL': 'sol',
    'SOLN': 'sol',
    'SOLUTION': 'sol',
    'INHALER': 'inhaler',
    'PATCH': 'patch',
    'PATCHES': 'patch',
    'LOTION': 'lotion',
    'POWDER': 'powder',
  };
  static const _number = r'(?:\d+(?:\.\d+)?|\.\d+)';
  static final _dose = RegExp(
    '(?<![\\w.,])($_number(?:/$_number)*)\\s*(MCG|MG|G|IU|%)'
    '(?:/(?:($_number)\\s*)?(ML|MG|G))?(?!\\w)',
  );

  static String normalize(String input) {
    var text = input
        .trim()
        .toUpperCase()
        .replaceAll('µ', 'U')
        .replaceAll('Μ', 'U');
    text = text.replaceAllMapped(
      RegExp(r'(\d+),(\d+)'),
      (m) => m[2]!.length == 3 && m[1] != '0' ? m[0]! : '${m[1]}.${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    text = text.replaceAll(RegExp(r'\bGM\b'), 'G');
    text = text.replaceAll(RegExp(r'\b(?:UG|MICROGRAMS?)\b'), 'MCG');
    text = text.replaceAll(RegExp(r'\bMILLIGRAMS?\b'), 'MG');
    text = text.replaceAll(RegExp(r'\bMILLILIT(?:ER|RE)S?\b'), 'ML');
    text = text.replaceAll(RegExp(r'\s*/\s*'), '/');
    return text
        .replaceAll(RegExp(r'[-_*():]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? strength(String text) {
    final components = <String>[];
    for (final m in _dose.allMatches(normalize(text))) {
      var unit = m[2]!;
      final factor = unit == 'G' ? 1000.0 : 1.0;
      if (unit == 'G') unit = 'MG';
      var divisor = double.tryParse(m[3] ?? '') ?? 1;
      var denominator = m[4];
      if (denominator == 'G') {
        divisor *= 1000;
        denominator = 'MG';
      }
      if (divisor <= 0) return null;
      for (final amount in m[1]!.split('/')) {
        final value = double.parse(amount) * factor / divisor;
        final stable = double.parse(value.toStringAsPrecision(12));
        final number = stable == stable.roundToDouble()
            ? stable.toInt().toString()
            : stable.toString();
        final suffix = denominator == null ? '' : '/$denominator';
        components.add('$number $unit$suffix');
      }
    }
    return components.isEmpty ? null : components.join(' + ');
  }

  static String? form(String text) {
    for (final token in normalize(text).split(' ')) {
      if (forms.containsKey(token)) return forms[token];
    }
    return null;
  }

  static String name(String text) {
    var value = normalize(text).replaceAll(_dose, ' ');
    value = value.replaceAll(RegExp(r'/\s*(?=\d+\s*(?:TAB|CAP)\b)'), ' ');
    value = value.replaceAll(RegExp(_number + r'\s*ML\b'), ' ');
    final formPattern = forms.keys.join('|');
    // Only strip explicit pack counts adjacent to a form, not arbitrary brand numbers.
    if (strength(text) != null) {
      value = value.replaceAllMapped(
        RegExp(r'\b\d+\s+(' + formPattern + r')\b'),
        (m) => m[1]!,
      );
      value = value.replaceAllMapped(
        RegExp(r'\b(' + formPattern + r')\s+\d+(?:\s+\d+)*(?![\w.])'),
        (m) => m[1]!,
      );
    }
    return value
        .split(RegExp(r'\s+'))
        .where(
          (t) => t.isNotEmpty && !forms.containsKey(t) && t != '/' && t != '-',
        )
        .join(' ')
        .trim();
  }

  static bool matches({
    required String requestedName,
    required String availableName,
    String? requestedStrength,
    String? availableStrength,
    String? requestedForm,
    String? availableForm,
  }) {
    final a = name(requestedName);
    final b = name(availableName);
    if (a.isEmpty || a != b) return false;
    final neededStrength =
        strength(requestedName) ?? strength(requestedStrength ?? '');
    final stockStrength =
        strength(availableName) ?? strength(availableStrength ?? '');
    final fieldStrength = strength(availableStrength ?? '');
    if (fieldStrength != null && stockStrength != fieldStrength) return false;
    if (neededStrength != null && neededStrength != stockStrength) return false;
    final neededForm = form(requestedName) ?? form(requestedForm ?? '');
    final stockForm = form(availableName) ?? form(availableForm ?? '');
    final fieldForm = form(availableForm ?? '');
    if (fieldForm != null && stockForm != fieldForm) return false;
    return neededForm == null || neededForm == stockForm;
  }
}
