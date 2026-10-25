import 'package:flutter/material.dart';
import '../models.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Search users by username, start a 1-1 chat, or create a group chat
/// with several members. Groups use the same chats/chat_members/
/// messages model as 1-1 chats — they are not local-only.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _search = TextEditingController();
  final _groupName = TextEditingController();
  List<Profile> _results = [];
  final Set<String> _selected = {};
  bool _searching = false;

  Future<void> _runSearch() async {
    setState(() => _searching = true);
    try {
      _results = await ChatService.searchUsers(_search.text);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openDirect(Profile other) async {
    final chatId = await ChatService.getOrCreateDirectChat(other.id);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, title: other.username),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _groupName.text.trim();
    if (name.isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a group name and pick at least one member.'),
        ),
      );
      return;
    }
    final chatId =
        await ChatService.createGroupChat(name, _selected.toList());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(chatId: chatId, title: name, isGroup: true),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New chat'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _runSearch,
                ),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _groupName,
              decoration: const InputDecoration(
                hintText: 'Group name (for a group chat)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _createGroup,
                  child: Text('Create group (${_selected.length} members)'),
                ),
              ),
            ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'Search for a username, tap a user for a 1-1 chat,\n'
                          'or tick users and create a group.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final user = _results[i];
                          final checked = _selected.contains(user.id);
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(user.username),
                            trailing: Checkbox(
                              value: checked,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(user.id);
                                } else {
                                  _selected.remove(user.id);
                                }
                              }),
                            ),
                            onTap: () => _openDirect(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
