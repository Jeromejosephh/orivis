//settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';
import '../services/data_service.dart';
import 'package:share_plus/share_plus.dart';
import '../services/logging_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = SettingsService(); //Settings provider
  final exporter = ExportService(); //CSV export provider
  double val = 0.1; //Confidence threshold
  bool prefillEnabled = true; //Prefill toggle
  bool hapticsEnabled = true; //Haptics toggle
  String retentionPolicy = 'forever'; //Retention option

  @override
  void initState() {
    super.initState();
    s.get().then((v) => setState(() => val = v)); //Load threshold
    s.getPrefillEnabled().then((v) => setState(() => prefillEnabled = v)); //Load prefill
    s.getHapticsEnabled().then((v) => setState(() => hapticsEnabled = v)); //Load haptics
    s.getRetentionPolicy().then((v) => setState(() => retentionPolicy = v)); //Load retention
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 68,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: Theme.of(c).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontFamily: 'SF Pro Display',
              )),
              Text('Preferences & diagnostics', style: Theme.of(c).textTheme.bodySmall?.copyWith(
                color: Theme.of(c).colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              )),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Model & UX'), //Section title
            Text('Confidence Threshold: ${val.toStringAsFixed(2)}'), //Threshold label
            Slider(
              min: 0.0,
              max: 1.0,
              divisions: 20,
              value: val,
              onChanged: (v) => setState(() => val = v), //Preview slider move
              onChangeEnd: (v) => s.set(v), //Persist on release
            ),
            const Divider(height: 24),
            SwitchListTile(
              title: const Text('Prefill last used metadata'),
              value: prefillEnabled,
              onChanged: (v) async {
                setState(() => prefillEnabled = v); //Update toggle
                await s.setPrefillEnabled(v); //Persist toggle
              },
            ),
            SwitchListTile(
              title: const Text('Haptics feedback'),
              value: hapticsEnabled,
              onChanged: (v) async {
                setState(() => hapticsEnabled = v); //Update toggle
                await s.setHapticsEnabled(v); //Persist toggle
              },
            ),
            const Divider(height: 32),
            const Text('Data'), //Section title
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Retention policy'),
              subtitle: Text('Automatically delete old inspections: ${_retentionLabel(retentionPolicy)}'),
              onTap: () async {
                final choice = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Retention Policy'),
                    children: [
                      SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '30d'), child: const Text('30 days')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '1yr'), child: const Text('1 year')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'forever'), child: const Text('Forever')),
                    ],
                  ),
                );
                if (choice != null) {
                  setState(() => retentionPolicy = choice); //Update label
                  await s.setRetentionPolicy(choice); //Persist policy
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.orange),
              title: const Text('Clean up old inspections'),
              subtitle: const Text('Delete inspections based on retention policy'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context); //Messenger for snackbars
                final policy = await s.getRetentionPolicy(); //Read current policy
                DateTime? cutoff;
                final now = DateTime.now();
                if (policy == '30d') {
                  cutoff = now.subtract(const Duration(days: 30)); //30 days cutoff
                } else if (policy == '1yr') {
                  cutoff = now.subtract(const Duration(days: 365)); //1 year cutoff
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('Retention policy is Forever; no cleanup needed'))); //No-op
                  return;
                }
                if (!mounted) return;
                final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clean up old inspections'),
                        content: Text('This will delete inspections older than ${_retentionLabel(policy)} and their images. Continue?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.orange))),
                        ],
                      ),
                    ) ?? false;
                if (!confirm) return;
                final data = DataService(); //Data accessor
                final deleted = await data.deleteOlderThan(cutoff); //Perform cleanup
                messenger.showSnackBar(SnackBar(content: Text('Deleted $deleted old inspection(s)'))); //Report deletions
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Export inspections CSV'),
              subtitle: const Text('Share a CSV of all saved inspections'),
              onTap: () async {
                final file = await exporter.exportAllToCsv(); //Generate CSV
                if (!mounted) return;
                if (file == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No inspections to export'))); //No data
                  return;
                }
                await Share.shareXFiles([XFile(file.path)], text: 'Orivis inspections export'); //Share CSV
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear all inspections'),
              subtitle: const Text('Permanently deletes all saved inspections'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear all inspections'),
                        content: const Text('This will permanently delete all saved inspections. Continue?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ) ?? false;
                if (!confirm) return;
                final data = DataService(); //Use service
                await data.clearAll(); //Clear storage
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All inspections cleared'))); //Confirm
              },
            ),
            const Divider(height: 32),
            const Text('Support & Diagnostics'), //Section title
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Export logs'),
              subtitle: const Text('Share app logs to help debug issues'),
              onTap: () async {
                final f = await LoggingService.instance.exportLogFile(); //Export log file
                if (!mounted) return;
                if (f == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No logs available'))); //No logs
                  return;
                }
                await Share.shareXFiles([XFile(f.path)], text: 'Orivis logs'); //Share logs
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear logs'),
              subtitle: const Text('Reset local diagnostic logs'),
              onTap: () async {
                await LoggingService.instance.clear(); //Wipe log file
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs cleared'))); //Confirm
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('App version and model info'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())); //Open About
              },
            ),
          ],
        ),
      );

  String _retentionLabel(String policy) {
    switch (policy) {
      case '30d': return '30 days';
      case '1yr': return '1 year';
      default: return 'Forever';
    }
  }
}