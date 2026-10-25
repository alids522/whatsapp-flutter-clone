import 'package:flutter/material.dart';
import 'call_screen.dart';

/// Calls tab: a local demo call log (not a Supabase table in v1),
/// plus a demo call button. Real voice/video calling is NOT
/// implemented — the call screen says so on screen (see README).
class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  final List<String> _log = [];

  Future<void> _demoCall() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CallScreen(contactName: 'Demo contact'),
      ),
    );
    if (mounted) {
      setState(() => _log.insert(0, 'Demo call · just now'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Calls are a UI placeholder in v1 — no real voice/video '
            'call is placed. The log below is local to this device.',
            textAlign: TextAlign.center,
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          onPressed: _demoCall,
          icon: const Icon(Icons.call),
          label: const Text('Start demo call'),
        ),
        Expanded(
          child: _log.isEmpty
              ? const Center(child: Text('No calls yet.'))
              : ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.call)),
                    title: Text(_log[i]),
                    subtitle: const Text('Outgoing · demo'),
                  ),
                ),
        ),
      ],
    );
  }
}
