import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:user_application/features/reminders/widgets/reminder_section_header.dart';

import '../controllers/reminders_controller.dart';
import '../data/models/medication_reminder_model.dart';
import '../views/reminder_details_page.dart';
import 'action_sheet.dart';
import 'owner_badge.dart';
import 'reminder_card.dart';
import 'time_chip.dart';

class MedicationReminderCard extends StatelessWidget {
  final MedicationReminderModel reminder;
  final RemindersController controller;

  const MedicationReminderCard({
    super.key,
    required this.reminder,
    required this.controller,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSuccessColor = Color(0xFF4CAF50);
  static const Color rWarningColor = Color(0xFFFF9800);
  static const Color rDangerColor = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final isActive = reminder.status == 'active';

    return ReminderCard(
      borderColor: isActive
          ? rPrimaryColor.withOpacity(0.12)
          : Colors.orange.withOpacity(0.18),
      onTap: () {
        Get.to(
              () => ReminderDetailsPage(
            reminderId: reminder.id,
            reminderType: 'medication',
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? rPrimaryColor.withOpacity(0.10)
                      : Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Iconsax.book,
                  color: isActive ? rPrimaryColor : rWarningColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.medicineName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reminder.dosage?.trim().isNotEmpty == true
                          ? reminder.dosage!
                          : 'بدون جرعة محددة',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'taken':
                      await controller.markMedicationTaken(reminder);
                      break;
                    case 'snooze':
                      await controller.snoozeMedication(reminder);
                      break;
                    case 'pause':
                      if (isActive) {
                        await controller.pauseMedication(reminder);
                      } else {
                        await controller.resumeMedication(reminder);
                      }
                      break;
                    case 'delete':
                      await controller.deleteMedicationReminder(reminder);
                      break;
                    case 'details':
                      Get.to(
                            () => ReminderDetailsPage(
                          reminderId: reminder.id,
                          reminderType: 'medication',
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'taken',
                    child: Text('تم الأخذ'),
                  ),
                  const PopupMenuItem(
                    value: 'snooze',
                    child: Text('تأجيل'),
                  ),
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(isActive ? 'إيقاف مؤقت' : 'استئناف'),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('عرض التفاصيل'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [
                  rPrimaryColor,
                  const Color(0xFF7BC4EA),
                ]
                    : [
                  const Color(0xFFFFB74D),
                  const Color(0xFFFFCC80),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OwnerBadge(owner: reminder.owner),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                  reminder.times.map((e) => TimeChip(time: e)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniAction(
                  title: 'تم الأخذ',
                  icon: Iconsax.tick_circle,
                  color: rSuccessColor,
                  onTap: () => controller.markMedicationTaken(reminder),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAction(
                  title: 'تأجيل',
                  icon: Iconsax.timer_pause,
                  color: rWarningColor,
                  onTap: () => controller.snoozeMedication(reminder),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAction(
                  title: isActive ? 'إيقاف' : 'استئناف',
                  icon: isActive
                      ? Iconsax.pause_circle
                      : Iconsax.play_circle,
                  color: isActive ? Colors.black54 : rPrimaryColor,
                  onTap: () async {
                    if (isActive) {
                      await controller.pauseMedication(reminder);
                    } else {
                      await controller.resumeMedication(reminder);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ReminderActionSheet.showForMedication(
                context: context,
                reminder: reminder,
                controller: controller,
              ),
              icon: const Icon(Iconsax.more, size: 16),
              label: const Text('خيارات أكثر'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}