import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models.dart';

/// Supabase-backed chat data layer. Nothing here is local-only:
/// chats, members, messages and statuses all live in Supabase tables
/// (see supabase_schema.sql), and messages arrive via Realtime.
class ChatService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String get _myId => _client.auth.currentUser!.id;

  // ---------- users ----------

  static Future<List<Profile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .ilike('username', '%$q%')
        .neq('id', _myId)
        .limit(20);
    return (rows as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Profile?> profileById(String id) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  // ---------- chats ----------

  static Future<List<ChatSummary>> fetchMyChats() async {
    final memberships = await _client
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', _myId);
    final chatIds = (memberships as List)
        .map((e) => (e as Map<String, dynamic>)['chat_id'] as String)
        .toList();
    if (chatIds.isEmpty) return [];

    final chats = await _client
        .from('chats')
        .select('id, name, is_group')
        .inFilter('id', chatIds)
        .order('created_at', ascending: false);

    final result = <ChatSummary>[];
    for (final c in chats as List) {
      final chat = c as Map<String, dynamic>;
      final chatId = chat['id'] as String;
      final isGroup = chat['is_group'] as bool? ?? false;

      String title = chat['name'] as String? ?? '';
      if (!isGroup) {
        // Direct chat title = the other member's username.
        final members = await _client
            .from('chat_members')
            .select('user_id')
            .eq('chat_id', chatId)
            .neq('user_id', _myId)
            .limit(1);
        if (members.isNotEmpty) {
          final otherId = members.first['user_id'] as String;
          final other = await profileById(otherId);
          if (other != null) title = other.username;
        }
      }

      final last = await _client
          .from('messages')
          .select('body, image_url, sender_id, is_read, created_at')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      String? lastText;
      bool mine = false;
      bool read = true;
      DateTime? lastAt;
      if (last != null) {
        lastText = (last['image_url'] as String?) != null
            ? '📷 Photo'
            : last['body'] as String?;
        mine = last['sender_id'] == _myId;
        read = last['is_read'] as bool? ?? false;
        lastAt = DateTime.tryParse(last['created_at'] as String? ?? '');
      }

      result.add(ChatSummary(
        id: chatId,
        title: title.isEmpty ? 'Chat' : title,
        isGroup: isGroup,
        lastMessage: lastText,
        lastMessageAt: lastAt,
        lastMessageMine: mine,
        lastMessageRead: read,
      ));
    }

    result.sort((a, b) {
      final at = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return result;
  }

  /// Find an existing 1-1 chat with [otherId], or create one.
  static Future<String> getOrCreateDirectChat(String otherId) async {
    final mine = await _client
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', _myId);
    final myChatIds = (mine as List)
        .map((e) => (e as Map<String, dynamic>)['chat_id'] as String)
        .toList();
    if (myChatIds.isNotEmpty) {
      final shared = await _client
          .from('chat_members')
          .select('chat_id')
          .eq('user_id', otherId)
          .inFilter('chat_id', myChatIds);
      for (final m in shared as List) {
        final chatId = (m as Map<String, dynamic>)['chat_id'] as String;
        final chat = await _client
            .from('chats')
            .select('is_group')
            .eq('id', chatId)
            .maybeSingle();
        if (chat != null && (chat['is_group'] as bool? ?? false) == false) {
          return chatId;
        }
      }
    }
    final chat = await _client
        .from('chats')
        .insert({'is_group': false, 'created_by': _myId})
        .select('id')
        .single();
    final chatId = chat['id'] as String;
    await _client.from('chat_members').insert([
      {'chat_id': chatId, 'user_id': _myId},
      {'chat_id': chatId, 'user_id': otherId},
    ]);
    return chatId;
  }

  static Future<String> createGroupChat(
    String name,
    List<String> memberIds,
  ) async {
    final chat = await _client
        .from('chats')
        .insert({'name': name, 'is_group': true, 'created_by': _myId})
        .select('id')
        .single();
    final chatId = chat['id'] as String;
    final members = <String>{_myId, ...memberIds};
    await _client.from('chat_members').insert(
      members.map((id) => {'chat_id': chatId, 'user_id': id}).toList(),
    );
    return chatId;
  }

  // ---------- messages ----------

  static Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((rows) =>
            rows.map((e) => ChatMessage.fromJson(e)).toList());
  }

  static Future<void> markAsRead(String chatId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', chatId)
        .neq('sender_id', _myId)
        .eq('is_read', false);
  }

  static Future<void> sendMessage(
    String chatId, {
    String? body,
    String? imageUrl,
  }) async {
    final text = body?.trim();
    if ((text == null || text.isEmpty) && imageUrl == null) return;
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _myId,
      'body': text,
      'image_url': imageUrl,
    });
  }

  /// Pick an image, upload to the `chat-media` bucket, return its public URL.
  /// Throws a clear error when the bucket does not exist yet — callers
  /// surface that to the user instead of sending a fake image message.
  static Future<String> uploadImage(XFile file) async {
    final bytes = await File(file.path).readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$_myId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _client.storage
          .from(AppConfig.storageBucket)
          .uploadBinary(path, bytes);
    } on StorageException catch (e) {
      throw Exception(
        'Media upload failed (${e.message}). Create the '
        "'${AppConfig.storageBucket}' storage bucket in Supabase "
        'Storage, then try again.',
      );
    }
    return _client.storage.from(AppConfig.storageBucket).getPublicUrl(path);
  }

  // ---------- statuses ----------

  static Future<List<StatusItem>> fetchStatuses() async {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final rows = await _client
        .from('statuses')
        .select('id, user_id, text, created_at')
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(50);
    final result = <StatusItem>[];
    for (final r in rows as List) {
      final map = r as Map<String, dynamic>;
      final profile = await profileById(map['user_id'] as String);
      result.add(StatusItem.fromJson(map, profile?.username ?? 'Unknown'));
    }
    return result;
  }

  static Future<void> postStatus(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _client.from('statuses').insert({
      'user_id': _myId,
      'text': t,
    });
  }
}
