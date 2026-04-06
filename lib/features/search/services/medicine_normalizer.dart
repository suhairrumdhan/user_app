class MedicineNormalizer {
  const MedicineNormalizer._();

  static const Map<String, List<String>> dosageForms = {
    'tablet': ['tablet', 'tablets', 'tab', 'tabs', 'قرص', 'اقراص', 'حبوب'],
    'capsule': ['capsule', 'capsules', 'cap', 'caps', 'كبسولة', 'كبسولات'],
    'syrup': ['syrup', 'شراب'],
    'suspension': ['suspension', 'معلق'],
    'drops': ['drops', 'drop', 'قطرة', 'قطرات'],
    'spray': ['spray', 'بخاخ'],
    'cream': ['cream', 'كريم'],
    'ointment': ['ointment', 'مرهم'],
    'gel': ['gel', 'جل'],
    'solution': ['solution', 'محلول'],
    'ampoule': ['ampoule', 'amp', 'ampoules', 'امبول', 'أمبول'],
    'vial': ['vial', 'vials', 'فيال'],
    'inhaler': ['inhaler', 'بخاخة'],
    'suppository': ['suppository', 'suppositories', 'لبوس'],
    'sachet': ['sachet', 'sachets', 'كيس', 'اكياس'],
    'injection': ['injection', 'injectable', 'حقن', 'حقنة'],
    'powder': ['powder', 'بودرة'],
    'lotion': ['lotion', 'لوشن'],
    'patch': ['patch', 'لاصقة'],
  };

  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    String text = input.trim().toLowerCase();

    text = _normalizeArabic(text);
    text = _normalizeEnglish(text);
    text = _normalizeUnits(text);
    text = _removeNoise(text);
    text = _collapseSpaces(text);

    return text.trim();
  }

  static List<String> buildSearchTokens(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return [];

    final baseName = extractBaseName(normalized);

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

    unique.addAll(parts);
    unique.addAll(baseParts);

    return unique.toList();
  }

  static String? extractStrength(String input) {
    final normalized = normalize(input);

    final patterns = [
      RegExp(
        r'(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)\s*(mg|mcg|g|ml|iu|%)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(mg|mcg|g|iu)\s*/\s*(\d+(?:\.\d+)?)\s*(ml)',
        caseSensitive: false,
      ),
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
        final leftUnit = match.group(2)!.toLowerCase();
        final rightValue = match.group(3)!.replaceAll(' ', '');
        final rightUnit = match.group(4)!.toLowerCase();
        return '$leftValue$leftUnit/$rightValue$rightUnit';
      }

      final value = match.group(1)?.replaceAll(' ', '');
      final unit = match.group(2)?.toLowerCase();

      if (value != null && unit != null) {
        return '$value$unit';
      }
    }

    return null;
  }

  static String? extractDosageForm(String input) {
    final normalized = normalize(input);

    for (final entry in dosageForms.entries) {
      for (final alias in entry.value) {
        final normalizedAlias = normalize(alias);
        if (normalized.contains(normalizedAlias)) {
          return entry.key;
        }
      }
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
      for (final alias in dosageForms[dosageForm] ?? const <String>[]) {
        text = text.replaceAll(normalize(alias), ' ');
      }
    }

    const genericNoiseWords = <String>[
      'mg',
      'mcg',
      'g',
      'ml',
      'iu',
      '%',
      'tab',
      'tabs',
      'tablet',
      'tablets',
      'cap',
      'caps',
      'capsule',
      'capsules',
      'syrup',
      'solution',
      'suspension',
      'drops',
      'drop',
      'spray',
      'cream',
      'ointment',
      'gel',
      'amp',
      'ampoule',
      'ampoules',
      'vial',
      'inhaler',
      'suppository',
      'suppositories',
      'sachet',
      'sachets',
      'injection',
      'injectable',
      'powder',
      'lotion',
      'patch',
      'plus',
      'and',
    ];

    for (final word in genericNoiseWords) {
      text = text.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b'),
        ' ',
      );
    }

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
    if (aNorm.contains(bNorm) || bNorm.contains(aNorm)) return true;

    final aBase = extractBaseName(aNorm);
    final bBase = extractBaseName(bNorm);

    if (aBase.isEmpty || bBase.isEmpty) return false;
    return aBase.contains(bBase) || bBase.contains(aBase);
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
      return 0.97;
    }

    final distance = levenshteinDistance(x, y);
    final maxLen = x.length > y.length ? x.length : y.length;
    final levenshteinScore = maxLen == 0 ? 1 : 1 - (distance / maxLen);
    final trigramScore = trigramSimilarity(x, y);

    double finalScore = (levenshteinScore * 0.5) + (trigramScore * 0.5);

    if (baseX.isNotEmpty && baseY.isNotEmpty) {
      final baseDistance = levenshteinDistance(baseX, baseY);
      final baseMaxLen = baseX.length > baseY.length ? baseX.length : baseY.length;
      final baseLevenshtein =
      baseMaxLen == 0 ? 1 : 1 - (baseDistance / baseMaxLen);
      final baseTrigram = trigramSimilarity(baseX, baseY);
      final baseScore = (baseLevenshtein * 0.5) + (baseTrigram * 0.5);

      finalScore = (finalScore * 0.6) + (baseScore * 0.4);
    }

    return finalScore.clamp(0, 1).toDouble();
  }

  static String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '');
  }

  static String _normalizeEnglish(String text) {
    return text
        .replaceAll('&', ' and ')
        .replaceAll('+', ' plus ')
        .replaceAll('/', '/')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
  }

  static String _normalizeUnits(String text) {
    return text
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*ملغ'),
          (m) => '${m.group(1)}mg',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*مجم'),
          (m) => '${m.group(1)}mg',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*جم'),
          (m) => '${m.group(1)}g',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*مل'),
          (m) => '${m.group(1)}ml',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*ميكروجرام'),
          (m) => '${m.group(1)}mcg',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*وحده'),
          (m) => '${m.group(1)}iu',
    )
        .replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*%'),
          (m) => '${m.group(1)}%',
    );
  }

  static String _removeNoise(String text) {
    return text.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s/%]', unicode: true),
      ' ',
    );
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