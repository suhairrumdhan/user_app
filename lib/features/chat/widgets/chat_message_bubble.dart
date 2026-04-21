import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;
  final Color primaryColor;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.primaryColor,
  });

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatTime(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final bool isMe = message.isMe;
    final Color bubbleColor =
    isMe ? primaryColor : const Color(0xFFFFFFFF);
    final Color textColor =
    isMe ? Colors.white : const Color(0xFF1F2937);
    final Color metaColor =
    isMe ? Colors.white70 : Colors.grey.shade600;
    final BorderRadius bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 5),
      bottomRight: Radius.circular(isMe ? 5 : 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: isMe
                    ? null
                    : Border.all(
                  color: const Color(0xFFE8EEF5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? primaryColor.withOpacity(0.16)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isMe ? 10 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: bubbleRadius,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    message.isImage || message.isFile ? 8 : 12,
                    message.isImage || message.isFile ? 8 : 9,
                    message.isImage || message.isFile ? 8 : 12,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.isImage && message.hasImage) ...[
                        GestureDetector(
                          onTap: () => _openUrl(message.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Image.network(
                                  message.imageUrl!,
                                  width: 230,
                                  height: 230,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 230,
                                    height: 170,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey[700],
                                      size: 28,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.28),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.open_in_full_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (message.text.trim().isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      if (message.isFile && message.hasFile) ...[
                        InkWell(
                          onTap: () => _openUrl(message.fileUrl!),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withOpacity(0.14)
                                  : const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(14),
                              border: isMe
                                  ? null
                                  : Border.all(
                                color: const Color(0xFFE7EDF5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.16)
                                        : primaryColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.insert_drive_file_rounded,
                                    color: isMe ? Colors.white : primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.displayFileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if ((message.fileExtension ?? '')
                                              .isNotEmpty)
                                            Text(
                                              '.${message.fileExtension}',
                                              style: TextStyle(
                                                color: metaColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (message.fileSizeBytes != null) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatFileSize(
                                                message.fileSizeBytes!,
                                              ),
                                              style: TextStyle(
                                                color: metaColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (message.text.trim().isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      if (message.text.trim().isNotEmpty)
                        Text(
                          message.text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            height: 1.38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Spacer(),
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10.3,
                              color: metaColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}