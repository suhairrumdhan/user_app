import 'package:flutter/material.dart';

class ProfileMenuCard extends StatefulWidget {
  const ProfileMenuCard({
    super.key,
    required this.title,
    required this.subTitle,
    required this.icon,
    this.onTap,
    this.expandableChild,
  });

  final String title, subTitle;
  final IconData icon;
  final VoidCallback? onTap; // التصرف عند الضغط
  final Widget? expandableChild; // المحتوى الإضافي عند التوسع

  @override
  State<ProfileMenuCard> createState() => _ProfileMenuCardState();
}

class _ProfileMenuCardState extends State<ProfileMenuCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _handleTap() {
    if (widget.expandableChild != null) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5EABD6);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 22, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.expandableChild != null)
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0, // يدور السهم 180°
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: Colors.black.withOpacity(0.4),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? SizedBox(
                  width: double.infinity,
                  height: 300, // مثلا تحدد ارتفاع مناسب للفورم
                  child: widget.expandableChild,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
