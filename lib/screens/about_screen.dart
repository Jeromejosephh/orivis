//about_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart' show rootBundle;

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = ''; //App version string
  String buildNumber = ''; //Build number string
  String modelFile = 'assets/models/orivis_mnv3_q.tflite'; //Model file path
  int labelCount = 0; //Count of classes
  List<String> labels = const []; //Class label list

  @override
  void initState() {
    super.initState();
    _load(); //Load version and labels
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform(); //Fetch app info
      final raw = await rootBundle.loadString('assets/models/labels.txt'); //Load labels file
      final ls = raw.split('\n').where((e) => e.trim().isNotEmpty).toList(); //Parse labels
      if (!mounted) return;
      setState(() {
        version = info.version; //Set version
        buildNumber = info.buildNumber; //Set build
        labels = ls; //Set label list
        labelCount = ls.length; //Set count
      });
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')), //Standard app bar
      body: Padding(
        padding: const EdgeInsets.all(16.0), //Page padding
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.app_shortcut),
              title: const Text('App Version'),
              subtitle: Text(version.isEmpty ? '—' : '$version ($buildNumber)'), //Version info
            ),
            const Divider(),
            const ListTile(
              title: Text('Model'),
              subtitle: Text('On-device TFLite model for defect detection'), //Model description
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Model file'),
              subtitle: Text(modelFile), //Model file name
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Classes'),
              subtitle: Text(labelCount == 0 ? '—' : '$labelCount: ${labels.join(', ')}'), //Labels overview
            ),
            const SizedBox(height: 12),
            Text(
              'Orivis helps you run offline visual inspection with on-device AI. For support, export logs from Settings > Support & Diagnostics.',
              style: Theme.of(context).textTheme.bodySmall, //Support guidance
            ),
          ],
        ),
      ),
    );
  }
}