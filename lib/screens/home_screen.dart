import 'package:flutter/material.dart';
import '../models.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import 'calls_tab.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'settings_screen.dart';
import 'status_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<ChatSummary>>? _chatsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() =>
      setState(() => _chatsFuture = ChatService.fetchMyChats());

  Widget _chatsTab() {
    return FutureBuilder<List<ChatSummary>>(
      future: _chatsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'No chats yet.\nTap + to search a username and start chatting.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chat = chats[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF075E54),
                  child: Text(
                    chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(chat.title),
                subtitle: Text(
                  chat.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: chat.lastMessageAt == null
                    ? null
                    : Text(
                        formatTime(chat.lastMessageAt!),
                        style: const TextStyle(fontSize: 12),
                      ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat.id,
                        title: chat.title,
                        isGroup: chat.isGroup,
                      ),
                    ),
                  );
                  _refresh();
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF075E54),
          foregroundColor: Colors.white,
          title: const Text('ChatApp'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'CHATS'),
              Tab(text: 'UPDATES'),
              Tab(text: 'CALLS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _chatsTab(),
            const StatusTab(),
            const CallsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewChatScreen()),
            );
            _refresh();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
