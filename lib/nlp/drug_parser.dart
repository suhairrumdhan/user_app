class DrugInfo {
  final String name;
  final String dosage;
  final String? route;
  final String? frequency;
  final String? duration;

  DrugInfo({
    required this.name,
    required this.dosage,
    this.route,
    this.frequency,
    this.duration,
  });
}

class DrugParser {
  static List<DrugInfo> parse(String text) {
    final List<DrugInfo> drugs = [];

    // تقسيم النص لأسطرغ
    final lines = text.split('\n');

    // Regex شامل: اسم دواء + جرعة + وحدة + route + frequency + duration
    final regex = RegExp(
      r'(?<name>[A-Za-z][A-Za-z0-9\s\-]+)\s+(?<dose>\d+\s?(mg|ml|g|tab|cap|drop|cream))'
      r'(?:.*?\b(?<route>oral|local|iv|im)\b)?'
      r'(?:.*?\b(?<freq>\d+\s?(daily|times|x\/day))\b)?'
      r'(?:.*?\b(?<dur>\d+\s?day\(s\)?)\b)?',
      caseSensitive: false,
    );

    for (var line in lines) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final name = (match.namedGroup('name') ?? '').trim();
        final dose = (match.namedGroup('dose') ?? '').trim();
        final route = match.namedGroup('route')?.trim();
        final freq = match.namedGroup('freq')?.trim();
        final dur = match.namedGroup('dur')?.trim();

        drugs.add(
          DrugInfo(
            name: name,
            dosage: dose,
            route: route,
            frequency: freq,
            duration: dur,
          ),
        );
      }
    }

    return drugs;
  }
}
