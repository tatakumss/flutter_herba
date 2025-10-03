import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Interpreter? _interpreter;
  Interpreter? _embedder; // optional feature extractor
  bool _initialized = false;
  int _inputSize = 224;
  bool _isQuant = true; // default to quant model
  List<String> _labels = [];

  bool get isInitialized => _initialized;

  Future<void> init({
    String modelAsset = 'assets/models/herbal_classifier_mobile.tflite',
    String labelsAsset = 'assets/models/phase1_labels.txt',
    String? extractorAsset, // optional feature extractor model
  }) async {
    if (_initialized) return;
    try {
      // Load model bytes explicitly for clearer error surfacing
      final modelData = await rootBundle.load(modelAsset);
      final modelBytes = modelData.buffer.asUint8List();
      final options = InterpreterOptions()
        ..threads = 2
        // NNAPI can be unstable on some emulators; disable by default
        ..useNnApiForAndroid = false;
      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    } catch (e) {
      // Re-throw with context so UI can show precise cause
      throw ArgumentError('Failed to load TFLite model "$modelAsset": $e');
    }
    final inputT = _interpreter!.getInputTensors().first;
    final shape = inputT.shape; // [1,H,W,3]
    if (shape.length >= 3) _inputSize = shape[1];
    // Robust quant detection without referencing enum constants
    try {
      final s = inputT.type.toString().toLowerCase();
      _isQuant = !s.contains('float');
    } catch (_) { _isQuant = true; }
    // Load labels
    try {
      final labelsTxt = await rootBundle.loadString(labelsAsset);
      _labels = labelsTxt
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      _labels = [];
    }

    // Optionally load feature extractor
    if (extractorAsset != null && extractorAsset.isNotEmpty) {
      try {
        final fxData = await rootBundle.load(extractorAsset);
        final fxBytes = fxData.buffer.asUint8List();
        final options = InterpreterOptions()
          ..threads = 2
          ..useNnApiForAndroid = false;
        _embedder = Interpreter.fromBuffer(fxBytes, options: options);
      } catch (e) {
        // Keep app running even if embedder is unavailable
        _embedder = null;
      }
    }

    _initialized = true;
  }

  Future<List<Map<String, dynamic>>> classify(Uint8List bytes, {int topK = 3}) async {
    final probs = await predictProbs(bytes);
    final pairs = <Map<String, dynamic>>[];
    for (int i = 0; i < probs.length; i++) {
      final name = (i < _labels.length && _labels[i].isNotEmpty) ? _labels[i] : 'Class $i';
      pairs.add({'label': name, 'score': probs[i]});
    }
    pairs.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return pairs.take(topK).toList();
  }

  // Returns the full probability vector in model order. If the model outputs logits
  // or unnormalized scores, we apply softmax to get probabilities.
  Future<List<double>> predictProbs(Uint8List bytes) async {
    if (_interpreter == null) throw StateError('Interpreter not initialized');
    final img.Image? base = img.decodeImage(bytes);
    if (base == null) throw StateError('Invalid image');
    final img.Image resized = img.copyResize(base, width: _inputSize, height: _inputSize, interpolation: img.Interpolation.linear);

    final intSize = _inputSize;
    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);

    int p = 0;
    final inputTensor = List.generate(1, (_) =>
        List.generate(intSize, (_) =>
            List.generate(intSize, (_) =>
                List.generate(3, (_) => _isQuant ? rgb[p++] : (rgb[p++] / 255.0)))));

    final outputT = _interpreter!.getOutputTensors().first;
    final numLabels = outputT.shape.last;
    final outputTensor = _isQuant
        ? List.generate(1, (_) => List<int>.filled(numLabels, 0))
        : List.generate(1, (_) => List<double>.filled(numLabels, 0.0));

    _interpreter!.run(inputTensor, outputTensor);

    final raw = List<double>.generate(
      numLabels,
      (i) => _isQuant ? (outputTensor[0][i] as int).toDouble() : (outputTensor[0][i] as double),
    );
    final double sum = raw.fold(0.0, (a, b) => a + b);
    // If already looks like probabilities, return; else softmax
    if (sum > 0.98 && sum < 1.02 && raw.every((v) => v >= 0.0 && v <= 1.0)) {
      return raw;
    }
    return _softmax(raw);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _embedder?.close();
    _embedder = null;
    _initialized = false;
  }

  // Generate an embedding using the optional feature extractor. Returns empty list if unavailable.
  Future<List<double>> getEmbedding(Uint8List bytes) async {
    final fx = _embedder;
    if (fx == null) return <double>[];
    final img.Image? base = img.decodeImage(bytes);
    if (base == null) return <double>[];
    final img.Image resized = img.copyResize(base, width: _inputSize, height: _inputSize, interpolation: img.Interpolation.linear);

    final intSize = _inputSize;
    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);
    int p = 0;
    final inputTensor = List.generate(1, (_) =>
        List.generate(intSize, (_) =>
            List.generate(intSize, (_) =>
                List.generate(3, (_) => _isQuant ? rgb[p++] : (rgb[p++] / 255.0)))));

    final outT = fx.getOutputTensors().first;
    final outLen = outT.shape.last;
    // Assume embedder outputs float32 (common). If quantized, we still treat as numbers and skip /255.
    final output = List.generate(1, (_) => List<double>.filled(outLen, 0.0));

    fx.run(inputTensor, output);

    // Return as doubles
    return List<double>.generate(outLen, (i) => output[0][i]);
  }

  // Softmax utility for normalization
  List<double> _softmax(List<double> x) {
    if (x.isEmpty) return x;
    final m = x.reduce((a, b) => a > b ? a : b);
    final exps = x.map((v) => math.exp(v - m)).toList();
    final s = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / (s + 1e-10)).toList();
  }
}
