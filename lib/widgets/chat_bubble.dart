import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String status;
  final bool isDeleted;
  final String? imageUrl;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.status,
    this.isDeleted = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasText = message.isNotEmpty;

    Color bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    if (isMe) {
      if (isDeleted) {
        bubbleColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
      } else if (status == 'pending') {
        bubbleColor = isDark ? const Color(0xFF1A3A5C) : Colors.grey[200]!;
      } else if (status == 'failed') {
        bubbleColor = isDark ? Colors.red[900]! : Colors.red[100]!;
      }
    } else {
      if (isDeleted) {
        bubbleColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image part
            if (hasImage)
              GestureDetector(
                onTap: () => _openFullscreen(context, imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: (!hasText)
                        ? (isMe
                            ? const Radius.circular(16)
                            : const Radius.circular(0))
                        : Radius.zero,
                    bottomRight: (!hasText)
                        ? (isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(16))
                        : Radius.zero,
                  ),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: Colors.green,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            // Text + timestamp
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: hasImage && hasText ? 6 : (hasImage ? 0 : 8),
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText || isDeleted)
                    Text(
                      isDeleted ? '🚫 This message was deleted' : message,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                        color: isDeleted
                            ? Colors.grey
                            : (status == 'failed'
                                ? (isDark ? Colors.red[200] : Colors.red[900])
                                : (isDark ? Colors.white : Colors.black87)),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      if (isMe && !isDeleted) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(isDark),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }

  Widget _buildStatusIcon(bool isDark) {
    IconData iconData = Icons.access_time;
    Color iconColor = isDark ? Colors.white60 : Colors.black54;

    if (status == 'read') {
      iconData = Icons.done_all;
      iconColor = isDark ? Colors.greenAccent : Colors.blue;
    } else if (status == 'sent') {
      iconData = Icons.done;
    } else if (status == 'pending') {
      iconData = Icons.access_time_rounded;
      iconColor = isDark ? Colors.white38 : Colors.grey;
    } else if (status == 'failed') {
      iconData = Icons.error_outline;
      iconColor = isDark ? Colors.redAccent : Colors.red;
    }

    return Icon(iconData, size: 14, color: iconColor);
  }
}
