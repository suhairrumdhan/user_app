// custom_bottom_navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/icons.dart';
import 'package:user_application/features/chat/services/chat_service.dart';
import 'package:user_application/features/notifications/services/notifications_service.dart';

const Color inActiveIconColor = Color(0xFFB6B6B6);

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  final ChatService _chatService = ChatService();
  final NotificationsService _notificationsService = NotificationsService();
  CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  Widget _buildAnimatedIcon({
    required String svgString,
    required bool isActive,
    required int badgeCount,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isActive ? 28 : 24,
      height: isActive ? 28 : 24,
      child: SvgPicture.string(
        svgString,
        colorFilter: ColorFilter.mode(
          isActive ? const Color(0xFF5EABD6) : inActiveIconColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildBadgeIcon({
    required Widget icon,
    required int count,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _chatService.getUnreadCountStream(),
      builder: (context, chatSnapshot) {
        final chatUnreadCount = chatSnapshot.data ?? 0;

        return StreamBuilder<int>(
          stream: _notificationsService.getUnreadCountStream(),
          builder: (context, notificationsSnapshot) {
            final notificationsUnreadCount = notificationsSnapshot.data ?? 0;

            return BottomNavigationBar(
              onTap: onTap,
              currentIndex: currentIndex,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: _buildAnimatedIcon(
                    svgString: homeIconSvg,
                    isActive: false,
                    badgeCount: 0,
                  ),
                  activeIcon: _buildAnimatedIcon(
                    svgString: homeIconSvg,
                    isActive: true,
                    badgeCount: 0,
                  ),
                  label: "الرئيسية",
                ),
                BottomNavigationBarItem(
                  icon: _buildBadgeIcon(
                    count: chatUnreadCount,
                    icon: _buildAnimatedIcon(
                      svgString: chatIcon,
                      isActive: false,
                      badgeCount: chatUnreadCount,
                    ),
                  ),
                  activeIcon: _buildBadgeIcon(
                    count: chatUnreadCount,
                    icon: _buildAnimatedIcon(
                      svgString: chatIcon,
                      isActive: true,
                      badgeCount: chatUnreadCount,
                    ),
                  ),
                  label: "الدردشات",
                ),
                BottomNavigationBarItem(
                  icon: _buildAnimatedIcon(
                    svgString: ordersIcon,
                    isActive: false,
                    badgeCount: 0,
                  ),
                  activeIcon: _buildAnimatedIcon(
                    svgString: ordersIcon,
                    isActive: true,
                    badgeCount: 0,
                  ),
                  label: "الطلبات",
                ),
                BottomNavigationBarItem(
                  icon: _buildBadgeIcon(
                    count: notificationsUnreadCount,
                    icon: _buildAnimatedIcon(
                      svgString: notificationIcon,
                      isActive: false,
                      badgeCount: notificationsUnreadCount,
                    ),
                  ),
                  activeIcon: _buildBadgeIcon(
                    count: notificationsUnreadCount,
                    icon: _buildAnimatedIcon(
                      svgString: notificationIcon,
                      isActive: true,
                      badgeCount: notificationsUnreadCount,
                    ),
                  ),
                  label: "الإشعارات",
                ),
                BottomNavigationBarItem(
                  icon: _buildAnimatedIcon(
                    svgString: userIcon,
                    isActive: false,
                    badgeCount: 0,
                  ),
                  activeIcon: _buildAnimatedIcon(
                    svgString: userIcon,
                    isActive: true,
                    badgeCount: 0,
                  ),
                  label: "الملف الشخصي",
                ),
              ],
            );
          },
        );
      },
    );
  }
}
_OrderNotificationContent buildOrderStatusNotificationContent({
  required String status,
  required String statusLabel,
  required String beneficiaryName,
  String? note,
}) {
  switch (status) {
    case 'reviewing':
      return _OrderNotificationContent(
        title: 'الطلب قيد المراجعة',
        body: 'بدأت الصيدلية مراجعة طلب $beneficiaryName.',
      );

    case 'confirmed':
      return _OrderNotificationContent(
        title: 'تم تأكيد الطلب',
        body: 'تم تأكيد طلب $beneficiaryName.',
      );

    case 'partiallyConfirmed':
      return _OrderNotificationContent(
        title: 'الطلب متوفر جزئيًا',
        body: note != null && note.trim().isNotEmpty
            ? 'بعض عناصر طلب $beneficiaryName متوفرة. ملاحظة: ${note.trim()}'
            : 'بعض عناصر طلب $beneficiaryName متوفرة.',
      );

    case 'rejected':
      return _OrderNotificationContent(
        title: 'تم رفض الطلب',
        body: note != null && note.trim().isNotEmpty
            ? 'تم رفض طلب $beneficiaryName. السبب: ${note.trim()}'
            : 'تم رفض طلب $beneficiaryName.',
      );

    case 'ready':
      return _OrderNotificationContent(
        title: 'الطلب جاهز',
        body: 'طلب $beneficiaryName أصبح جاهزًا للاستلام.',
      );

    case 'completed':
      return _OrderNotificationContent(
        title: 'اكتمل الطلب',
        body: 'تم إكمال طلب $beneficiaryName بنجاح.',
      );

    case 'cancelled':
      return _OrderNotificationContent(
        title: 'تم إلغاء الطلب',
        body: note != null && note.trim().isNotEmpty
            ? 'تم إلغاء طلب $beneficiaryName. السبب: ${note.trim()}'
            : 'تم إلغاء طلب $beneficiaryName.',
      );

    default:
      return _OrderNotificationContent(
        title: 'تم تحديث الطلب',
        body: 'تم تحديث حالة طلب $beneficiaryName إلى $statusLabel.',
      );
  }
}

class _OrderNotificationContent {
  final String title;
  final String body;

  const _OrderNotificationContent({
    required this.title,
    required this.body,
  });
}