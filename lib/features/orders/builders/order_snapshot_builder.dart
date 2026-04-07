import 'package:get/get.dart';

import '../../family/controllers/family_controller.dart';
import '../../family/models/family_member_model.dart';
import '../../insurance/controllers/insurance_controller.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../profile/controllers/user_controller.dart';
import '../../search/models/matched_medicine_result.dart';
import '../../search/services/medicine_normalizer.dart';
import '../models/order_status.dart';

class OrderSnapshotBuilder {
  OrderSnapshotBuilder._();

  static OrderBeneficiarySnapshot buildBeneficiarySnapshot({
    required BeneficiaryModel beneficiary,
    required String ownerUserId,
  }) {
    final userController = Get.find<UserController>();
    final familyController = Get.find<FamilyController>();

    if (beneficiary.isSelf) {
      final currentUser = userController.user.value;

      if (currentUser == null) {
        throw Exception('تعذر تحميل بيانات المستخدم الحالي');
      }

      final allergies = _safeStringList(currentUser.allergies);
      final healthConditions = _safeStringList(currentUser.healthConditions);
      final currentMedications =
      _safeStringList(currentUser.currentMedications);

      final hasHealthData = allergies.isNotEmpty ||
          healthConditions.isNotEmpty ||
          currentMedications.isNotEmpty ||
          _hasText(currentUser.bloodType) ||
          _resolveAge(
            explicitAge: null,
            dateOfBirth: currentUser.dateOfBirth,
          ) != null ||
          currentUser.dateOfBirth != null ||
          _hasText(currentUser.gender);

      return OrderBeneficiarySnapshot(
        beneficiaryId: currentUser.id,
        ownerUserId: ownerUserId,
        type: BeneficiaryType.self,
        name: _safeName(
          preferred: beneficiary.name,
          fallback: currentUser.name,
        ),
        relationLabel: beneficiary.relation?.trim().isNotEmpty == true
            ? beneficiary.relation!.trim()
            : 'أنا',
        familyMemberId: null,
        gender: _safeText(currentUser.gender),
        bloodType: _safeText(currentUser.bloodType),
        age: _resolveAge(
          explicitAge: null,
          dateOfBirth: currentUser.dateOfBirth,
        ),        dateOfBirth: currentUser.dateOfBirth,
        allergies: allergies,
        healthConditions: healthConditions,
        currentMedications: currentMedications,
        hasHealthData: hasHealthData,
      );
    }

    final FamilyMemberModel? member = familyController.members
        .cast<FamilyMemberModel?>()
        .firstWhere(
          (m) => m?.id == beneficiary.id,
      orElse: () => null,
    );

    if (member == null) {
      throw Exception('تعذر العثور على بيانات المستفيد من أفراد العائلة');
    }

    final allergies = _safeStringList(member.allergies);
    final healthConditions = _safeStringList(member.healthConditions);
    final currentMedications = _safeStringList(member.currentMedications);

    final hasHealthData = allergies.isNotEmpty ||
        healthConditions.isNotEmpty ||
        currentMedications.isNotEmpty ||
        _hasText(member.bloodType) ||
        member.age != null ||
        member.dateOfBirth != null ||
        _hasText(member.gender);

    return OrderBeneficiarySnapshot(
      beneficiaryId: beneficiary.id,
      ownerUserId: ownerUserId,
      type: BeneficiaryType.family,
      name: _safeName(
        preferred: beneficiary.name,
        fallback: member.name,
      ),
      relationLabel: beneficiary.relation?.trim().isNotEmpty == true
          ? beneficiary.relation!.trim()
          : (member.relation?.trim().isNotEmpty == true
          ? member.relation!.trim()
          : 'فرد من العائلة'),
      familyMemberId: member.id,
      gender: _safeText(member.gender),
      bloodType: _safeText(member.bloodType),
      age: member.age,
      dateOfBirth: member.dateOfBirth,
      allergies: allergies,
      healthConditions: healthConditions,
      currentMedications: currentMedications,
      hasHealthData: hasHealthData,
    );
  }

