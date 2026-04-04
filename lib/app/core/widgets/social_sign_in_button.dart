import 'package:flutter/material.dart';

class SocialSignInButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final Color color;

  const SocialSignInButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        splashRadius: 24,
      ),
    );
  }
}
