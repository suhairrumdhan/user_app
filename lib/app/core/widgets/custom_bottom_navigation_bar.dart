// custom_bottom_navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/icons.dart';
import 'package:user_application/features/chat/services/chat_service.dart';
const Color inActiveIconColor = Color(0xFFB6B6B6);

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  final ChatService _chatService = ChatService();
   CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

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
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return BottomNavigationBar(
          onTap: onTap,
          currentIndex: currentIndex,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: SvgPicture.string(
                homeIconSvg,
                colorFilter: const ColorFilter.mode(
                  inActiveIconColor,
                  BlendMode.srcIn,
                ),
              ),
              activeIcon: SvgPicture.string(
                homeIconSvg,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF5EABD6),
                  BlendMode.srcIn,
                ),
              ),
              label: "الرئيسية",
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(
                count: unreadCount,
                icon: SvgPicture.string(
                  chatIcon,
                  colorFilter: const ColorFilter.mode(
                    inActiveIconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              activeIcon: _buildBadgeIcon(
                count: unreadCount,
                icon: SvgPicture.string(
                  chatIcon,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF5EABD6),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              label: "الدردشات",
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.string(
                heartIcon,
                colorFilter: const ColorFilter.mode(
                  inActiveIconColor,
                  BlendMode.srcIn,
                ),
              ),
              activeIcon: SvgPicture.string(
                heartIcon,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF5EABD6),
                  BlendMode.srcIn,
                ),
              ),
              label: "المفضلة",
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.string(
                notificationIcon,
                colorFilter: const ColorFilter.mode(
                  inActiveIconColor,
                  BlendMode.srcIn,
                ),
              ),
              activeIcon: SvgPicture.string(
                notificationIcon,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF5EABD6),
                  BlendMode.srcIn,
                ),
              ),
              label: "الإشعارات",
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.string(
                userIcon,
                colorFilter: const ColorFilter.mode(
                  inActiveIconColor,
                  BlendMode.srcIn,
                ),
              ),
              activeIcon: SvgPicture.string(
                userIcon,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF5EABD6),
                  BlendMode.srcIn,
                ),
              ),
              label: "الملف الشخصي",
            ),
          ],
        );
      },
    );
  }
}