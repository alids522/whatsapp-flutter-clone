import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;

  @override
  void initState() {
    super.initState();
    AuthService.currentUsername().then((v) {
      if (mounted) setState(() => _username = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 28,
              child: Text(
                _username != null && _username!.isNotEmpty
                    ? _username![0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(_username ?? 'Loading…'),
            subtitle: const Text('Signed in with username + password'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About this app'),
            subtitle: Text(
              'WhatsApp-like chat v1. Real calls and end-to-end '
              'encryption are not implemented — see README.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService.signOut();
              // AuthGate switches back to the login screen.
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
