import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
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
      _interpreter = await Interpreter.fromBuffer(modelBytes, options: options);
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
        _embedder = await Interpreter.fromBuffer(fxBytes, options: options);
      } catch (e) {
        // Keep app running even if embedder is unavailable
        _embedder = null;
      }
    }

    _initialized = true;
  }

  Future<List<Map<String, dynamic>>> classify(Uint8List bytes, {int topK = 3}) async {
    if (_interpreter == null) throw StateError('Interpreter not initialized');
    final img.Image? base = img.decodeImage(bytes);
    if (base == null) throw StateError('Invalid image');
    final img.Image resized = img.copyResize(base, width: _inputSize, height: _inputSize, interpolation: img.Interpolation.linear);

    final intSize = _inputSize;
    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);

    // Build input as nested lists [1,H,W,3]
    int p = 0;
    final inputTensor = List.generate(1, (_) =>
        List.generate(intSize, (_) =>
            List.generate(intSize, (_) =>
                List.generate(3, (_) => _isQuant ? rgb[p++] : (rgb[p++] / 255.0)))));

    // Prepare output [1,N]
    final outputT = _interpreter!.getOutputTensors().first;
    final numLabels = outputT.shape.last;
    final outputTensor = _isQuant
        ? List.generate(1, (_) => List<int>.filled(numLabels, 0))
        : List.generate(1, (_) => List<double>.filled(numLabels, 0.0));

    _interpreter!.run(inputTensor, outputTensor);

    // Convert to doubles and topK
    final scores = List<double>.generate(
      numLabels,
      (i) => _isQuant ? (outputTensor[0][i] as int) / 255.0 : (outputTensor[0][i] as double),
    );
    final pairs = <Map<String, dynamic>>[];
    for (int i = 0; i < numLabels; i++) {
      final name = (i < _labels.length && _labels[i].isNotEmpty) ? _labels[i] : 'Class $i';
      pairs.add({'label': name, 'score': scores[i]});
    }
    pairs.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return pairs.take(topK).toList();
  }

  // Returns the full probability/logit-like scores as doubles in model order
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

    return List<double>.generate(
      numLabels,
      (i) => _isQuant ? (outputTensor[0][i] as int) / 255.0 : (outputTensor[0][i] as double),
    );
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
    final output = _isQuant
        ? List.generate(1, (_) => List<int>.filled(outLen, 0))
        : List.generate(1, (_) => List<double>.filled(outLen, 0.0));

    fx.run(inputTensor, output);

    // Return as doubles
    return List<double>.generate(
      outLen,
      (i) => _isQuant ? (output[0][i] as int) / 255.0 : (output[0][i] as double),
    );
  }
}
