//inspection_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/data_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item; //Selected inspection
  final int actualIndex; //Index in stored order
  const InspectionDetailScreen({super.key, required this.item, required this.actualIndex});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  late Map<String, dynamic> it; //Mutable copy of item
  final data = DataService(); //Data service
  bool _hasChanges = false; //Track if edits were made

  @override
  void initState() {
    super.initState();
    it = Map<String, dynamic>.from(widget.item); //Copy for edits
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString); //Parse timestamp
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString; //Fallback on failure
    }
  }

  Future<void> _share() async {
    final label = (it['label'] ?? '').toString().replaceAll('_', '/'); //Readable label
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

  Future<void> _edit() async {
    final pid = TextEditingController(text: (it['productId'] ?? '').toString()); //Prefill
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
      it['productId'] = pid.text; //Apply update
      it['batchId'] = bid.text;
      it['station'] = st.text;
      it['operatorId'] = op.text;
      await data.update(widget.actualIndex, it); //Persist edit
      _hasChanges = true; //Mark changes made
      if (!mounted) return;
      setState(() {}); //Refresh UI
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspection updated'))); //Confirm
    }
  }

  Future<void> _delete() async {
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
    await data.delete(widget.actualIndex); //Remove from storage
    if (!mounted) return;
    Navigator.pop(context, true); //Signal deletion
  }

  @override
  Widget build(BuildContext context) {
    final label = (it['label'] ?? '').toString(); //Raw label
    final displayLabel = label.replaceAll('_', '/'); //Readable label
    final ok = label.toUpperCase() == 'OK'; //Status flag
    final color = ok ? Colors.green : Colors.red; //Status color
    final conf = (it['confidence'] as num?)?.toDouble() ?? 0.0; //Score
    final pid = it['productId'] ?? ''; //Product
    final bid = it['batchId'] ?? ''; //Batch
    final st = it['station'] ?? ''; //Station
    final op = it['operatorId'] ?? ''; //Operator
    final ts = it['timestamp'] ?? (it['time'] ?? ''); //Timestamp
    final imgPath = it['imagePath'] ?? ''; //Image path

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        actions: [
          IconButton(tooltip: 'Share', onPressed: _share, icon: const Icon(Icons.ios_share)), //Share
          IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit)), //Edit
          IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete)), //Delete
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3, //Image box
            child: Container(
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: imgPath.isNotEmpty && File(imgPath).existsSync()
                  ? InteractiveViewer(child: Image.file(File(imgPath), fit: BoxFit.contain)) //Zoomable image
                  : const Center(child: Icon(Icons.image, size: 56, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                label: Text(ok ? 'OK' : 'Defect: $displayLabel'), //Status chip
                backgroundColor: ok ? Colors.green.shade50 : Colors.red.shade50,
                labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text('Confidence: ${(conf * 100).toStringAsFixed(1)}%'), //Score label
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: conf.clamp(0.0, 1.0), //Score bar
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12), //Metadata card
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metaRow(Icons.qr_code_2, 'Product ID', pid),
                  _metaRow(Icons.numbers, 'Batch ID', bid),
                  _metaRow(Icons.factory, 'Station', st),
                  _metaRow(Icons.badge, 'Operator', op),
                  _metaRow(Icons.access_time, 'Timestamp', _formatTimestamp(ts)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    if (value.toString().isEmpty) return const SizedBox.shrink(); //Skip empty fields
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]), //Field icon
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), //Field label
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), //Field value
              ],
            ),
          ),
        ],
      ),
    );
  }
}