// custom_bottom_navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../cons/icons.dart';

const Color inActiveIconColor = Color(0xFFB6B6B6);

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      onTap: onTap,
      currentIndex: currentIndex,
      showSelectedLabels: false,
      showUnselectedLabels: false,
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
              Color(0xFFFF7643),
              BlendMode.srcIn,
            ),
          ),
          label: "الرئيسية",
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.string(
            chatIcon,
            colorFilter: const ColorFilter.mode(
              inActiveIconColor,
              BlendMode.srcIn,
            ),
          ),
          activeIcon: SvgPicture.string(
            chatIcon,
            colorFilter: const ColorFilter.mode(
              Color(0xFFFF7643),
              BlendMode.srcIn,
            ),
          ),
          label: "وصفاتي",
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
              Color(0xFFFF7643),
              BlendMode.srcIn,
            ),
          ),
          label: "المفضلة",
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
              Color(0xFFFF7643),
              BlendMode.srcIn,
            ),
          ),
          label: "الملف الشخصي",
        ),
      ],
    );
  }
}