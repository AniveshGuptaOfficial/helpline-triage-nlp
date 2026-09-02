import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/conversation_store.dart';
import '../widgets/app_bottom_nav.dart';

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
  List<Conversation> _recent = [];

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
      // loadAll() already orders by updatedAt descending, so the first
      // few entries are the most recent conversations.
      _recent = all.take(3).toList();
      _isLoading = false;
    });
  }

  // Order matches the mockup legend: Medicine, Appointment, Emergency.
  List<({String label, int count, Color color})> get _segments => [
        (label: 'Medicine', count: _counts['Medicine Query'] ?? 0, color: kMedicine),
        (label: 'Appointment', count: _counts['Appointment'] ?? 0, color: kAppointment),
        (label: 'Emergency', count: _counts['Emergency'] ?? 0, color: kEmergency),
      ];

  Widget _donut() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(150, 150),
            painter: _DonutPainter(
              segments: _segments.map((s) => (value: s.count.toDouble(), color: s.color)).toList(),
              total: _total.toDouble(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_total',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Text('HELPLINES',
                  style: TextStyle(fontSize: 10, color: kNeutral, letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(({String label, int count, Color color}) s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('${s.label} (${s.count})', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _recentCaseTile(Conversation c) {
    final color = categoryColor(c.category);
    final dateLabel = _formatUpdatedAt(c.updatedAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(dateLabel, style: const TextStyle(fontSize: 11.5, color: kNeutral)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: categoryColorLight(c.category),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (c.category ?? 'Unknown').toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdatedAt(int millis) {
    if (millis == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';
    if (isToday) return 'Today, $time';
    if (isYesterday) return 'Yesterday, $time';
    return '${dt.day.toString().padLeft(2, '0')} ${_monthAbbr(dt.month)} ${dt.year}';
  }

  String _monthAbbr(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Triage Dashboard',
                style: TextStyle(
                    color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Overview of your cases',
                style: TextStyle(fontSize: 12, color: kNeutral)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kCardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Consultations',
                                style: TextStyle(fontSize: 13, color: kNeutral)),
                            const SizedBox(height: 4),
                            Text('$_total',
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: kPrimary, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kCardBorder),
                  ),
                  child: Row(
                    children: [
                      _donut(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _segments.map(_legendRow).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Recent Cases',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No conversations yet.', style: TextStyle(color: kNeutral)),
                    ),
                  )
                else
                  ..._recent.map(_recentCaseTile),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

/// Simple ring-chart painter - no chart package dependency needed for a
/// 3-segment donut. Draws each segment as an arc proportional to its share
/// of the total, leaving the untouched track color for an empty state.
class _DonutPainter extends CustomPainter {
  final List<({double value, Color color})> segments;
  final double total;

  _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = kDonutTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0) return;

    double startAngle = -3.14159265 / 2; // start at 12 o'clock
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * 3.14159265;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.total != total;
  }
}