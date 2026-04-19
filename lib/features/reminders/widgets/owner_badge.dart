import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../data/models/reminder_owner_embedded.dart';

class OwnerBadge extends StatelessWidget {
  final ReminderOwnerEmbedded owner;

  const OwnerBadge({
    super.key,
    required this.owner,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owner.type == 'self' ? Iconsax.profile_circle : Iconsax.people,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${owner.name} • ${owner.relation}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}