  static OrderInsuranceSnapshot buildInsuranceSnapshot({
    required BeneficiaryModel beneficiary,
    required bool useInsurance,
  }) {
    if (!useInsurance) {
      return const OrderInsuranceSnapshot(
        enabled: false,
        companyCodes: [],
        companyNames: [],
        cardNumbers: [],
      );
    }

    final insuranceController = Get.find<InsuranceController>();

    final activeInsurances = insuranceController.insurances.where((item) {
      if (!item.isActive) return false;

      if (beneficiary.isSelf) {
        return true;
      }

      return item.coveredMemberIds.contains(beneficiary.id);
    }).toList();

    if (activeInsurances.isEmpty) {
      return const OrderInsuranceSnapshot(
        enabled: false,
        companyCodes: [],
        companyNames: [],
        cardNumbers: [],
      );
    }

    return OrderInsuranceSnapshot(
      enabled: true,
      companyCodes: activeInsurances
          .map((e) => e.companyCode.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
      companyNames: activeInsurances
          .map((e) => e.companyName.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
      cardNumbers: activeInsurances
          .map((e) => e.cardNumber.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
    );
  }
  static OrderPharmacySnapshot buildPharmacySnapshot({
    required PharmacyModel pharmacy,
  }) {
    return OrderPharmacySnapshot(
      pharmacyId: pharmacy.id,
      pharmacyName: pharmacy.displayName,
      phoneNumber: pharmacy.hasPhone ? pharmacy.phoneNumber : null,
      imageUrl: pharmacy.hasImage ? pharmacy.imageUrl : null,
      address: pharmacy.displayAddress,
      isOnline: pharmacy.isOnline,
      is24Hours: pharmacy.is24Hours,
      isOpenNow: pharmacy.isOpenNow,
      latitude: pharmacy.latitude,
      longitude: pharmacy.longitude,
      distanceKm: pharmacy.distanceKm > 0 ? pharmacy.distanceKm : pharmacy.distance,
      estimatedTotalPrice:
      pharmacy.totalEstimatedPrice > 0 ? pharmacy.totalEstimatedPrice : null,
      pharmacyScore: pharmacy.pharmacyScore > 0 ? pharmacy.pharmacyScore : null,
    );
  }

  static List<OrderMedicineItem> buildMedicineItems({
    required List<MedicineModel> medicines,
    PharmacyModel? selectedPharmacy,
  }) {
    return medicines.map((medicine) {
      final rawName = medicine.displayName.trim();
      final normalized = MedicineNormalizer.normalize(rawName);
      final strength = MedicineNormalizer.extractStrength(rawName);
      final dosageForm = MedicineNormalizer.extractDosageForm(rawName);

      MatchedMedicineResult? matched;

      if (selectedPharmacy != null && selectedPharmacy.matchedMedicines.isNotEmpty) {
        matched = selectedPharmacy.matchedMedicines.cast<MatchedMedicineResult?>().firstWhere(
              (item) =>
          item != null &&
              item.requestedName.trim().toLowerCase() == rawName.toLowerCase(),
          orElse: () => null,
        );
      }

      return OrderMedicineItem(
        requestedName: rawName,
        normalizedName: normalized,
        strength: strength,
        dosageForm: dosageForm,
        quantity: 1,
        note: null,
        matchedMedicineId: matched?.matchedMedicineId,
        matchedMedicineName: matched?.matchedMedicineName,
        estimatedPrice: matched?.price,
        availableAtSelection: matched != null,
      );
    }).toList();
  }


  static OrderModel buildOrder({
    required String ownerUserId,
    required OrderUserSnapshot userSnapshot,
    required PharmacyModel pharmacy,
    required BeneficiaryModel beneficiary,
    required List<MedicineModel> medicines,
    required bool useInsurance,
    required OrderRequestSource requestSource,
    String? userNote,
    String? chatId,
    String? prescriptionId,
    String? prescriptionImageUrl,
    String? prescriptionText,
    Map<String, dynamic>? metadata,
  }) {
    final beneficiarySnapshot = buildBeneficiarySnapshot(
      beneficiary: beneficiary,
      ownerUserId: ownerUserId,
    );

    final insuranceSnapshot = buildInsuranceSnapshot(
      beneficiary: beneficiary,
      useInsurance: useInsurance,
    );

    final pharmacySnapshot = buildPharmacySnapshot(
      pharmacy: pharmacy,
    );

    final medicineItems = buildMedicineItems(
      medicines: medicines,
      selectedPharmacy: pharmacy,
    );

    final now = DateTime.now();

    final containsInsurance = insuranceSnapshot.hasInsurance;

    final hasSensitiveHealthData =
        beneficiarySnapshot.allergies.isNotEmpty ||
            beneficiarySnapshot.healthConditions.isNotEmpty ||
            beneficiarySnapshot.currentMedications.isNotEmpty ||
            beneficiarySnapshot.hasHealthData;

    final status = OrderStatus.pending;

    return OrderModel(
      user: userSnapshot,
      pharmacy: pharmacySnapshot,
      beneficiary: beneficiarySnapshot,
      insurance: insuranceSnapshot,
      requestSource: requestSource,
      requestSourceLabel: requestSource.label,
      medicines: medicineItems,
      status: status,
      statusLabel: status.label,
      userNote: _safeOptionalText(userNote),
      pharmacyNote: null,
      chatId: _safeOptionalText(chatId),
      totalItemsCount: medicineItems.fold<int>(
        0,
            (sum, item) => sum + item.quantity,
      ),
      estimatedTotalPrice: pharmacySnapshot.estimatedTotalPrice,
      hasSensitiveHealthData: hasSensitiveHealthData,
      containsInsurance: containsInsurance,
      prescriptionId: _safeOptionalText(prescriptionId),
      prescriptionImageUrl: _safeOptionalText(prescriptionImageUrl),
      prescriptionText: _safeOptionalText(prescriptionText),
      metadata: metadata ?? const {},
      statusHistory: [
        OrderStatusLog(
          status: status.value,
          label: status.label,
          changedById: ownerUserId,
          changedByType: 'user',
          note: 'تم إنشاء الطلب',
          changedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
      submittedAt: now,
      reviewedAt: null,
      completedAt: null,
      cancelledAt: null,
    );
  }

  static String? _safeOptionalText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static OrderUserSnapshot buildUserSnapshot({
    required String userId,
  }) {
    final userController = Get.find<UserController>();
    final currentUser = userController.user.value;

    if (currentUser == null) {
      throw Exception('تعذر تحميل بيانات المستخدم');
    }

    return OrderUserSnapshot(
      userId: userId,
      name: _safeName(
        preferred: currentUser.name,
        fallback: 'مستخدم',
      ),
      phone: _safeText(currentUser.phone),
      email: _safeText(currentUser.email),
      profileImageUrl: _safeText(currentUser.profileImageUrl),
    );
  }
  static int? _resolveAge({
    int? explicitAge,
    DateTime? dateOfBirth,
  }) {
    if (explicitAge != null && explicitAge > 0) return explicitAge;
    if (dateOfBirth == null) return null;

    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;

    final hasHadBirthdayThisYear =
        now.month > dateOfBirth.month ||
            (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);

    if (!hasHadBirthdayThisYear) {
      age--;
    }

    return age >= 0 ? age : null;
  }

  static List<String> _safeStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _safeText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool _hasText(dynamic value) {
    final text = value?.toString().trim();
    return text != null && text.isNotEmpty;
  }

  static String _safeName({
    required String? preferred,
    required String? fallback,
  }) {
    final p = preferred?.trim();
    if (p != null && p.isNotEmpty) return p;

    final f = fallback?.trim();
    if (f != null && f.isNotEmpty) return f;

    return 'مستفيد';
  }
}