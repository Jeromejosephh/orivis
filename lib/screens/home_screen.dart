//home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/settings_service.dart';
import 'inspection_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartInspection; //Trigger navigation to Inspect tab
  const HomeScreen({super.key, required this.onStartInspection});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final data = DataService(); //Data source
  final settings = SettingsService(); //Settings source
  final TextEditingController _searchCtrl = TextEditingController(); //Search controller
  List<Map<String, dynamic>> history = []; //Inspection history
  bool _showSwipeHint = false; //Swipe help banner toggle
  String _statusFilter = 'all'; //Status filter state
  String _dateFilter = 'all'; //Date filter state
  DateTime? _customStart; //Custom start date
  DateTime? _customEnd; //Custom end date

  @override
  void initState() {
    super.initState();
    _load(); //Initial data load
    _initSwipeHint(); //Compute swipe hint visibility
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); //Dispose controller
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load(); //Refresh when returning to this tab
  }

  Future<void> _load() async {
    final h = await data.getAll(); //Load persisted history
    setState(() => history = h.reversed.toList()); //Latest on top
  }

  Future<void> _initSwipeHint() async {
    final seen = await settings.getSwipeHintShown(); //Check if hint was dismissed
    if (!seen) {
      setState(() => _showSwipeHint = true); //Show once
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString); //Parse date
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return isoString; //Fallback if parse fails
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    final q = _searchCtrl.text.trim().toLowerCase(); //Normalize query
    Iterable<Map<String, dynamic>> out = items;

    if (_statusFilter == 'ok') {
      out = out.where((it) => (it['label'] ?? '').toString().toUpperCase() == 'OK'); //Filter OK only
    } else if (_statusFilter == 'defect') {
      out = out.where((it) => (it['label'] ?? '').toString().toUpperCase() != 'OK'); //Filter defects only
    }

    final now = DateTime.now(); //Compute date filters
    final todayStart = DateTime(now.year, now.month, now.day);
    if (_dateFilter != 'all') {
      out = out.where((it) {
        final tsStr = it['timestamp'] ?? it['time'];
        if (tsStr == null) return false;
        DateTime dt;
        try {
          dt = DateTime.parse(tsStr.toString());
        } catch (_) {
          return false;
        }
        if (_dateFilter == 'today') return dt.isAfter(todayStart);
        if (_dateFilter == '7d') return dt.isAfter(now.subtract(const Duration(days: 7)));
        if (_dateFilter == 'custom' && _customStart != null && _customEnd != null) {
          final start = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
          final end = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59, 999);
          return (dt.isAtSameMomentAs(start) || dt.isAfter(start)) && (dt.isBefore(end) || dt.isAtSameMomentAs(end));
        }
        return true;
      });
    }

    if (q.isNotEmpty) {
      bool matches(Map<String, dynamic> it) {
        bool m(String? v) => (v ?? '').toLowerCase().contains(q); //Simple contains match
        return m(it['productId']?.toString()) ||
               m(it['batchId']?.toString()) ||
               m(it['operatorId']?.toString()) ||
               m((it['label'] ?? '').toString());
      }
      out = out.where(matches); //Apply text query
    }
    return out.toList(); //Materialize list
  }

  Map<String, int> _getTodayStats() {
    final today = DateTime.now(); //Compute daily counts
    int okCount = 0, defectCount = 0;
    for (final item in history) {
      final ts = item['timestamp'] ?? '';
      try {
        final dt = DateTime.parse(ts);
        final sameDay = dt.year == today.year && dt.month == today.month && dt.day == today.day;
        if (sameDay) {
          final label = (item['label'] ?? '').toString().toUpperCase();
          if (label == 'OK') {
            okCount++;
          } else {
            defectCount++;
          }
        }
      } catch (_) {}
    }
    return {'ok': okCount, 'defect': defectCount}; //Return summary
  }

  Future<void> _shareInspection(Map<String, dynamic> it) async {
    final label = (it['label'] ?? '').toString().replaceAll('_', '/'); //Make label readable
    final conf = (it['confidence'] as num?)?.toStringAsFixed(2) ?? '';
    final pid = it['productId'] ?? '';
    final bid = it['batchId'] ?? '';
    final st = it['station'] ?? '';
    final op = it['operatorId'] ?? '';
    final ts = it['timestamp'] ?? '';
    final imgPath = it['imagePath'] ?? it['image'];
    final text = 'Result: $label\nConfidence: $conf\nPID: $pid  BID: $bid  ST: $st  OP: $op\nTime: $ts';
    if (imgPath != null && imgPath.toString().isNotEmpty && File(imgPath).existsSync()) {
      await Share.shareXFiles([XFile(imgPath)], text: text); //Share with image
    } else {
      await Share.share(text); //Share text only
    }
  }

  Future<void> _editInspection(int actualIndex, Map<String, dynamic> it) async {
    final pid = TextEditingController(text: (it['productId'] ?? '').toString()); //Prefill fields
    final bid = TextEditingController(text: (it['batchId'] ?? '').toString());
    final st = TextEditingController(text: (it['station'] ?? '').toString());
    final op = TextEditingController(text: (it['operatorId'] ?? '').toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Inspection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: pid, decoration: const InputDecoration(labelText: 'Product ID')),
              TextField(controller: bid, decoration: const InputDecoration(labelText: 'Batch ID')),
              TextField(controller: st, decoration: const InputDecoration(labelText: 'Station')),
              TextField(controller: op, decoration: const InputDecoration(labelText: 'Operator')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      final updated = Map<String, dynamic>.from(it); //Apply edits
      updated['productId'] = pid.text;
      updated['batchId'] = bid.text;
      updated['station'] = st.text;
      updated['operatorId'] = op.text;
      await data.update(actualIndex, updated); //Persist edits
      await _load(); //Refresh list
    }
  }

  void _showFullImage(String path) {
    if (path.isEmpty || !File(path).existsSync()) return; //Skip if missing
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Image'), backgroundColor: Colors.black, foregroundColor: Colors.white),
          backgroundColor: Colors.black,
          body: Center(child: InteractiveViewer(child: Image.file(File(path)))), //Zoomable view
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final stats = _getTodayStats(); //Compute today stats
    final todayTotal = stats['ok']! + stats['defect']!;
    final okRate = todayTotal > 0 ? (stats['ok']! / todayTotal * 100).toStringAsFixed(1) : '0.0'; //Compute OK rate

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orivis',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontFamily: 'SF Pro Display',
              ),
            ),
            Text(
              'History and insights',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
        actions: const [],
      ), //Enhanced heading
      body: Column(
        children: [
          if (_showSwipeHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.swipe_left, color: Colors.blue),
                  title: const Text('Swipe left on a row to Share, Edit, or Delete', style: TextStyle(fontSize: 14)),
                  trailing: TextButton(
                    onPressed: () async { setState(() => _showSwipeHint = false); await settings.setSwipeHintShown(true); },
                    child: const Text('Got it'),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12), //Quick stats cards
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Container(
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${stats['ok']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)))),
                          const SizedBox(height: 4),
                          const Text('OK Today', style: TextStyle(fontSize: 12, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.red.shade50,
                    child: Container(
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${stats['defect']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)))),
                          const SizedBox(height: 4),
                          const Text('Defects Today', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Container(
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('$okRate%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)))),
                          const SizedBox(height: 4),
                          const Text('OK Rate', style: TextStyle(fontSize: 12, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), //Search bar
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by PID, BID or Operator',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty ? null : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); setState(() {}); },
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), //Status chips
            child: Row(
              children: [
                ChoiceChip(label: const Text('All'), selected: _statusFilter == 'all', onSelected: (_) => setState(() => _statusFilter = 'all')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('OK'), selected: _statusFilter == 'ok', onSelected: (_) => setState(() => _statusFilter = 'ok')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Defects'), selected: _statusFilter == 'defect', onSelected: (_) => setState(() => _statusFilter = 'defect')),
                const Spacer(),
                if (_statusFilter != 'all' || _searchCtrl.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: () { setState(() { _statusFilter = 'all'; _searchCtrl.clear(); _dateFilter = 'all'; _customStart = null; _customEnd = null; }); },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), //Date chips
            child: Row(
              children: [
                ChoiceChip(label: const Text('All time'), selected: _dateFilter == 'all', onSelected: (_) => setState(() => _dateFilter = 'all')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Today'), selected: _dateFilter == 'today', onSelected: (_) => setState(() => _dateFilter = 'today')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Last 7d'), selected: _dateFilter == '7d', onSelected: (_) => setState(() => _dateFilter = '7d')),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(_dateFilter == 'custom' && _customStart != null && _customEnd != null
                      ? '${_customStart!.month}/${_customStart!.day}–${_customEnd!.month}/${_customEnd!.day}'
                      : 'Custom'),
                  selected: _dateFilter == 'custom',
                  onSelected: (_) async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: (_customStart != null && _customEnd != null) ? DateTimeRange(start: _customStart!, end: _customEnd!) : null,
                    );
                    if (picked != null) {
                      setState(() { _dateFilter = 'custom'; _customStart = picked.start; _customEnd = picked.end; });
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4), //Counter label
            child: Builder(builder: (context) {
              final filtered = _filtered(history);
              return Text('Saved Inspections (${filtered.length}/${history.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
            }),
          ),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32), //Empty state card
                      child: Card(
                        elevation: 0,
                        color: Colors.indigo.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.indigo.shade300),
                                const SizedBox(height: 16),
                                Text('No inspections yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('Start by capturing or selecting an image to inspect', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                                const SizedBox(height: 20),
                                FilledButton.icon(onPressed: widget.onStartInspection, icon: const Icon(Icons.camera_alt), label: const Text('Start Inspection')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final filtered = _filtered(history); //Apply filters
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24), //No results state
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off, size: 56, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text('No matching inspections'),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () { setState(() { _statusFilter = 'all'; _searchCtrl.clear(); }); },
                                  icon: const Icon(Icons.clear_all),
                                  label: const Text('Clear filters'),
                                )
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: filtered.length, //Render list
                        itemBuilder: (_, i) {
                          final it = filtered[i];
                          final label = (it['label'] ?? '').toString();
                          final conf = (it['confidence'] as num?)?.toDouble() ?? 0.0;
                          final pid = it['productId'] ?? '';
                          final bid = it['batchId'] ?? '';
                          final st = it['station'] ?? '';
                          final op = it['operatorId'] ?? '';
                          final imgPath = it['imagePath'] ?? '';
                          final ts = it['timestamp'] ?? (it['time'] ?? '');
                          final ok = label.toUpperCase() == 'OK';
                          final color = ok ? Colors.green : Colors.red;
                          final displayLabel = label.replaceAll('_', '/'); //Prettify label
                          return Slidable(
                            key: Key('${it['timestamp']}_$i'),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(onPressed: (_) => _shareInspection(it), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.ios_share, label: 'Share'),
                                SlidableAction(
                                  onPressed: (_) {
                                    final actualIndex = history.length - 1 - history.indexOf(it); //Map to stored index
                                    _editInspection(actualIndex, it);
                                  },
                                  backgroundColor: Colors.orange, foregroundColor: Colors.white, icon: Icons.edit, label: 'Edit',
                                ),
                                SlidableAction(
                                  onPressed: (_) async {
                                    final messenger = ScaffoldMessenger.of(context); //Capture messenger
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Inspection'),
                                            content: const Text('Are you sure you want to delete this inspection?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        ) ?? false;
                                    if (!confirm) return;
                                    final actualIndex = history.length - 1 - history.indexOf(it); //Compute index again
                                    final deletedItem = Map<String, dynamic>.from(it); //Snapshot for undo
                                    await data.delete(actualIndex); //Delete item
                                    await _load(); //Refresh list
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text('Inspection deleted'),
                                        duration: const Duration(seconds: 4),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          onPressed: () async { await data.insertAt(actualIndex, deletedItem); await _load(); }, //Undo restore
                                        ),
                                      ),
                                    );
                                  },
                                  backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete, label: 'Delete',
                                ),
                              ],
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () => _showFullImage(imgPath), //Open full image
                                  child: imgPath.isNotEmpty && File(imgPath).existsSync()
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.file(File(imgPath), width: 60, height: 60, fit: BoxFit.cover),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                ),
                                onTap: () async {
                                  final actualIndex = history.length - 1 - history.indexOf(it); //Map to stored index
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => InspectionDetailScreen(item: it, actualIndex: actualIndex)),
                                  );
                                  if (changed == true) { await _load(); } //Refresh after edits/deletion
                                },
                                title: Text(ok ? 'OK' : 'Defect: $displayLabel', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Confidence: ${conf.toStringAsFixed(2)}'),
                                    if (pid.isNotEmpty) Text('Product ID: $pid'),
                                    if (bid.isNotEmpty) Text('Batch ID: $bid'),
                                    if (st.isNotEmpty) Text('Station: $st'),
                                    if (op.isNotEmpty) Text('Operator: $op'),
                                    Text(_formatTimestamp(ts), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}