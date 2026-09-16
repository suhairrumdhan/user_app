import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../data/models/appointment_reminder_model.dart';
import '../views/reminder_details_page.dart';
import 'reminder_card.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentReminderModel reminder;
  final RemindersController controller;

  const AppointmentCard({
    super.key,
    required this.reminder,
    required this.controller,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rWarningColor = Color(0xFFFF9800);

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
            reminderType: 'appointment',
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
                      ? rWarningColor.withOpacity(0.10)
                      : Colors.grey.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Iconsax.calendar_1,
                  color: isActive ? rWarningColor : Colors.black45,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(reminder.appointmentDateTime),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'pause':
                      if (isActive) {
                        await controller.pauseAppointment(reminder);
                      } else {
                        await controller.resumeAppointment(reminder);
                      }
                      break;
                    case 'delete':
                      await controller.deleteAppointmentReminder(reminder);
                      break;
                    case 'details':
                      Get.to(
                        () => ReminderDetailsPage(
                          reminderId: reminder.id,
                          reminderType: 'appointment',
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (_) => [
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
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FBFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rPrimaryColor.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Iconsax.profile_2user,
                  title: 'المستفيد',
                  value: reminder.owner.name,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Iconsax.notification_bing,
                  title: 'التذكير قبل',
                  value: '${reminder.remindBeforeMinutes} دقيقة',
                ),
                if (reminder.location != null &&
                    reminder.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Iconsax.location,
                    title: 'المكان',
                    value: reminder.location!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y/$m/$d • $h:$min';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: rPrimaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
