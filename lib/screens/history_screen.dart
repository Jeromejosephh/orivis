//history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/logging_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<Map<String, dynamic>> history = []; //Replace with actual history data source
  String _dateFilter = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // TODO: Load history from the appropriate source
    setState(() {});
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    //Filter items based on date and search criteria
    return items.where((item) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['date']);
      bool matchesDate = _dateFilter == 'all' ||
          (_dateFilter == 'today' && isSameDay(date, DateTime.now())) ||
          (_dateFilter == '7d' && date.isAfter(DateTime.now().subtract(Duration(days: 7)))) ||
          (_dateFilter == 'custom' && _customStart != null && _customEnd != null && date.isAfter(_customStart!) && date.isBefore(_customEnd!));
      return matchesDate;
    }).toList();
  }

  Map<String, dynamic> _getFilteredStats(List<Map<String, dynamic>> items) {
    int okCount = 0, defectCount = 0;
    for (final item in items) {
      final isOk = (item['label'] ?? '').toString().toUpperCase() == 'OK';
      if (isOk) {
        okCount++;
      } else {
        defectCount++;
      }
    }

    String periodLabel;
    if (_dateFilter == 'all') {
      periodLabel = 'All';
    } else if (_dateFilter == 'today') {
      periodLabel = 'Today';
    } else if (_dateFilter == '7d') {
      periodLabel = '7d';
    } else if (_dateFilter == 'custom' && _customStart != null && _customEnd != null) {
      periodLabel = '${_customStart!.month}/${_customStart!.day}–${_customEnd!.month}/${_customEnd!.day}';
    } else {
      periodLabel = 'Filtered';
    }

    return {'ok': okCount, 'defect': defectCount, 'label': periodLabel};
  }

  @override
  Widget build(BuildContext ctx) {
    final filtered = _filtered(history);
    final stats = _getFilteredStats(filtered);
    final okCount = stats['ok'] as int;
    final defectCount = stats['defect'] as int;
    final periodLabel = stats['label'] as String;
    final total = okCount + defectCount;
    final okRate = total > 0 ? (okCount / total * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: Column(
        children: [
          // Filter and stats display
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date filter buttons
                Row(
                  children: [
                    _filterButton('All', () { setState(() { _dateFilter = 'all'; }); }),
                    const SizedBox(width: 8),
                    _filterButton('Today', () { setState(() { _dateFilter = 'today'; }); }),
                    const SizedBox(width: 8),
                    _filterButton('7d', () { setState(() { _dateFilter = '7d'; }); }),
                    const SizedBox(width: 8),
                    // Custom date range button
                    ElevatedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final start = await showDatePicker(
                          context: ctx,
                          initialDate: _customStart ?? now,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (start == null) return;
                        final end = await showDatePicker(
                          context: ctx,
                          initialDate: _customEnd ?? now,
                          firstDate: start,
                          lastDate: DateTime.now(),
                        );
                        if (end == null) return;
                        setState(() {
                          _dateFilter = 'custom';
                          _customStart = start;
                          _customEnd = end;
                        });
                      },
                      child: Text(_dateFilter == 'custom' && _customStart != null && _customEnd != null
                          ? '${DateFormat.yMd().format(_customStart!)} - ${DateFormat.yMd().format(_customEnd!)}'
                          : 'Custom'),
                    ),
                  ],
                ),
                // Stats display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('OK: $okCount', style: Theme.of(ctx).textTheme.titleMedium),
                    Text('Defects: $defectCount', style: Theme.of(ctx).textTheme.titleMedium),
                    Text('Period: $periodLabel', style: Theme.of(ctx).textTheme.titleMedium),
                    Text('OK Rate: $okRate%', style: Theme.of(ctx).textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
          // History list
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return ListTile(
                  title: Text(item['label'] ?? ''),
                  subtitle: Text(DateFormat.yMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(item['date']))),
                  trailing: Icon(item['label'] == 'OK' ? Icons.check_circle : Icons.error, color: item['label'] == 'OK' ? Colors.green : Colors.red),
                  onTap: () {
                    // TODO: Navigate to detail view
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, VoidCallback onPressed) {
    final isSelected = _dateFilter == label.toLowerCase();
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        primary: isSelected ? Theme.of(context).colorScheme.primary : null,
        onPrimary: isSelected ? Colors.white : null,
      ),
      child: Text(label),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}