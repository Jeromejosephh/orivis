// diagnostic_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/inference_diagnostic.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final diagnostic = InferenceDiagnostic();
  final picker = ImagePicker();
  bool loading = true;
  String? err;
  Map<String, dynamic>? results;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await diagnostic.load();
      if (!mounted) return;
      setState(() {
        loading = false;
        err = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        err = 'Model load failed: $e';
      });
    }
  }

  Future<void> _pickAndTest() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    
    final file = File(x.path);
    setState(() {
      selectedImage = file;
      loading = true;
      results = null;
    });

    try {
      final res = await diagnostic.runDiagnostics(file);
      if (!mounted) return;
      setState(() {
        results = res;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = 'Diagnostic failed: $e';
      });
    }
  }

  @override
  void dispose() {
    diagnostic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Diagnostics')),
      body: loading && results == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Model Preprocessing Diagnostic Tool',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This tool tests your model with different input normalization schemes to identify preprocessing mismatches.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: loading ? null : _pickAndTest,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image & Run Diagnostics'),
                ),
                const SizedBox(height: 16),
                if (selectedImage != null) ...[
                  const Text('Test Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(selectedImage!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (results != null) ...[
                  _buildModelInfo(),
                  const SizedBox(height: 16),
                  _buildTestResults(),
                  const SizedBox(height: 16),
                  _buildRecommendation(),
                ],
                if (err != null) ...[
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(err!, style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildModelInfo() {
    final info = results!['modelInfo'] as Map;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Model Info:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Input Shape: ${info['inputShape']}'),
            Text('Input Quantized: ${info['inputQuant']}'),
            if (info['inputQuant']) ...[
              Text('  Scale: ${info['inputScale']}, Zero: ${info['inputZero']}'),
            ],
            Text('Output Quantized: ${info['outputQuant']}'),
            if (info['outputQuant']) ...[
              Text('  Scale: ${info['outputScale']}, Zero: ${info['outputZero']}'),
            ],
            Text('Classes: ${info['numClasses']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults() {
    final tests = results!['tests'] as Map;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Test Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...tests.entries.map((entry) {
          final testData = entry.value as Map;
          final prediction = testData['prediction'];
          final confidence = (testData['confidence'] as num).toDouble();
          final description = testData['description'];
          final inputRange = testData['inputRange'] as Map;
          final allResultsList = testData['allResults'] as List;
          
          final isOK = prediction.toString().toUpperCase() == 'OK';
          final color = isOK ? Colors.green : Colors.red;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(prediction),
                        backgroundColor: color.withValues(alpha: 0.2),
                        labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Input range: [${(inputRange['min'] as num).toStringAsFixed(2)}, ${(inputRange['max'] as num).toStringAsFixed(2)}]',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text('All class probabilities:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  ...allResultsList.map((item) {
                    final itemMap = item as Map;
                    final label = itemMap['label'] as String;
                    final prob = (itemMap['probability'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(label, style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: prob,
                              backgroundColor: Colors.grey.shade200,
                              minHeight: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(prob * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecommendation() {
    final tests = results!['tests'] as Map;
    
    // Find which normalization gives the most reasonable result
    String recommendation = '';
    String? bestTest;
    
    for (final entry in tests.entries) {
      final testData = entry.value as Map;
      final prediction = testData['prediction'].toString().toUpperCase();
      
      if (prediction != 'OK') {
        bestTest = entry.key;
        break;
      }
    }
    
    if (bestTest != null) {
      final testData = tests[bestTest] as Map;
      recommendation = '✅ FOUND ISSUE: The "${testData['description']}" normalization detected a defect!\n\n'
          'Your current normalization is likely incorrect. Update inference_service.dart to use this scheme.';
    } else {
      recommendation = '⚠️ ALL TESTS PREDICT OK\n\n'
          'This suggests the problem is not preprocessing, but rather:\n'
          '1. Training data domain mismatch (model never saw images like this)\n'
          '2. Model needs retraining with more diverse, real-world data\n'
          '3. Check that training images actually contain visible defects';
    }
    
    return Card(
      color: bestTest != null ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommendation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(recommendation),
          ],
        ),
      ),
    );
  }
}
