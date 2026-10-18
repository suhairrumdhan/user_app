import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../prescription/views/search_results_page.dart';
import '../../search/controllers/search_controller.dart' as app_search;
import '../../search/models/medicine_search_request.dart';
import '../../search/services/medicine_normalizer.dart';
import '../controllers/saved_prescription_controller.dart';
import '../models/saved_prescription_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SavedPrescriptionsPage extends StatelessWidget {
  const SavedPrescriptionsPage({super.key});

  static const Color pPrimaryColor = Color(0xFF5EABD6);
  static const Color pLightColor = Color(0xFFF5FBFF);
  static const Color pDarkTextColor = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SavedPrescriptionController());

    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.prescriptions.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pPrimaryColor,
                        ),
                      ),
                    );
                  }

                  if (controller.errorMessage.value.isNotEmpty &&
                      controller.prescriptions.isEmpty) {
                    return _buildErrorState(controller.errorMessage.value);
                  }

                  if (controller.prescriptions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: controller.prescriptions.length,
                    itemBuilder: (context, index) {
                      final item = controller.prescriptions[index];
                      return _buildPrescriptionCard(
                        context: context,
                        controller: controller,
                        prescription: item,
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'وصفاتك المحفوظة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.archive_book,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.archive_book, size: 82, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد وصفات محفوظة',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'احفظ الوصفات أثناء البحث لتجدها هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.warning_2, size: 70, color: Colors.orange),
            const SizedBox(height: 14),
            const Text(
              'تعذر تحميل الوصفات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: pDarkTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard({
    required BuildContext context,
    required SavedPrescriptionController controller,
    required SavedPrescriptionModel prescription,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildIcon(prescription),
              const SizedBox(width: 14),
              Expanded(child: _buildMainInfo(prescription)),
              _buildDeleteButton(
                context: context,
                controller: controller,
                prescription: prescription,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMedicinePreview(prescription),
          const SizedBox(height: 12),
          _buildSearchHistoryPreview(prescription),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSmallAction(
                  icon: Iconsax.search_normal_1,
                  label: 'إعادة البحث',
                  color: pPrimaryColor,
                  onTap: () => _reusePrescription(
                    controller: controller,
                    prescription: prescription,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (prescription.hasOriginalFile &&
                  prescription.originalFileUrl != null)
                Expanded(
                  child: _buildSmallAction(
                    icon: prescription.originalFileType == 'pdf'
                        ? Iconsax.document_text
                        : Iconsax.gallery,
                    label: 'عرض الملف',
                    color: const Color(0xFF4CAF50),
                    onTap: () => _openOriginalFile(
                      url: prescription.originalFileUrl!,
                      type: prescription.originalFileType ?? 'image',
                    ),
                  ),
                )
              else
                Expanded(
                  child: _buildSmallAction(
                    icon: Iconsax.document,
                    label: 'بدون ملف',
                    color: Colors.grey,
                    onTap: null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(SavedPrescriptionModel prescription) {
    final icon = prescription.source == 'manual'
        ? Iconsax.edit_2
        : prescription.originalFileType == 'pdf'
        ? Iconsax.document_text
        : Iconsax.gallery;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: pPrimaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: pPrimaryColor, size: 26),
    );
  }

  Widget _buildMainInfo(SavedPrescriptionModel prescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prescription.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: pDarkTextColor,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              prescription.beneficiaryType == 'self'
                  ? Iconsax.profile_circle
                  : Iconsax.people,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${prescription.beneficiaryName} • ${prescription.beneficiaryRelation}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(Iconsax.calendar, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 5),
            Text(
              _formatDate(prescription.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeleteButton({
    required BuildContext context,
    required SavedPrescriptionController controller,
    required SavedPrescriptionModel prescription,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Iconsax.trash, color: Colors.red, size: 20),
        onPressed: () => _showDeleteDialog(
          context: context,
          controller: controller,
          prescription: prescription,
        ),
      ),
    );
  }

  Widget _buildMedicinePreview(SavedPrescriptionModel prescription) {
    final preview = prescription.medicines.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pPrimaryColor.withOpacity(0.08)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...preview.map((m) => _buildMedicineTag(m.name)),
          if (prescription.medicines.length > 3)
            _buildMedicineTag('+${prescription.medicines.length - 3}'),
        ],
      ),
    );
  }

  Widget _buildSearchHistoryPreview(SavedPrescriptionModel prescription) {
    final history = prescription.searchHistory.reversed.take(3).toList();

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pPrimaryColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.clock, size: 16, color: pPrimaryColor),
              const SizedBox(width: 6),
              Text(
                'مرات البحث',
                style: TextStyle(
                  color: pPrimaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${prescription.searchHistory.length}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map(
            (date) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(Iconsax.calendar_1, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(date),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    return '$d/$m/$y - $h:$min';
  }

  Widget _buildMedicineTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pPrimaryColor.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: pDarkTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSmallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(onTap == null ? 0.06 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(onTap == null ? 0.08 : 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reusePrescription({
    required SavedPrescriptionController controller,
    required SavedPrescriptionModel prescription,
  }) async {
    final medicines = prescription.medicines
        .map((m) => MedicineModel(name: m.name))
        .toList();

    final beneficiary = BeneficiaryModel(
      id: prescription.beneficiaryId,
      name: prescription.beneficiaryName,
      type: prescription.beneficiaryType,
      relation: prescription.beneficiaryRelation,
    );

    final requests = medicines.map((medicine) {
      final raw = medicine.displayName.trim();

      return MedicineSearchRequest(
        rawText: raw,
        normalizedText: MedicineNormalizer.normalize(raw),
        strength: MedicineNormalizer.extractStrength(raw),
        dosageForm: MedicineNormalizer.extractDosageForm(raw),
        baseName: MedicineNormalizer.extractBaseName(raw),
        searchTokens: MedicineNormalizer.buildSearchTokens(raw),
        resolvedDisplayName: raw,
      );
    }).toList();

    final searchController = Get.isRegistered<app_search.SearchController>()
        ? Get.find<app_search.SearchController>()
        : Get.put(app_search.SearchController());

    searchController.clearAll();
    searchController.setSearchSource(prescription.source);
    searchController.setRequests(requests);

    await controller.recordPrescriptionSearch(prescription.id);

    Get.to(
      () => SearchResultsPage(
        medicines: medicines,
        searchSource: prescription.source,
        initialBeneficiary: beneficiary,
        prescriptionId: prescription.id,
        prescriptionImageUrl: prescription.originalFileUrl,
      ),
    );
  }

  void _openOriginalFile({required String url, required String type}) {
    Get.to(() => SavedPrescriptionFileViewerPage(fileUrl: url, fileType: type));
  }

  void _showDeleteDialog({
    required BuildContext context,
    required SavedPrescriptionController controller,
    required SavedPrescriptionModel prescription,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الوصفة'),
        content: Text('هل أنت متأكد من حذف "${prescription.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await controller.deletePrescription(prescription);
                Get.snackbar(
                  'تم الحذف',
                  'تم حذف الوصفة المحفوظة',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              } catch (_) {
                Get.snackbar(
                  'خطأ',
                  'تعذر حذف الوصفة',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();

    return '$d/$m/$y';
  }
}

class SavedPrescriptionFileViewerPage extends StatelessWidget {
  final String fileUrl;
  final String fileType;

  const SavedPrescriptionFileViewerPage({
    super.key,
    required this.fileUrl,
    required this.fileType,
  });

  static const Color primary = Color(0xFF5EABD6);

  bool get _isPdf => fileType.toLowerCase() == 'pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isPdf ? const Color(0xFFF8FBFF) : Colors.black,
      appBar: AppBar(
        backgroundColor: _isPdf ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _isPdf ? primary : Colors.white),
        title: Text(
          _isPdf ? 'عرض ملف الوصفة' : 'عرض صورة الوصفة',
          style: TextStyle(
            color: _isPdf ? primary : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isPdf ? _buildPdfViewer() : _buildImageViewer(),
    );
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.network(
      fileUrl,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowPageLoadingIndicator: true,
    );
  }

  Widget _buildImageViewer() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: fileUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
