import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/conversation_store.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isLoading = true;
  int _total = 0;
  Map<String, int> _counts = {
    'Emergency': 0,
    'Medicine Query': 0,
    'Appointment': 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ConversationStore.loadAll();
    final counts = {'Emergency': 0, 'Medicine Query': 0, 'Appointment': 0};
    for (final c in all) {
      if (c.category != null && counts.containsKey(c.category)) {
        counts[c.category!] = counts[c.category]! + 1;
      }
    }
    if (!mounted) return;
    setState(() {
      _total = all.length;
      _counts = counts;
      _isLoading = false;
    });
  }

  Widget _statCard(String label, int count) {
    final color = categoryColor(label);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(categoryIcon(label), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Conversation Stats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Total conversations: $_total',
                    style: const TextStyle(fontSize: 16, color: kNeutral),
                  ),
                ),
                const SizedBox(height: 12),
                _statCard('Emergency', _counts['Emergency'] ?? 0),
                _statCard('Medicine Query', _counts['Medicine Query'] ?? 0),
                _statCard('Appointment', _counts['Appointment'] ?? 0),
              ],
            ),
    );
  }
}