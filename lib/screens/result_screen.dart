//result_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ResultScreen extends StatefulWidget {
  final File image; //Selected image file
  final Map<String, dynamic> result; //Inference result
  const ResultScreen({super.key, required this.image, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ds = DataService(); //Data service
  final settings = SettingsService(); //Settings service
  final _formKey = GlobalKey<FormState>(); //Form validation key

  late final String label; //Resolved label
  late final double conf; //Confidence score
  late final bool defectDetected; //Defect flag

  final productIdCtrl = TextEditingController(); //Product ID field
  final batchIdCtrl = TextEditingController(); //Batch ID field
  final stationCtrl = TextEditingController(); //Station field
  final operatorCtrl = TextEditingController(); //Operator field

  @override
  void initState() {
    super.initState();
    label = (widget.result['label'] ?? '').toString(); //Extract label
    conf = (widget.result['confidence'] as num).toDouble(); //Extract confidence
    defectDetected = label.toUpperCase() != 'OK'; //Compute status

    settings.getHapticsEnabled().then((enabled) {
      if (!mounted || !enabled) return; //Guard state
      if (defectDetected) {
        HapticFeedback.mediumImpact(); //Haptic for defect
      } else {
        HapticFeedback.lightImpact(); //Haptic for OK
      }
    });

    settings.getPrefillEnabled().then((prefill) async {
      if (!prefill) return; //Skip if disabled
      final d = await settings.getDefaults(); //Load defaults
      if (!mounted) return; //Guard state
      productIdCtrl.text = d['productId'] ?? ''; //Prefill product ID
      batchIdCtrl.text = d['batchId'] ?? ''; //Prefill batch ID
      stationCtrl.text = d['station'] ?? ''; //Prefill station
      operatorCtrl.text = d['operatorId'] ?? ''; //Prefill operator
    });
  }

  @override
  void dispose() {
    productIdCtrl.dispose(); //Dispose controllers
    batchIdCtrl.dispose();
    stationCtrl.dispose();
    operatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.replaceAll('_', '/'); //Format label
    final titleText = defectDetected ? 'Defect detected: $displayLabel' : 'No defect detected'; //Title text
    final titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: defectDetected ? Colors.red : Colors.green,
    ); //Title style

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16.0), //Page padding
        child: Column(
          children: [
            Expanded(child: Image.file(widget.image)), //Show captured image
            Text(titleText, style: titleStyle), //Show status title
            FutureBuilder<double>(
              future: settings.get(), //Fetch threshold
              builder: (ctx, snap) {
                final th = snap.data ?? 0.1; //Threshold value
                final below = conf < th; //Below-threshold flag
                return Column(
                  children: [
                    Text('Confidence: ${conf.toStringAsFixed(2)}'), //Confidence label
                    const SizedBox(height: 6),
                    if (below)
                      Chip(
                        label: Text('Below threshold (${th.toStringAsFixed(2)})'), //Threshold hint
                        backgroundColor: Colors.orange.shade100,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey, //Attach form key
              autovalidateMode: AutovalidateMode.onUserInteraction, //Live validation
              child: Column(
                children: [
                  TextFormField(
                    controller: productIdCtrl,
                    decoration: const InputDecoration(labelText: 'Product ID *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Product ID is required' : null, //Required
                  ),
                  TextFormField(
                    controller: batchIdCtrl,
                    decoration: const InputDecoration(labelText: 'Batch ID *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Batch ID is required' : null, //Required
                  ),
                  TextFormField(
                    controller: stationCtrl,
                    decoration: const InputDecoration(labelText: 'Station *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Station is required' : null, //Required
                  ),
                  TextFormField(
                    controller: operatorCtrl,
                    decoration: const InputDecoration(labelText: 'Operator *'),
                    textInputAction: TextInputAction.done,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Operator is required' : null, //Required
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Result'), //Save action
                      onPressed: () async {
                        final form = _formKey.currentState; //Validate form
                        if (form == null || !form.validate()) return;

                        String? appVersion; //Resolve app version
                        try {
                          final info = await PackageInfo.fromPlatform();
                          appVersion = '${info.version}+${info.buildNumber}';
                        } catch (_) {}

                        await ds.saveResult(
                          label,
                          conf,
                          widget.image.path,
                          productId: productIdCtrl.text.trim(),
                          batchId: batchIdCtrl.text.trim(),
                          station: stationCtrl.text.trim(),
                          operatorId: operatorCtrl.text.trim(),
                          inferenceMs: (widget.result['inferenceMs'] as int?) ?? (widget.result['inference_ms'] as int?), //Store inference time
                          modelFile: (widget.result['modelFile'] as String?) ?? (widget.result['model_file'] as String?), //Store model file
                          appVersion: appVersion, //Store app version
                        );

                        if (await settings.getPrefillEnabled()) {
                          await settings.setDefaults({
                            'productId': productIdCtrl.text.trim(), //Persist default product
                            'batchId': batchIdCtrl.text.trim(), //Persist default batch
                            'station': stationCtrl.text.trim(), //Persist default station
                            'operatorId': operatorCtrl.text.trim(), //Persist default operator
                          });
                        }

                        if (context.mounted) {
                          Navigator.pop(context); //Close result screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inspection saved!'), duration: Duration(seconds: 2)), //Confirm save
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}