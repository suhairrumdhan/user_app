import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../search/models/matched_medicine_result.dart';
import 'search_ui_colors.dart';

class PharmacyResultCard extends StatelessWidget {
  final PharmacyModel pharmacy;
  final VoidCallback? onTapOrder;
  final VoidCallback? onTapChat;
  final VoidCallback? onTapOpenMap;
  final VoidCallback? onTapDetails;

  const PharmacyResultCard({
    super.key,
    required this.pharmacy,
    this.onTapOrder,
    this.onTapChat,
    this.onTapOpenMap,
    this.onTapDetails,
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
        borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 12),
            _buildMainStats(),
            const SizedBox(height: 12),
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
            gradient: const LinearGradient(
              colors: [SearchUiColors.primary, SearchUiColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Iconsax.hospital,
            color: Colors.white,
            size: 22,
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                    onTap: onTapOpenMap,
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
                  ),
                ],
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
            title: 'نسبة التوفر',
            value: '${pharmacy.coveragePercent.toStringAsFixed(0)}%',
            subtitle:
            '${pharmacy.matchedCount}/${pharmacy.requestedCount} متوفر',
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
              maxHeight: 640,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogHeader(context),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogSummary(),
                        const SizedBox(height: 14),
                        if (pharmacy.matchedMedicines.isNotEmpty) ...[
                          const Text(
                            'الأدوية المتوفرة',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: SearchUiColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...pharmacy.matchedMedicines
                              .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _medicineTile(item),
                          )),
                        ],
                        if (pharmacy.missingMedicines.isNotEmpty) ...[
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
                            children: pharmacy.missingMedicines
                                .map(
                                  (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: SearchUiColors.danger
                                      .withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: SearchUiColors.danger
                                        .withOpacity(0.16),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pharmacy.pharmacyName,
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

  Widget _buildDialogSummary() {
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
                  pharmacy.displayPrice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dialogMetric(
                  'نسبة التوفر',
                  '${pharmacy.coveragePercent.toStringAsFixed(0)}%',
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
                  '${pharmacy.matchedCount}/${pharmacy.requestedCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dialogMetric(
                  'التأمين',
                  pharmacy.insuranceLabel,
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

  Widget _medicineTile(MatchedMedicineResult item) {
    final scientific = (item.matchedScientificName ?? '').trim();

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SearchUiColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Iconsax.box,
              size: 18,
              color: SearchUiColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.requestedName,
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
                  item.matchedMedicineName,
                  maxLines: 1,
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
                '${item.price.toStringAsFixed(2)} د.ل',
                style: const TextStyle(
                  color: SearchUiColors.darkText,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SearchUiColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.matchScore.toStringAsFixed(0)}%',
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
    );
  }
}