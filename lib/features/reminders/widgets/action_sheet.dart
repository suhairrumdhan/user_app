import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../data/models/appointment_reminder_model.dart';
import '../data/models/medication_reminder_model.dart';

class ReminderActionSheet extends StatelessWidget {
  final String title;
  final List<_ActionItem> actions;

  const ReminderActionSheet({
    super.key,
    required this.title,
    required this.actions,
  });

  static Future<void> showForMedication({
    required BuildContext context,
    required MedicationReminderModel reminder,
    required RemindersController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ReminderActionSheet(
          title: reminder.medicineName,
          actions: [
            _ActionItem(
              icon: Iconsax.tick_circle,
              color: const Color(0xFF4CAF50),
              title: 'تم الأخذ',
              onTap: () async {
                Navigator.pop(context);
                await controller.markMedicationTaken(reminder);
              },
            ),
            _ActionItem(
              icon: Iconsax.timer_pause,
              color: const Color(0xFFFF9800),
              title: 'تأجيل 10 دقائق',
              onTap: () async {
                Navigator.pop(context);
                await controller.snoozeMedication(reminder);
              },
            ),
            _ActionItem(
              icon: Iconsax.close_circle,
              color: const Color(0xFFE57373),
              title: 'تخطي',
              onTap: () async {
                Navigator.pop(context);
                await controller.skipMedication(reminder);
              },
            ),
            _ActionItem(
              icon: reminder.status == 'active'
                  ? Iconsax.pause_circle
                  : Iconsax.play_circle,
              color: const Color(0xFF5EABD6),
              title: reminder.status == 'active' ? 'إيقاف مؤقت' : 'استئناف',
              onTap: () async {
                Navigator.pop(context);
                if (reminder.status == 'active') {
                  await controller.pauseMedication(reminder);
                } else {
                  await controller.resumeMedication(reminder);
                }
              },
            ),
            _ActionItem(
              icon: Iconsax.trash,
              color: Colors.red,
              title: 'حذف التذكير',
              onTap: () async {
                Navigator.pop(context);
                await controller.deleteMedicationReminder(reminder);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showForAppointment({
    required BuildContext context,
    required AppointmentReminderModel reminder,
    required RemindersController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ReminderActionSheet(
          title: reminder.title,
          actions: [
            _ActionItem(
              icon: reminder.status == 'active'
                  ? Iconsax.pause_circle
                  : Iconsax.play_circle,
              color: const Color(0xFF5EABD6),
              title: reminder.status == 'active' ? 'إيقاف مؤقت' : 'استئناف',
              onTap: () async {
                Navigator.pop(context);
                if (reminder.status == 'active') {
                  await controller.pauseAppointment(reminder);
                } else {
                  await controller.resumeAppointment(reminder);
                }
              },
            ),
            _ActionItem(
              icon: Iconsax.trash,
              color: Colors.red,
              title: 'حذف الموعد',
              onTap: () async {
                Navigator.pop(context);
                await controller.deleteAppointmentReminder(reminder);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 18),
              ...actions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: item.color.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(item.icon, color: item.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                          Icon(
                            Iconsax.arrow_left_2,
                            color: item.color,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
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

class _ActionItem {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });
}
