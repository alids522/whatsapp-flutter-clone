import 'package:flutter/material.dart';
import '../models.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';

/// Updates / Status tab: post a text status, view other users'
/// statuses from the last 24 hours. Statuses live in Supabase.
class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final _controller = TextEditingController();
  Future<List<StatusItem>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = ChatService.fetchStatuses());

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ChatService.postStatus(text);
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Post a text status…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _post(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                onPressed: _post,
                child: const Text('Post'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<StatusItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(
                  child: Text('No statuses in the last 24 hours.'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          s.username.isNotEmpty
                              ? s.username[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(s.username),
                      subtitle: Text(s.text),
                      trailing: Text(
                        formatTime(s.createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
