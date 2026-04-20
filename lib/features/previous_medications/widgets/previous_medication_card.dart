import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../models/previous_medication_model.dart';

class PreviousMedicationCard extends StatelessWidget {
  final PreviousMedicationModel medication;
  final Color statusColor;
  final Color visibilityColor;
  final Color reminderColor;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDetailsTap;
  final VoidCallback? onArchiveTap;
  final VoidCallback? onStopVisibilityTap;
  final VoidCallback? onReminderTap;

  const PreviousMedicationCard({
    super.key,
    required this.medication,
    required this.statusColor,
    required this.visibilityColor,
    required this.reminderColor,
    required this.subtitle,
    required this.onTap,
    required this.onDetailsTap,
    this.onArchiveTap,
    this.onStopVisibilityTap,
    this.onReminderTap,
  });

  String _formatDate(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LeadingIcon(
                    isVisible: medication.isCurrentlyVisibleToPharmacist,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopRow(
                          title: medication.medicineName,
                          dateText: _formatDate(medication.takenAt),
                        ),
                        const SizedBox(height: 6),
                        if (subtitle.trim().isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(
                              icon: Iconsax.tick_circle,
                              label: medication.statusLabel,
                              color: statusColor,
                            ),
                            _Badge(
                              icon: medication.isCurrentlyVisibleToPharmacist
                                  ? Iconsax.eye
                                  : Iconsax.eye_slash,
                              label: medication.pharmacistVisibilityLabel,
                              color: visibilityColor,
                            ),
                            _Badge(
                              icon: Iconsax.notification,
                              label: medication.reminderStatusLabel,
                              color: reminderColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Iconsax.arrow_left_2,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SearchUiColors.light,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _MetaRow(
                      label: 'الجرعة',
                      value: medication.dosage ?? 'غير محدد',
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(
                      label: 'الصيدلية',
                      value: medication.pharmacyName ?? 'غير محدد',
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(
                      label: 'العلاقة',
                      value: medication.ownerRelation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniActionButton(
                      label: 'التفاصيل',
                      icon: Iconsax.document_text,
                      color: SearchUiColors.primary,
                      onTap: onDetailsTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniActionButton(
                      label: medication.hasLinkedReminder
                          ? 'فصل التذكير'
                          : 'تذكير',
                      icon: Iconsax.notification,
                      color: reminderColor,
                      onTap: onReminderTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniActionButton(
                      label: medication.isCurrentlyVisibleToPharmacist
                          ? 'إخفاء'
                          : 'مخفي',
                      icon: Iconsax.eye_slash,
                      color: visibilityColor,
                      onTap: medication.isCurrentlyVisibleToPharmacist
                          ? onStopVisibilityTap
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniActionButton(
                      label: medication.isArchived ? 'مؤرشف' : 'أرشفة',
                      icon: Iconsax.archive,
                      color: Colors.grey,
                      onTap: medication.isArchived ? null : onArchiveTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final bool isVisible;

  const _LeadingIcon({
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final color1 = isVisible ? const Color(0xFF5EABD6) : const Color(0xFF90A4AE);
    final color2 = isVisible ? const Color(0xFF7A8CFF) : const Color(0xFFB0BEC5);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Iconsax.hospital,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final String title;
  final String dateText;

  const _TopRow({
    required this.title,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          dateText,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}