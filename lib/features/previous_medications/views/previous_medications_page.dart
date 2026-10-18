import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../controllers/previous_medications_controller.dart';
import '../models/previous_medication_model.dart';
import '../widgets/previous_medication_card.dart';
import '../widgets/previous_medications_empty_state.dart';

class PreviousMedicationsPage extends StatelessWidget {
  const PreviousMedicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PreviousMedicationsController controller =
    Get.put(PreviousMedicationsController(), permanent: true);

    return Scaffold(
      backgroundColor: SearchUiColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HeaderSection(controller: controller),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: SearchUiColors.light,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _FiltersBar(controller: controller),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value &&
                            controller.allRecords.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: SearchUiColors.primary,
                            ),
                          );
                        }

                        final records = controller.filteredRecords;

                        if (records.isEmpty) {
                          return const PreviousMedicationsEmptyState();
                        }

                        return RefreshIndicator(
                          color: SearchUiColors.primary,
                          onRefresh: controller.refreshRecords,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = records[index];

                              return PreviousMedicationCard(
                                medication: item,
                                statusColor: controller.getStatusColor(item),
                                visibilityColor:
                                controller.getVisibilityColor(item),
                                reminderColor:
                                controller.getReminderColor(item),
                                subtitle: controller.buildSubtitle(item),
                                onTap: () => _showDetailsSheet(
                                  context: context,
                                  controller: controller,
                                  item: item,
                                ),
                                onDetailsTap: () => _showDetailsSheet(
                                  context: context,
                                  controller: controller,
                                  item: item,
                                ),
                                onArchiveTap: item.isArchived
                                    ? null
                                    : () => controller.archiveRecord(item.id),
                                onStopVisibilityTap:
                                item.isCurrentlyVisibleToPharmacist
                                    ? () => controller
                                    .stopPharmacistVisibility(item.id)
                                    : null,
                                onReminderTap: item.hasLinkedReminder
                                    ? () => controller.clearReminderLink(
                                  recordId: item.id,
                                )
                                    : () {
                                  Get.snackbar(
                                    'التذكير',
                                    'يمكنك إضافة تذكير من صفحة التذكيرات.',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                              );
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsSheet({
    required BuildContext context,
    required PreviousMedicationsController controller,
    required PreviousMedicationModel item,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _PreviousMedicationDetailsSheet(
          controller: controller,
          item: item,
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final PreviousMedicationsController controller;

  const _HeaderSection({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(
                    Iconsax.arrow_left_2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سجل الأدوية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    title: 'الإجمالي',
                    value: controller.totalCount.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    title: 'ظاهر للصيدلي',
                    value: controller.visibleToPharmacistCount.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    title: 'بتذكير',
                    value: controller.withReminderCount.toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String value;

  const _StatPill({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final PreviousMedicationsController controller;

  const _FiltersBar({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final filters = PreviousMedicationsFilter.values;

    return SizedBox(
      height: 46,
      child: Obx(() {
        final selected = controller.selectedFilter.value;

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = filter == selected;

            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => controller.setFilter(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SearchUiColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? SearchUiColors.primary
                        : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    controller.getFilterLabel(filter),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _PreviousMedicationDetailsSheet extends StatelessWidget {
  final PreviousMedicationsController controller;
  final PreviousMedicationModel item;

  const _PreviousMedicationDetailsSheet({
    required this.controller,
    required this.item,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = controller.getStatusColor(item);
    final visibilityColor = controller.getVisibilityColor(item);
    final reminderColor = controller.getReminderColor(item);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFD),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.medicineName,
                        style: const TextStyle(
                          color: SearchUiColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Iconsax.close_circle),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Iconsax.tick_circle,
                        label: item.statusLabel,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Iconsax.eye,
                        label: item.pharmacistVisibilityLabel,
                        color: visibilityColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Iconsax.notification,
                        label: item.reminderStatusLabel,
                        color: reminderColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailsCard(
                  title: 'معلومات أساسية',
                  children: [
                    _DetailRow(label: 'اسم الدواء', value: item.medicineName),
                    _DetailRow(label: 'الجرعة', value: item.dosage ?? 'غير محدد'),
                    _DetailRow(label: 'طريقة/شكل الاستخدام', value: item.route ?? 'غير محدد'),
                    _DetailRow(label: 'الملاحظات', value: item.notes ?? 'لا توجد'),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailsCard(
                  title: 'المستفيد والطلب',
                  children: [
                    _DetailRow(label: 'اسم المستفيد', value: item.ownerName),
                    _DetailRow(label: 'العلاقة', value: item.ownerRelation),
                    _DetailRow(
                      label: 'الصيدلية',
                      value: item.pharmacyName ?? 'غير محدد',
                    ),
                    _DetailRow(
                      label: 'رقم الطلب',
                      value: item.orderId ?? 'غير محدد',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailsCard(
                  title: 'الفترة الزمنية',
                  children: [
                    _DetailRow(
                      label: 'تاريخ الأخذ',
                      value: _formatDate(item.takenAt),
                    ),
                    _DetailRow(
                      label: 'بداية العلاج',
                      value: _formatDate(item.treatmentStartDate),
                    ),
                    _DetailRow(
                      label: 'نهاية العلاج',
                      value: _formatDate(item.treatmentEndDate),
                    ),
                    _DetailRow(
                      label: 'يظهر للصيدلي من',
                      value: _formatDate(item.showToPharmacistFrom),
                    ),
                    _DetailRow(
                      label: 'يظهر للصيدلي حتى',
                      value: _formatDate(item.showToPharmacistUntil),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: item.hasLinkedReminder
                            ? 'إلغاء ربط التذكير'
                            : 'إنشاء تذكير',
                        icon: item.hasLinkedReminder
                            ? Iconsax.close_circle
                            : Iconsax.notification,
                        backgroundColor: reminderColor.withOpacity(0.12),
                        foregroundColor: reminderColor,
                        onTap: () {
                          Get.back();
                          if (item.hasLinkedReminder) {
                            controller.clearReminderLink(recordId: item.id);
                          } else {
                            Get.snackbar(
                              'التذكير',
                              'اربطيه مع شاشة إنشاء التذكير في الخطوة التالية',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: item.isCurrentlyVisibleToPharmacist
                            ? 'إخفاء عن الصيدلي'
                            : 'تم إيقاف الظهور',
                        icon: Iconsax.eye_slash,
                        backgroundColor: visibilityColor.withOpacity(0.12),
                        foregroundColor: visibilityColor,
                        onTap: item.isCurrentlyVisibleToPharmacist
                            ? () {
                          Get.back();
                          controller.stopPharmacistVisibility(item.id);
                        }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: item.isCompleted ? 'مكتمل' : 'تعيين كمكتمل',
                        icon: Iconsax.tick_circle,
                        backgroundColor: statusColor.withOpacity(0.12),
                        foregroundColor: statusColor,
                        onTap: item.isCompleted
                            ? null
                            : () {
                          Get.back();
                          controller.markCompleted(item.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: item.isArchived ? 'مؤرشف' : 'أرشفة',
                        icon: Iconsax.archive,
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade700,
                        onTap: item.isArchived
                            ? null
                            : () {
                          Get.back();
                          controller.archiveRecord(item.id);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailsCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.document_text,
                size: 18,
                color: SearchUiColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 13.4,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}