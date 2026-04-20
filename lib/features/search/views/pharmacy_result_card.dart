import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../search/models/matched_medicine_result.dart';
import 'search_ui_colors.dart';

class PharmacyResultCard extends StatelessWidget {
  final PharmacyModel pharmacy;
  final VoidCallback? onTapOrder;
  final VoidCallback? onTapChat;
  final VoidCallback? onTapOpenMap;
  final VoidCallback? onTapDetails;

  /// Reactive callback from parent
  final void Function({
  required String pharmacyId,
  required String requestedName,
  required MatchedMedicineResult newSelection,
  })? onSelectAlternative;

  const PharmacyResultCard({
    super.key,
    required this.pharmacy,
    this.onTapOrder,
    this.onTapChat,
    this.onTapOpenMap,
    this.onTapDetails,
    this.onSelectAlternative,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = pharmacy.isOpenNow || pharmacy.is24Hours
        ? SearchUiColors.success
        : SearchUiColors.danger;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(statusColor),
            const SizedBox(height: 8),
            _buildMainStats(),
            if (pharmacy.matchedMedicines.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildQuickMatchesPreview(),
            ],
            const SizedBox(height: 8),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: SearchUiColors.primary.withOpacity(0.15),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: pharmacy.imageUrl.isNotEmpty
              ? Image.network(
            pharmacy.imageUrl,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SearchUiColors.primary, SearchUiColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Iconsax.hospital,
                color: Colors.white,
                size: 22,
              ),
            ),
          )
              : Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SearchUiColors.primary, SearchUiColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Iconsax.hospital,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pharmacy.pharmacyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: SearchUiColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pharmacy.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Iconsax.location,
                    size: 14,
                    color: SearchUiColors.softText,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      pharmacy.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SearchUiColors.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onTapOpenMap ?? _openGoogleMaps,  // استخدام الدالة الافتراضية إذا لم يتم تمرير callback
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SearchUiColors.light,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: SearchUiColors.primary.withOpacity(0.10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.map_1,
                            size: 13,
                            color: SearchUiColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'الخريطة',
                            style: TextStyle(
                              color: SearchUiColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Iconsax.money_4,
            title: 'السعر الإجمالي',
            value: pharmacy.displayPrice,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Iconsax.box,
            title: 'النتائج المتوفرة',
            value: '${pharmacy.matchedCount}/${pharmacy.requestedCount} متوفر',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: SearchUiColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.2,
                    color: SearchUiColors.softText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: SearchUiColors.darkText,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.8,
                color: SearchUiColors.softText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickMatchesPreview() {
    if (pharmacy.matchedMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'أفضل التطابقات',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: SearchUiColors.darkText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pharmacy.matchedMedicines.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = pharmacy.matchedMedicines[index];
              return Container(
                width: 190,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SearchUiColors.light,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SearchUiColors.primary.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    _medicineImage(item.imageUrl, size: 50),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.requestedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                              color: SearchUiColors.softText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.matchedMedicineName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color: SearchUiColors.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onTapOrder,
            icon: const Icon(Iconsax.tick_circle, size: 17),
            label: const Text('إتمام الطلب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SearchUiColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onTapChat,
            icon: const Icon(Iconsax.message, size: 17),
            label: const Text('مراسلة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SearchUiColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTapDetails ?? () => _showDetailsDialog(context),
            icon: const Icon(Iconsax.eye, size: 17),
            label: const Text('التفاصيل'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SearchUiColors.primary,
              side: BorderSide(
                color: SearchUiColors.primary.withOpacity(0.22),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final ValueNotifier<PharmacyModel> pharmacyNotifier =
    ValueNotifier<PharmacyModel>(pharmacy);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
              maxHeight: 680,
            ),
            child: ValueListenableBuilder<PharmacyModel>(
              valueListenable: pharmacyNotifier,
              builder: (context, currentPharmacy, __) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(context, currentPharmacy),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogSummary(currentPharmacy),
                            const SizedBox(height: 14),
                            if (currentPharmacy.matchedMedicines.isNotEmpty) ...[
                              const Text(
                                'الأدوية المتوفرة',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SearchUiColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...currentPharmacy.matchedMedicines.map(
                                    (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _medicineTile(
                                    context,
                                    item,
                                    onChanged: (updatedItem) {
                                      final updatedMatches =
                                      currentPharmacy.matchedMedicines.map((m) {
                                        if (m.requestedName == updatedItem.requestedName) {
                                          return updatedItem;
                                        }
                                        return m;
                                      }).toList();

                                      final updatedTotal = updatedMatches.fold<double>(
                                        0,
                                            (sum, item) => sum + item.price,
                                      );

                                      final updatedPharmacy = currentPharmacy.copyWith(
                                        matchedMedicines: updatedMatches,
                                        totalEstimatedPrice: updatedTotal,
                                      );

                                      pharmacyNotifier.value = updatedPharmacy;

                                      onSelectAlternative?.call(
                                        pharmacyId: currentPharmacy.id,
                                        requestedName: updatedItem.requestedName,
                                        newSelection: updatedItem,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                            if (currentPharmacy.missingMedicines.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'الأدوية غير المتوفرة',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SearchUiColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: currentPharmacy.missingMedicines
                                    .map(
                                      (name) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SearchUiColors.danger.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: SearchUiColors.danger.withOpacity(0.16),
                                      ),
                                    ),
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: SearchUiColors.danger,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
  Widget _buildDialogHeader(BuildContext context, PharmacyModel currentPharmacy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              currentPharmacy.pharmacyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SearchUiColors.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogSummary(PharmacyModel currentPharmacy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dialogMetric(
                  'السعر الإجمالي',
                  currentPharmacy.displayPrice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dialogMetric(
                  'نسبة التوفر',
                  '${currentPharmacy.coveragePercent.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dialogMetric(
                  'التوفر',
                  '${currentPharmacy.matchedCount}/${currentPharmacy.requestedCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dialogMetric(
                  'التأمين',
                  currentPharmacy.insuranceLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dialogMetric(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SearchUiColors.softText,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SearchUiColors.darkText,
              fontSize: 12.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicineTile(
      BuildContext context,
      MatchedMedicineResult item, {
        required ValueChanged<MatchedMedicineResult> onChanged,
      }) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        MatchedMedicineResult selected = item;
        final scientific = (selected.matchedScientificName ?? '').trim();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SearchUiColors.primary.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _medicineImage(selected.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.requestedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SearchUiColors.darkText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected.matchedMedicineName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SearchUiColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (scientific.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            scientific,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SearchUiColors.softText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${selected.price.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(
                          color: SearchUiColors.darkText,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SearchUiColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${selected.matchScore.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: SearchUiColors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (selected.similarMatches.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'النتائج المتشابهة',
                    style: TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w800,
                      color: SearchUiColors.darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selected.similarMatches.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final alt = selected.similarMatches[index];
                      return _similarMedicineCard(
                        item: alt,
                        isSelected: false,
                        onTap: () {
                          final oldSelected = selected;

                          final nextAlternatives = <MatchedMedicineResult>[
                            oldSelected.copyWith(similarMatches: const []),
                            ...selected.similarMatches
                                .where((e) => e.matchedMedicineId != alt.matchedMedicineId)
                                .toList(),
                          ];

                          final newSelected = alt.copyWith(
                            similarMatches: nextAlternatives,
                          );

                          setLocalState(() {
                            selected = newSelected;
                          });

                          onChanged(newSelected);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _medicineImage(String? imageUrl, {double size = 54}) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Iconsax.gallery,
          size: 22,
          color: SearchUiColors.primary,
        ),
      )
          : const Icon(
        Iconsax.gallery,
        size: 22,
        color: SearchUiColors.primary,
      ),
    );
  }

  Widget _similarMedicineCard({
    required MatchedMedicineResult item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? SearchUiColors.primary.withOpacity(0.08)
              : SearchUiColors.light,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? SearchUiColors.primary
                : SearchUiColors.primary.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            _medicineImage(item.imageUrl, size: 50),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.matchedMedicineName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: SearchUiColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(2)} د.ل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                      color: SearchUiColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.matchScore.toStringAsFixed(0)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                      color: SearchUiColors.softText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _openGoogleMaps() {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;

    if (lat == null || lng == null) return;

    // فتح خرائط Google مباشرة
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    // يمكنك استخدام url_launcher package
    // لا تنس إضافة الحزمة: flutter pub add url_launcher
    // ثم استيرادها: import 'package:url_launcher/url_launcher.dart';

    _launchUrl(url);
  }

  Future<void> _launchUrl(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}