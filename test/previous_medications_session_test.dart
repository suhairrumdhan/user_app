import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/previous_medications/controllers/previous_medications_controller.dart';
import 'package:user_application/features/previous_medications/models/previous_medication_model.dart';
import 'package:user_application/features/previous_medications/services/previous_medications_service.dart';

class RecordsService implements PreviousMedicationsService {
  final feeds = <String, StreamController<List<PreviousMedicationModel>>>{};
  final refresh = Completer<List<PreviousMedicationModel>>();
  @override
  Stream<List<PreviousMedicationModel>> watchAll({
    String? userId,
    String? beneficiaryId,
    String? status,
  }) => feeds.putIfAbsent(userId!, () => StreamController.broadcast()).stream;
  @override
  Future<List<PreviousMedicationModel>> getAll({
    String? userId,
    String? beneficiaryId,
    String? status,
  }) => refresh.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PreviousMedicationModel record(String uid) => PreviousMedicationModel(
  id: uid,
  userId: uid,
  ownerBeneficiaryId: uid,
  ownerName: uid,
  ownerType: 'self',
  ownerRelation: 'self',
  medicineName: 'Panadol',
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'switching accounts clears records and filters and ignores an old refresh',
    () async {
      final sessions = StreamController<String?>();
      final service = RecordsService();
      String? uid = 'first';
      final controller = PreviousMedicationsController(
        service: service,
        sessions: sessions.stream,
        currentUserId: () => uid,
      );
      controller.onInit();
      sessions.add(uid);
      await flush();
      service.feeds[uid]!.add([record(uid)]);
      await flush();
      expect(controller.allRecords.single.userId, 'first');
      controller.selectedBeneficiaryId.value = 'old-family';
      controller.selectedRecordId.value = 'first';
      controller.selectedFilter.value = PreviousMedicationsFilter.archived;
      final pending = controller.refreshRecords();
      uid = 'second';
      sessions.add(uid);
      await flush();
      expect(controller.allRecords, isEmpty);
      expect(controller.selectedBeneficiaryId.value, isNull);
      expect(controller.selectedRecordId.value, isNull);
      expect(controller.selectedFilter.value, PreviousMedicationsFilter.all);
      service.feeds[uid]!.add([record(uid)]);
      await flush();
      service.refresh.complete([record('first')]);
      await pending;
      expect(controller.allRecords.single.userId, 'second');
      uid = null;
      sessions.add(uid);
      await flush();
      expect(controller.allRecords, isEmpty);
      controller.onClose();
      await sessions.close();
      for (final feed in service.feeds.values) {
        await feed.close();
      }
    },
  );
}
