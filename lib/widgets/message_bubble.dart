import 'package:flutter/material.dart';
import '../models.dart';

String formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// WhatsApp-style bubble: green for mine, white for theirs,
/// with read ticks (✓ sent, ✓✓ delivered, blue ✓✓ read).
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const MessageBubble({super.key, required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        mine ? const Color(0xFFDCF8C6) : Colors.white;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 0),
            bottomRight: Radius.circular(mine ? 0 : 12),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.imageUrl!,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Text(
                    'Image could not be loaded.',
                  ),
                ),
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Text(message.body!, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 15,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
