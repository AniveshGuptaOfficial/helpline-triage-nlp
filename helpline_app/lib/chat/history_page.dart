import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/conversation_store.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ConversationStore.loadAll();
    if (!mounted) return;
    setState(() {
      _conversations = all;
      _isLoading = false;
    });
  }

  Future<void> _confirmAndDelete(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text(
          'This will permanently delete "${conversation.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kEmergency),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ConversationStore.delete(conversation.id);
    if (!mounted) return;
    setState(() {
      _conversations.removeWhere((c) => c.id == conversation.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Conversations')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('No past conversations yet.'))
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _conversations[index];
                    final color = categoryColor(c.category);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Icon(categoryIcon(c.category),
                            color: Colors.white, size: 18),
                      ),
                      title: Text(c.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.category ?? 'Uncategorized'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: kNeutral),
                        tooltip: 'Delete conversation',
                        onPressed: () => _confirmAndDelete(c),
                      ),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
    );
  }
}