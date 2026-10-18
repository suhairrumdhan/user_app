import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/saved_prescriptions/services/saved_prescription_service.dart';
import 'package:user_application/features/saved_prescriptions/models/saved_prescription_model.dart';
import 'package:user_application/features/prescription/models/beneficiary_model.dart';
import 'package:user_application/features/prescription/models/medicine_model.dart';
import 'helpers/memory_firestore.dart';

const beneficiary = BeneficiaryModel(
  id: 'user',
  name: 'User',
  type: 'self',
  relation: 'self',
);
const medicines = [MedicineModel(name: 'Panadol 500mg')];
SavedPrescriptionModel archived(String id, Map<String, dynamic> data) =>
    SavedPrescriptionModel(
      id: id,
      userId: 'user',
      uniqueKey: id,
      searchHistory: [],
      beneficiaryId: 'user',
      beneficiaryName: 'User',
      beneficiaryType: 'self',
      beneficiaryRelation: 'self',
      source: 'prescription',
      medicines: [],
      medicineCount: 1,
      hasOriginalFile: true,
      title: 'Prescription',
      storagePath: data['storagePath'] as String?,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late MemoryFirestore db;
  late SavedPrescriptionService service;
  late Map<String, String> files;
  late bool failFinalize;
  late bool failDelete;
  late int uploads;
  late int deletions;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('archive-recovery-');
    db = MemoryFirestore();
    files = {};
    failFinalize = false;
    failDelete = false;
    uploads = 0;
    deletions = 0;
    service = SavedPrescriptionService(
      firestore: db,
      currentUserId: () => 'user',
      uploadFile: (file, path, type) async {
        uploads++;
        files[path] = await file.readAsString();
        if (failFinalize) db.rejectCommit = true;
        return 'https://example.test/$path';
      },
      deleteFile: (path) async {
        deletions++;
        if (failDelete) throw StateError('offline');
        files.remove(path);
      },
    );
  });
  tearDown(() => temp.delete(recursive: true));
  Future<File> source(String name, String contents) async {
    final file = File('${temp.path}/$name.pdf');
    await file.writeAsString(contents);
    return file;
  }

  Future<String> save(File file) => service.savePrescription(
    beneficiary: beneficiary,
    medicines: medicines,
    source: 'prescription',
    originalFile: file,
    originalFileType: 'pdf',
  );
  String path(String id) => 'users/user/saved_prescriptions/$id';

  test(
    'different files with identical medicines remain separate; concurrent retries share one record',
    () async {
      final first = await source('first', 'prescription one');
      final second = await source('second', 'prescription two');
      final ids = await Future.wait([save(first), save(first)]);
      expect(ids[0], ids[1]);
      final other = await save(second);
      expect(other, isNot(ids.first));
      expect(db.documents.length, 2);
      expect(db.documents[path(ids.first)]!['state'], 'saved');
      expect(files.length, 2);
    },
  );
  test(
    'rejected intent never uploads; lost finalization retains a recoverable intent',
    () async {
      final file = await source('first', 'one');
      db.rejectCommit = true;
      await expectLater(save(file), throwsStateError);
      expect(uploads, 0);
      db.rejectCommit = false;
      failFinalize = true;
      await expectLater(save(file), throwsStateError);
      expect(db.documents.values.single['state'], 'saving');
      final id = db.documents.keys.single.split('/').last;
      db.rejectCommit = false;
      failFinalize = false;
      expect(await save(file), id);
      expect(db.documents.length, 1);
      expect(db.documents[path(id)]!['state'], 'saved');
      expect(files.length, 1);
    },
  );
  test(
    'failed deletion commit cannot remove the file; cleanup failure retains durable intent and retries safely',
    () async {
      final id = await save(await source('first', 'one'));
      final model = archived(id, db.documents[path(id)]!);
      db.rejectCommit = true;
      await expectLater(service.deletePrescription(model), throwsStateError);
      expect(deletions, 0);
      expect(files.length, 1);
      expect(db.documents[path(id)]!['state'], 'saved');
      db.rejectCommit = false;
      failDelete = true;
      await service.deletePrescription(model);
      expect(db.documents[path(id)]!['state'], 'deleting');
      expect(files.length, 1);
      failDelete = false;
      await service.deletePrescription(model);
      expect(db.documents.containsKey(path(id)), isFalse);
      expect(files, isEmpty);
    },
  );
}
