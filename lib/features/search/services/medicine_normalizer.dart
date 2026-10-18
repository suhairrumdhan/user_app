class MedicineNormalizer {
  const MedicineNormalizer._();

  static const Map<String, List<String>> dosageForms = {
    'TABLET': ['TABLET', 'TABLETS', 'TAB', 'TABS'],
    'CAPSULE': ['CAPSULE', 'CAPSULES', 'CAP', 'CAPS'],
    'SYRUP': ['SYRUP', 'SYP'],
    'SUSPENSION': ['SUSPENSION', 'SUSP'],
    'DROPS': ['DROPS', 'DROP'],
    'SPRAY': ['SPRAY'],
    'CREAM': ['CREAM'],
    'OINTMENT': ['OINTMENT', 'OINT'],
    'GEL': ['GEL'],
    'SOLUTION': ['SOLUTION', 'SOLN'],
    'AMPOULE': ['AMPOULE', 'AMP', 'AMPOULES'],
    'VIAL': ['VIAL', 'VIALS'],
    'INHALER': ['INHALER'],
    'SUPPOSITORY': ['SUPPOSITORY', 'SUPPOSITORIES'],
    'SACHET': ['SACHET', 'SACHETS'],
    'INJECTION': ['INJECTION', 'INJECTABLE', 'INJ'],
    'POWDER': ['POWDER'],
    'LOTION': ['LOTION'],
    'PATCH': ['PATCH'],
  };

  static const List<String> _genericNoiseWords = [
    'MG',
    'MCG',
    'G',
    'ML',
    'IU',
    '%',
    'TABLET',
    'TABLETS',
    'TAB',
    'TABS',
    'CAPSULE',
    'CAPSULES',
    'CAP',
    'CAPS',
    'SYRUP',
    'SYP',
    'SUSPENSION',
    'SUSP',
    'DROPS',
    'DROP',
    'SPRAY',
    'CREAM',
    'OINTMENT',
    'OINT',
    'GEL',
    'AMP',
    'AMPOULE',
    'AMPOULES',
    'VIAL',
    'VIALS',
    'INHALER',
    'SUPPOSITORY',
    'SUPPOSITORIES',
    'SACHET',
    'SACHETS',
    'INJECTION',
    'INJECTABLE',
    'INJ',
    'POWDER',
    'LOTION',
    'PATCH',
    'PLUS',
    'AND',
    'OR',
    'WITH',
    'FOR',
  ];

  static final Map<String, String> _formAliases = {
    for (final entry in dosageForms.entries)
      for (final alias in entry.value) alias: entry.key,
  };
  static final RegExp _formPattern = RegExp(
    r'\b(?:' + _formAliases.keys.map(RegExp.escape).join('|') + r')\b',
  );

  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    String text = input.trim().toUpperCase();

    text = _normalizeEnglish(text);
    text = _normalizeUnits(text);
    text = _normalizeDosageAliases(text);
    text = _removeNoise(text);
    text = _collapseSpaces(text);

    return text.trim();
  }

  static List<String> buildSearchTokens(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return [];

    final baseName = extractBaseName(normalized);
    final strength = extractStrength(normalized);
    final dosageForm = extractDosageForm(normalized);

    final parts = normalized
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final baseParts = baseName
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final unique = <String>{};

    unique.add(normalized);

    if (baseName.isNotEmpty) {
      unique.add(baseName);
    }

    if (strength != null && strength.isNotEmpty) {
      unique.add(strength);
    }

    if (dosageForm != null && dosageForm.isNotEmpty) {
      unique.add(dosageForm);
    }

    unique.addAll(parts);
    unique.addAll(baseParts);

    // add useful prefixes like first word / first two words
    if (baseParts.isNotEmpty) {
      unique.add(baseParts.first);
    }
    if (baseParts.length >= 2) {
      unique.add('${baseParts[0]} ${baseParts[1]}');
    }

    return unique.where((e) => e.trim().isNotEmpty).toList();
  }

  static String? extractStrength(String input) {
    final normalized = normalize(input);

    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(MG|MCG|G|IU)\s*/\s*(\d+(?:\.\d+)?)\s*(ML)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(MG|MCG|G|ML|IU|%)'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(normalized);
      if (match == null) continue;

      if (match.groupCount >= 4 &&
          match.group(1) != null &&
          match.group(2) != null &&
          match.group(3) != null &&
          match.group(4) != null) {
        final leftValue = match.group(1)!.replaceAll(' ', '');
        final leftUnit = match.group(2)!.toUpperCase();
        final rightValue = match.group(3)!.replaceAll(' ', '');
        final rightUnit = match.group(4)!.toUpperCase();
        return '$leftValue$leftUnit/$rightValue$rightUnit';
      }

      final value = match.group(1)?.replaceAll(' ', '');
      final unit = match.group(2)?.toUpperCase();

      if (value != null && unit != null) {
        return '$value$unit';
      }
    }

    return null;
  }

  static String? extractDosageForm(String input) {
    final normalized = normalize(input);

    for (final canonical in dosageForms.keys) {
      if (normalized.contains(canonical)) return canonical;
    }

    return null;
  }

  static String extractBaseName(String input) {
    String text = normalize(input);

    final strength = extractStrength(text);
    final dosageForm = extractDosageForm(text);

    if (strength != null && strength.isNotEmpty) {
      text = text.replaceAll(strength, ' ');
    }

    if (dosageForm != null && dosageForm.isNotEmpty) {
      text = text.replaceAll(
        RegExp(r'\b' + RegExp.escape(dosageForm) + r'\b'),
        ' ',
      );
    }

    for (final word in _genericNoiseWords) {
      text = text.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b'), ' ');
    }

    // remove standalone numbers
    text = text.replaceAll(RegExp(r'\b\d+\b'), ' ');

    text = _collapseSpaces(text);
    return text.trim();
  }

  static bool areEquivalent(String a, String b) {
    final aNorm = normalize(a);
    final bNorm = normalize(b);

    if (aNorm == bNorm) return true;

    final aBase = extractBaseName(aNorm);
    final bBase = extractBaseName(bNorm);

    return aBase.isNotEmpty && aBase == bBase;
  }

  static bool containsNormalized(String text, String query) {
    final aNorm = normalize(text);
    final bNorm = normalize(query);

    if (aNorm.isEmpty || bNorm.isEmpty) return false;

    if (aNorm.contains(bNorm) || bNorm.contains(aNorm)) {
      return true;
    }

    final aBase = extractBaseName(aNorm);
    final bBase = extractBaseName(bNorm);

    if (aBase.isEmpty || bBase.isEmpty) return false;

    if (aBase.contains(bBase) || bBase.contains(aBase)) {
      return true;
    }

    // important for PANADOL -> PANADOL EXTRA / PANADOL 500 MG
    final aParts = aBase.split(' ').where((e) => e.isNotEmpty).toList();
    final bParts = bBase.split(' ').where((e) => e.isNotEmpty).toList();

    if (aParts.isNotEmpty && bParts.isNotEmpty) {
      if (aParts.first == bParts.first) return true;
    }

    return false;
  }

  static List<String> generateNGrams(String input, {int n = 3}) {
    final text = normalize(input).replaceAll(' ', '');
    if (text.length < n) return text.isEmpty ? [] : [text];

    final grams = <String>[];
    for (int i = 0; i <= text.length - n; i++) {
      grams.add(text.substring(i, i + n));
    }
    return grams;
  }

  static double trigramSimilarity(String a, String b) {
    final aGrams = generateNGrams(a).toSet();
    final bGrams = generateNGrams(b).toSet();

    if (aGrams.isEmpty || bGrams.isEmpty) return 0;

    final intersection = aGrams.intersection(bGrams).length;
    final union = aGrams.union(bGrams).length;

    if (union == 0) return 0;
    return intersection / union;
  }

  static int levenshteinDistance(String s1, String s2) {
    final a = normalize(s1);
    final b = normalize(s2);

    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        matrix[i][j] = _min3(
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[a.length][b.length];
  }

  static double similarityScore(String a, String b) {
    final x = normalize(a);
    final y = normalize(b);

    if (x.isEmpty || y.isEmpty) return 0;
    if (x == y) return 1;

    final baseX = extractBaseName(x);
    final baseY = extractBaseName(y);

    if (baseX.isNotEmpty && baseY.isNotEmpty && baseX == baseY) {
      return 0.98;
    }

    final xParts = baseX.split(' ').where((e) => e.isNotEmpty).toList();
    final yParts = baseY.split(' ').where((e) => e.isNotEmpty).toList();

    if (xParts.isNotEmpty &&
        yParts.isNotEmpty &&
        xParts.first == yParts.first) {
      // PANADOL vs PANADOL EXTRA
      return 0.92;
    }

    final distance = levenshteinDistance(x, y);
    final maxLen = x.length > y.length ? x.length : y.length;
    final levenshteinScore = maxLen == 0 ? 1 : 1 - (distance / maxLen);
    final trigramScore = trigramSimilarity(x, y);

    double finalScore = (levenshteinScore * 0.45) + (trigramScore * 0.55);

    if (baseX.isNotEmpty && baseY.isNotEmpty) {
      final baseDistance = levenshteinDistance(baseX, baseY);
      final baseMaxLen = baseX.length > baseY.length
          ? baseX.length
          : baseY.length;
      final baseLevenshtein = baseMaxLen == 0
          ? 1
          : 1 - (baseDistance / baseMaxLen);
      final baseTrigram = trigramSimilarity(baseX, baseY);
      final baseScore = (baseLevenshtein * 0.45) + (baseTrigram * 0.55);

      finalScore = (finalScore * 0.55) + (baseScore * 0.45);
    }

    return finalScore.clamp(0, 1).toDouble();
  }

  static String _normalizeEnglish(String text) {
    return text
        .replaceAll('&', ' AND ')
        .replaceAll('+', ' PLUS ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s*/\s*'), '/')
        .replaceAllMapped(
          RegExp(r'([A-Z])(\d)'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        );
  }

  static String _normalizeUnits(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*MG\b'),
          (m) => '${m.group(1)}MG',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*MCG\b'),
          (m) => '${m.group(1)}MCG',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*G\b'),
          (m) => '${m.group(1)}G',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*ML\b'),
          (m) => '${m.group(1)}ML',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*IU\b'),
          (m) => '${m.group(1)}IU',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*%\b'),
          (m) => '${m.group(1)}%',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*(MG|MCG|G|ML|IU)\b'),
          (m) => '${m.group(1)} ${m.group(2)}',
        );
  }

  static String _normalizeDosageAliases(String text) {
    return text.replaceAllMapped(
      _formPattern,
      (match) => _formAliases[match.group(0)!]!,
    );
  }

  static String _removeNoise(String text) {
    return text.replaceAll(RegExp(r'[^A-Z0-9\s/%]'), ' ');
  }

  static String _collapseSpaces(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= a && b <= c) return b;
    return c;
  }
}
