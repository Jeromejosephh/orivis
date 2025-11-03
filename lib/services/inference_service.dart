//inference_service.dart
import 'dart:io';
import 'dart:math' show exp;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'logging_service.dart';

class InferenceService {
  tfl.Interpreter? _interpreter; //TFLite interpreter instance
  List<String> _labels = []; //Class labels
  int _numClasses = 4; //Default class count

  int _inputW = 224; //Model input width
  int _inputH = 224; //Model input height
  bool _inQuant = false; //Quantized input flag
  double _inScale = 1.0; //Input scale for quantization
  int _inZero = 0; //Input zero point

  bool _outQuant = false; //Quantized output flag
  double _outScale = 1.0; //Output scale
  int _outZero = 0; //Output zero point

  Future<void> load() async {
    try {
      try {
        final raw = await rootBundle.loadString('assets/models/labels.txt'); //Load labels file
        _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
      } catch (_) {}

      _interpreter = await tfl.Interpreter.fromAsset('assets/models/orivis_mnv3_q.tflite'); //Load TFLite model

      final ins = _interpreter!.getInputTensors(); //Inspect input tensor
      if (ins.isNotEmpty) {
        final ti = ins.first;
        final shape = ti.shape;
        if (shape.length >= 4) {
          _inputH = shape[1]; //Set input height
          _inputW = shape[2]; //Set input width
        }
        _inQuant = (ti.type == tfl.TensorType.uint8 || ti.type == tfl.TensorType.int8); //Detect quant input
        if (_inQuant) {
          final p = ti.params;
          _inScale = p.scale; //Read input scale
          _inZero = p.zeroPoint; //Read input zero point
        }
      }

      final outs = _interpreter!.getOutputTensors(); //Inspect output tensor
      if (outs.isNotEmpty) {
        final to = outs.first;
        final shape = to.shape;
        if (shape.isNotEmpty) _numClasses = shape.last; //Set class count
        _outQuant = (to.type == tfl.TensorType.uint8 || to.type == tfl.TensorType.int8); //Detect quant output
        if (_outQuant) {
          final p = to.params;
          _outScale = p.scale; //Read output scale
          _outZero = p.zeroPoint; //Read output zero point
        }
      }
    } catch (e) {
      throw Exception('Failed to load TFLite model asset. Check pubspec assets and file path. Details: $e');
    }
  }

  Future<Map<String, dynamic>> classify(File imageFile) async {
    if (_interpreter == null) {
      throw Exception('Interpreter not loaded. Call load() first.'); //Guard if model not loaded
    }

    final bytes = await imageFile.readAsBytes(); //Read file bytes
    final decoded = img.decodeImage(bytes); //Decode image
    if (decoded == null) throw Exception('Could not decode image');

    final resized = img.copyResize(decoded, width: _inputW, height: _inputH); //Resize to model input

    Object inputTensorObj; //Prepare input tensor buffer
    if (_inQuant) {
      final ints = List.generate(1, (_) => List.generate(_inputH, (_) => List.generate(_inputW, (_) => List.filled(3, 0))));
      for (int y = 0; y < _inputH; y++) {
        for (int x = 0; x < _inputW; x++) {
          final p = resized.getPixel(x, y);
          final r = p.r / 255.0;
          final g = p.g / 255.0;
          final b = p.b / 255.0;
          ints[0][y][x][0] = (r / _inScale + _inZero).round().clamp(-128, 255);
          ints[0][y][x][1] = (g / _inScale + _inZero).round().clamp(-128, 255);
          ints[0][y][x][2] = (b / _inScale + _inZero).round().clamp(-128, 255);
        }
      }
      inputTensorObj = ints;
    } else {
      final floats = List.generate(1, (_) => List.generate(_inputH, (_) => List.generate(_inputW, (_) => List.filled(3, 0.0))));
      for (int y = 0; y < _inputH; y++) {
        for (int x = 0; x < _inputW; x++) {
          final p = resized.getPixel(x, y);
          // Use raw pixel values [0, 255] - no normalization
          // Based on diagnostic results showing Raw normalization works best
          floats[0][y][x][0] = p.r.toDouble();
          floats[0][y][x][1] = p.g.toDouble();
          floats[0][y][x][2] = p.b.toDouble();
        }
      }
      inputTensorObj = floats;
    }

    Object outputTensorObj; //Prepare output buffer
    if (_outQuant) {
      outputTensorObj = List.generate(1, (_) => List.filled(_numClasses, 0));
    } else {
      outputTensorObj = List.generate(1, (_) => List.filled(_numClasses, 0.0));
    }

    final t0 = DateTime.now(); //Start timer
    _interpreter!.run(inputTensorObj, outputTensorObj); //Run inference
    final elapsedMs = DateTime.now().difference(t0).inMilliseconds; //Elapsed ms

    late List<double> scores; //Get scores as doubles
    if (_outQuant) {
      final ints = (outputTensorObj as List)[0].cast<int>();
      scores = ints.map((v) => (v - _outZero) * _outScale).toList(); //Dequantize output
    } else {
      scores = (outputTensorObj as List)[0].cast<double>();
    }

    if (kDebugMode) {
      final minVal = scores.reduce((a, b) => a < b ? a : b); //Min score
      final maxVal = scores.reduce((a, b) => a > b ? a : b); //Max score
      debugPrint('DEBUG: Raw(dequantized) output range: [$minVal, $maxVal]');
    }

    List<double> probabilities; //Convert to probabilities if needed
    if (!_outQuant) {
      final sum = scores.fold<double>(0.0, (a, b) => a + b);
      final looksLikeProbs = sum > 0.9 && sum < 1.1 && scores.every((v) => v >= 0.0 && v <= 1.0);
      if (looksLikeProbs) {
        probabilities = scores; //Already probabilities
      } else {
        final expScores = scores.map((x) => exp(x)).toList(); //Softmax numerator
        final sumExp = expScores.reduce((a, b) => a + b); //Softmax denominator
        probabilities = expScores.map((x) => x / sumExp).toList(); //Softmax result
      }
    } else {
      final expScores = scores.map((x) => exp(x)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      probabilities = expScores.map((x) => x / sumExp).toList();
    }

    int best = 0; //Index of best class
    double bestScore = probabilities[0]; //Best score
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestScore) { best = i; bestScore = probabilities[i]; }
    }

    if (kDebugMode) {
      final bestLabel = (_labels.isNotEmpty && best < _labels.length) ? _labels[best] : 'Class $best';
      debugPrint('DEBUG: Best class=$best, confidence=$bestScore, label=$bestLabel');
    }

    final label = (_labels.isNotEmpty && best < _labels.length) ? _labels[best] : 'Class $best'; //Resolve label
    await LoggingService.instance.log('Inference: label=$label conf=${bestScore.toStringAsFixed(3)} ms=$elapsedMs', level: 'METRIC'); //Log metrics

    return {
      'label': label, //Predicted label
      'confidence': bestScore, //Confidence score
      'inferenceMs': elapsedMs, //Elapsed time
      'modelFile': 'assets/models/orivis_mnv3_q.tflite', //Model file
      'numClasses': _numClasses, //Class count
    };
  }

  void dispose() => _interpreter?.close(); //Close interpreter
}