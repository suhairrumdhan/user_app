import 'package:get/get.dart';

import '../models/saved_prescription_model.dart';
import '../services/saved_prescription_service.dart';

class SavedPrescriptionController extends GetxController {
  final SavedPrescriptionService _service = SavedPrescriptionService.instance;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<SavedPrescriptionModel> prescriptions =
      <SavedPrescriptionModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    bindPrescriptions();
  }

  Future<void> recordPrescriptionSearch(String prescriptionId) async {
    try {
      await _service.recordPrescriptionSearch(prescriptionId);
    } catch (e) {
      errorMessage.value = 'تعذر إتمام العملية. حاول مرة أخرى.';
      rethrow;
    }
  }

  void bindPrescriptions() {
    isLoading.value = true;
    errorMessage.value = '';

    prescriptions.bindStream(
      _service.getSavedPrescriptions().handleError((error) {
        errorMessage.value = 'تعذر إتمام العملية. حاول مرة أخرى.';
        isLoading.value = false;
      }),
    );

    ever<List<SavedPrescriptionModel>>(prescriptions, (_) {
      isLoading.value = false;
    });
  }

  Future<void> deletePrescription(SavedPrescriptionModel prescription) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _service.deletePrescription(prescription);
    } catch (e) {
      errorMessage.value = 'تعذر إتمام العملية. حاول مرة أخرى.';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateNote({
    required String prescriptionId,
    required String? note,
  }) async {
    try {
      await _service.updateNote(
        prescriptionId: prescriptionId,
        note: note,
      );
    } catch (e) {
      errorMessage.value = 'تعذر إتمام العملية. حاول مرة أخرى.';
      rethrow;
    }
  }
}