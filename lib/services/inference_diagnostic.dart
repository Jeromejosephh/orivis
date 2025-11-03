// inference_diagnostic.dart
// Diagnostic utility to test different preprocessing schemes and log detailed outputs
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' show exp;

class InferenceDiagnostic {
  tfl.Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputW = 224;
  int _inputH = 224;
  bool _inQuant = false;
  double _inScale = 1.0;
  int _inZero = 0;
  bool _outQuant = false;
  double _outScale = 1.0;
  int _outZero = 0;
  int _numClasses = 5;

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {}

    _interpreter = await tfl.Interpreter.fromAsset('assets/models/orivis_mnv3_q.tflite');

    final ins = _interpreter!.getInputTensors();
    if (ins.isNotEmpty) {
      final ti = ins.first;
      final shape = ti.shape;
      if (shape.length >= 4) {
        _inputH = shape[1];
        _inputW = shape[2];
      }
      _inQuant = (ti.type == tfl.TensorType.uint8 || ti.type == tfl.TensorType.int8);
      if (_inQuant) {
        final p = ti.params;
        _inScale = p.scale;
        _inZero = p.zeroPoint;
      }
    }

    final outs = _interpreter!.getOutputTensors();
    if (outs.isNotEmpty) {
      final to = outs.first;
      final shape = to.shape;
      if (shape.isNotEmpty) _numClasses = shape.last;
      _outQuant = (to.type == tfl.TensorType.uint8 || to.type == tfl.TensorType.int8);
      if (_outQuant) {
        final p = to.params;
        _outScale = p.scale;
        _outZero = p.zeroPoint;
      }
    }
  }

  Future<Map<String, dynamic>> runDiagnostics(File imageFile) async {
    if (_interpreter == null) throw Exception('Load model first');

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');

    final resized = img.copyResize(decoded, width: _inputW, height: _inputH);

    final results = <String, dynamic>{
      'modelInfo': {
        'inputShape': '1x${_inputH}x${_inputW}x3',
        'inputQuant': _inQuant,
        'inputScale': _inScale,
        'inputZero': _inZero,
        'outputQuant': _outQuant,
        'outputScale': _outScale,
        'outputZero': _outZero,
        'numClasses': _numClasses,
      },
      'tests': {},
    };

    // Test 1: Current normalization [-1, 1]
    results['tests']['current_minus1_to_1'] = await _testNormalization(
      resized, 
      (r, g, b) => [
        (r / 255.0 - 0.5) * 2.0,
        (g / 255.0 - 0.5) * 2.0,
        (b / 255.0 - 0.5) * 2.0,
      ],
      'Current: (pixel/255 - 0.5) * 2 → [-1,1]'
    );

    // Test 2: Simple [0, 1] normalization
    results['tests']['simple_0_to_1'] = await _testNormalization(
      resized,
      (r, g, b) => [r / 255.0, g / 255.0, b / 255.0],
      'Simple: pixel/255 → [0,1]'
    );

    // Test 3: ImageNet normalization
    results['tests']['imagenet'] = await _testNormalization(
      resized,
      (r, g, b) => [
        (r / 255.0 - 0.485) / 0.229,
        (g / 255.0 - 0.456) / 0.224,
        (b / 255.0 - 0.406) / 0.225,
      ],
      'ImageNet: (pixel/255 - mean) / std'
    );

    // Test 4: No normalization (raw 0-255)
    results['tests']['raw_0_to_255'] = await _testNormalization(
      resized,
      (r, g, b) => [r.toDouble(), g.toDouble(), b.toDouble()],
      'Raw: pixel values [0,255]'
    );

    return results;
  }

  Future<Map<String, dynamic>> _testNormalization(
    img.Image image,
    List<double> Function(num r, num g, num b) normalize,
    String description,
  ) async {
    final floats = List.generate(1, (_) => 
      List.generate(_inputH, (_) => 
        List.generate(_inputW, (_) => 
          List.filled(3, 0.0)
        )
      )
    );

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int y = 0; y < _inputH; y++) {
      for (int x = 0; x < _inputW; x++) {
        final p = image.getPixel(x, y);
        final normalized = normalize(p.r, p.g, p.b);
        floats[0][y][x][0] = normalized[0];
        floats[0][y][x][1] = normalized[1];
        floats[0][y][x][2] = normalized[2];
        
        for (var val in normalized) {
          if (val < minVal) minVal = val;
          if (val > maxVal) maxVal = val;
        }
      }
    }

    final outputTensorObj = List.generate(1, (_) => List.filled(_numClasses, 0.0));

    final t0 = DateTime.now();
    _interpreter!.run(floats, outputTensorObj);
    final elapsedMs = DateTime.now().difference(t0).inMilliseconds;

    List<double> scores = (outputTensorObj as List)[0].cast<double>();

    // Apply softmax
    final expScores = scores.map((x) => exp(x)).toList();
    final sumExp = expScores.reduce((a, b) => a + b);
    final probabilities = expScores.map((x) => x / sumExp).toList();

    int bestIdx = 0;
    double bestConf = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestConf) {
        bestIdx = i;
        bestConf = probabilities[i];
      }
    }

    final bestLabel = (_labels.isNotEmpty && bestIdx < _labels.length) 
        ? _labels[bestIdx] 
        : 'Class $bestIdx';

    final allResultsList = <Map<String, dynamic>>[];
    for (int i = 0; i < _labels.length && i < probabilities.length; i++) {
      allResultsList.add({
        'label': _labels[i],
        'probability': probabilities[i],
      });
    }

    return {
      'description': description,
      'inputRange': {'min': minVal, 'max': maxVal},
      'rawOutputs': scores,
      'probabilities': probabilities,
      'allResults': allResultsList,
      'prediction': bestLabel,
      'confidence': bestConf,
      'inferenceMs': elapsedMs,
    };
  }

  void dispose() => _interpreter?.close();
}
