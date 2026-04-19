import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class TimeChip extends StatelessWidget {
  final String time;
  final VoidCallback? onDelete;

  const TimeChip({
    super.key,
    required this.time,
    this.onDelete,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        right: 12,
        left: onDelete != null ? 8 : 12,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rPrimaryColor.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.clock, size: 15, color: rPrimaryColor),
          const SizedBox(width: 6),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}