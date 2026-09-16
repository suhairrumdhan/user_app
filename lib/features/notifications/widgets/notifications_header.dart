import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';

class NotificationsHeader extends StatelessWidget {
  final int totalCount;
  final int unreadCount;
  final VoidCallback? onMarkAllAsRead;
  final bool isProcessing;

  const NotificationsHeader({
    super.key,
    required this.totalCount,
    required this.unreadCount,
    this.onMarkAllAsRead,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: SearchUiColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.notification_bing,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'الإشعارات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 7),
                      Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unreadCount > 0)
                IconButton(
                  tooltip: 'تعيين الكل كمقروء',
                  onPressed: isProcessing ? null : onMarkAllAsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.22)),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.10),
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Iconsax.tick_circle, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
