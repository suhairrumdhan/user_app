import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/medicine_suggestion.dart';
import 'medicine_normalizer.dart';

class MedicineSuggestionService {
  final FirebaseFirestore _firestore;

  MedicineSuggestionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<MedicineSuggestion>> fetchSuggestions(
    String input, {
    int limit = 8,
  }) async {
    final query = MedicineNormalizer.normalize(input).replaceAll(' ', '');
    if (query.length < 2) return const [];

    final snapshot = await _firestore
        .collection('medicine_search_index')
        .where('suggestionPrefixes', arrayContains: query)
        .limit(40)
        .get();

    final unique = <String, MedicineSuggestion>{};
    for (final document in snapshot.docs) {
      final data = document.data();

      final name = (data['medicineName'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final normalizedName = MedicineNormalizer.normalize(name);
      unique.putIfAbsent(
        normalizedName,
        () => MedicineSuggestion(
          medicineName: name,
          scientificName: (data['scientificName'] ?? '').toString().trim(),
        ),
      );
    }

    final suggestions = unique.values.toList()
      ..sort((a, b) {
        final aName = MedicineNormalizer.normalize(
          a.medicineName,
        ).replaceAll(' ', '');
        final bName = MedicineNormalizer.normalize(
          b.medicineName,
        ).replaceAll(' ', '');
        final aStarts = aName.startsWith(query);
        final bStarts = bName.startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return a.medicineName.compareTo(b.medicineName);
      });

    return suggestions.take(limit).toList();
  }
}
