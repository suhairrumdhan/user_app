import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../models/app_notification_model.dart';
import '../models/notification_type.dart';

class NotificationCard extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ui = _NotificationUiData.fromNotification(notification);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onDelete();
        // The live query removes the card after a successful write. A failed
        // delete must not leave a dismissed widget mounted in the list.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.trash, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'حذف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.white : ui.cardTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notification.isRead
                    ? Colors.grey.shade200
                    : ui.baseColor.withOpacity(0.22),
                width: notification.isRead ? 1.0 : 1.25,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusStripe(
                  color: notification.isRead
                      ? Colors.grey.shade300
                      : ui.baseColor,
                ),
                const SizedBox(width: 8),
                _NotificationLeading(ui: ui, imageUrl: notification.imageUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopRow(
                        title: notification.title,
                        timeText: _formatTime(notification.createdAt),
                        isRead: notification.isRead,
                        color: ui.baseColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _BottomMetaRow(
                        sourceLabel: _buildSourceLabel(notification),
                        secondaryLabel: _buildSecondaryLabel(notification),
                        color: ui.metaColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${value.day}/${value.month}';
  }

  static String _buildSourceLabel(AppNotificationModel notification) {
    if ((notification.pharmacyName ?? '').trim().isNotEmpty) {
      return notification.pharmacyName!;
    }

    switch (notification.type) {
      case AppNotificationType.orderUpdate:
        return 'الطلبات';
      case AppNotificationType.pharmacyMessage:
        return 'الصيدلية';
      case AppNotificationType.adminMessage:
        return 'الإدارة';
      case AppNotificationType.promotion:
        return 'العروض';
      case AppNotificationType.medicineReminder:
        return 'تنبيه دواء';
      case AppNotificationType.appointmentReminder:
        return 'موعد';
      case AppNotificationType.system:
        return 'النظام';
    }
  }

  static String? _buildSecondaryLabel(AppNotificationModel notification) {
    final beneficiary = notification.beneficiaryName?.trim();
    final status = notification.extraData['status']
        ?.toString()
        .trim()
        .toLowerCase();
    final statusLabel = notification.extraData['statusLabel']
        ?.toString()
        .trim();
    final canAdd = notification.extraData['canAddToMedicationHistory'] == true;

    if (notification.type == AppNotificationType.orderUpdate) {
      final isDelivered =
          status == 'delivered' ||
          status == 'completed_delivery' ||
          statusLabel == 'تم الاستلام' ||
          statusLabel == 'تم التسليم';

      if (isDelivered || canAdd) {
        if (beneficiary != null && beneficiary.isNotEmpty) {
          return '$beneficiary • إضافة إلى الأدوية السابقة';
        }
        return 'إضافة إلى الأدوية السابقة';
      }

      if (beneficiary != null && beneficiary.isNotEmpty) {
        return beneficiary;
      }

      if (statusLabel != null && statusLabel.isNotEmpty) {
        return statusLabel;
      }

      return null;
    }

    if (notification.type == AppNotificationType.medicineReminder ||
        notification.type == AppNotificationType.appointmentReminder) {
      if (beneficiary != null && beneficiary.isNotEmpty) {
        return beneficiary;
      }
    }

    return null;
  }
}

class _StatusStripe extends StatelessWidget {
  final Color color;

  const _StatusStripe({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _NotificationLeading extends StatelessWidget {
  final _NotificationUiData ui;
  final String? imageUrl;

  const _NotificationLeading({required this.ui, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: [ui.color1, ui.color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasImage ? Colors.white : null,
        borderRadius: BorderRadius.circular(12),
        border: hasImage
            ? Border.all(color: Colors.grey.shade200, width: 1)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade100,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ui.baseColor,
                      ),
                    ),
                  );
                },
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ui.color1, ui.color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(ui.icon, color: Colors.white, size: 19),
    );
  }
}

class _TopRow extends StatelessWidget {
  final String title;
  final String timeText;
  final bool isRead;
  final Color color;

  const _TopRow({
    required this.title,
    required this.timeText,
    required this.isRead,
    required this.color,
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
              fontSize: 13.2,
              fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          timeText,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!isRead) ...[
          const SizedBox(width: 5),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomMetaRow extends StatelessWidget {
  final String sourceLabel;
  final String? secondaryLabel;
  final Color color;

  const _BottomMetaRow({
    required this.sourceLabel,
    required this.secondaryLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            sourceLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (secondaryLabel != null && secondaryLabel!.trim().isNotEmpty) ...[
          Text(
            '  •  ',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              secondaryLabel!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationUiData {
  final IconData icon;
  final Color color1;
  final Color color2;
  final Color baseColor;
  final Color cardTint;
  final Color metaColor;

  const _NotificationUiData({
    required this.icon,
    required this.color1,
    required this.color2,
    required this.baseColor,
    required this.cardTint,
    required this.metaColor,
  });

  factory _NotificationUiData.fromNotification(
    AppNotificationModel notification,
  ) {
    final status = notification.extraData['status']?.toString();

    if (notification.type == AppNotificationType.orderUpdate) {
      switch (status) {
        case 'ready':
          return const _NotificationUiData(
            icon: Iconsax.box_tick,
            color1: Color(0xFF16A34A),
            color2: Color(0xFF4ADE80),
            baseColor: Color(0xFF16A34A),
            cardTint: Color(0xFFF3FFF7),
            metaColor: Color(0xFF15803D),
          );

        case 'confirmedReserved':
        case 'confirmed':
          return const _NotificationUiData(
            icon: Iconsax.tick_circle,
            color1: Color(0xFF0F766E),
            color2: Color(0xFF2DD4BF),
            baseColor: Color(0xFF0F766E),
            cardTint: Color(0xFFF2FFFD),
            metaColor: Color(0xFF0F766E),
          );

        case 'partialOfferPending':
        case 'partiallyConfirmed':
          return const _NotificationUiData(
            icon: Iconsax.warning_2,
            color1: Color(0xFFEA580C),
            color2: Color(0xFFFB923C),
            baseColor: Color(0xFFEA580C),
            cardTint: Color(0xFFFFF7ED),
            metaColor: Color(0xFFC2410C),
          );

        case 'underReview':
        case 'reviewing':
          return const _NotificationUiData(
            icon: Iconsax.search_status,
            color1: Color(0xFF2563EB),
            color2: Color(0xFF60A5FA),
            baseColor: Color(0xFF2563EB),
            cardTint: Color(0xFFF4F8FF),
            metaColor: Color(0xFF1D4ED8),
          );

        case 'rejected':
        case 'cancelled':
        case 'notCollected':
          return const _NotificationUiData(
            icon: Iconsax.close_circle,
            color1: Color(0xFFDC2626),
            color2: Color(0xFFF87171),
            baseColor: Color(0xFFDC2626),
            cardTint: Color(0xFFFFF5F5),
            metaColor: Color(0xFFB91C1C),
          );

        case 'preparing':
          return const _NotificationUiData(
            icon: Iconsax.box,
            color1: Color(0xFF7C3AED),
            color2: Color(0xFFA78BFA),
            baseColor: Color(0xFF7C3AED),
            cardTint: Color(0xFFF7F2FF),
            metaColor: Color(0xFF6D28D9),
          );

        case 'completed':
          return const _NotificationUiData(
            icon: Iconsax.verify,
            color1: Color(0xFF475569),
            color2: Color(0xFF94A3B8),
            baseColor: Color(0xFF475569),
            cardTint: Color(0xFFF8FAFC),
            metaColor: Color(0xFF475569),
          );
      }
    }

    switch (notification.type) {
      case AppNotificationType.orderUpdate:
        return _NotificationUiData(
          icon: Iconsax.box,
          color1: SearchUiColors.primary,
          color2: SearchUiColors.secondary,
          baseColor: SearchUiColors.primary,
          cardTint: SearchUiColors.primary.withOpacity(0.04),
          metaColor: SearchUiColors.primary,
        );

      case AppNotificationType.pharmacyMessage:
        return const _NotificationUiData(
          icon: Iconsax.messages_2,
          color1: Color(0xFF2563EB),
          color2: Color(0xFF60A5FA),
          baseColor: Color(0xFF2563EB),
          cardTint: Color(0xFFF4F8FF),
          metaColor: Color(0xFF1D4ED8),
        );

      case AppNotificationType.adminMessage:
        return const _NotificationUiData(
          icon: Iconsax.shield_tick,
          color1: Color(0xFF4F46E5),
          color2: Color(0xFF818CF8),
          baseColor: Color(0xFF4F46E5),
          cardTint: Color(0xFFF5F3FF),
          metaColor: Color(0xFF4338CA),
        );

      case AppNotificationType.promotion:
        return const _NotificationUiData(
          icon: Iconsax.discount_shape,
          color1: Color(0xFFF59E0B),
          color2: Color(0xFFFBBF24),
          baseColor: Color(0xFFF59E0B),
          cardTint: Color(0xFFFFFBEB),
          metaColor: Color(0xFFD97706),
        );

      case AppNotificationType.medicineReminder:
        return const _NotificationUiData(
          icon: Iconsax.timer_1,
          color1: Color(0xFF059669),
          color2: Color(0xFF34D399),
          baseColor: Color(0xFF059669),
          cardTint: Color(0xFFF0FDF4),
          metaColor: Color(0xFF047857),
        );

      case AppNotificationType.appointmentReminder:
        return const _NotificationUiData(
          icon: Iconsax.calendar_1,
          color1: Color(0xFF7C3AED),
          color2: Color(0xFFA78BFA),
          baseColor: Color(0xFF7C3AED),
          cardTint: Color(0xFFF7F2FF),
          metaColor: Color(0xFF6D28D9),
        );

      case AppNotificationType.system:
        return const _NotificationUiData(
          icon: Iconsax.notification_bing,
          color1: Color(0xFF64748B),
          color2: Color(0xFF94A3B8),
          baseColor: Color(0xFF64748B),
          cardTint: Color(0xFFF8FAFC),
          metaColor: Color(0xFF475569),
        );
    }
  }
}
