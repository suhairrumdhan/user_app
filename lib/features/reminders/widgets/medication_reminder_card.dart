import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../data/models/medication_reminder_model.dart';
import '../views/reminder_details_page.dart';
import 'reminder_card.dart';

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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isActive
                      ? rPrimaryColor.withOpacity(0.10)
                      : Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Iconsax.book,
                  color: isActive ? rPrimaryColor : rWarningColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.medicineName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.dosage?.trim().isNotEmpty == true
                          ? reminder.dosage!
                          : reminder.owner.name,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                  const PopupMenuItem(value: 'taken', child: Text('تم الأخذ')),
                  const PopupMenuItem(value: 'snooze', child: Text('تأجيل')),
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(isActive ? 'إيقاف مؤقت' : 'استئناف'),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('عرض التفاصيل'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: isActive
                  ? rPrimaryColor.withOpacity(0.08)
                  : rWarningColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.clock, color: rPrimaryColor, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reminder.times.join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  reminder.owner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: rPrimaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final busy = controller.isMedicationOperationInProgress(
              reminder.id,
            );
            return Row(
              children: [
                Expanded(
                  child: _MiniAction(
                    title: 'تم الأخذ',
                    icon: Iconsax.tick_circle,
                    color: rSuccessColor,
                    onTap: busy
                        ? null
                        : () => controller.markMedicationTaken(reminder),
                    busy: busy,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniAction(
                    title: 'تأجيل',
                    icon: Iconsax.timer_pause,
                    color: rWarningColor,
                    onTap: busy
                        ? null
                        : () => controller.snoozeMedication(reminder),
                    busy: busy,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniAction(
                    title: isActive ? 'إيقاف' : 'استئناف',
                    icon: isActive ? Iconsax.pause_circle : Iconsax.play_circle,
                    color: isActive ? Colors.black54 : rPrimaryColor,
                    onTap: busy
                        ? null
                        : () async {
                            if (isActive) {
                              await controller.pauseMedication(reminder);
                            } else {
                              await controller.resumeMedication(reminder);
                            }
                          },
                    busy: busy,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  const _MiniAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
