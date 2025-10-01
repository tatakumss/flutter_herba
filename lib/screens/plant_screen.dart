import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/tflite_service.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/scan_history_service.dart';
import '../services/ood_service.dart';
import 'package:image/image.dart' as img;
import '../services/collection_service.dart';

class PlantScreen extends StatefulWidget {
  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> with WidgetsBindingObserver {
  Uint8List? _previewBytes;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  final _picker = ImagePicker();
  final _tflite = TFLiteService();
  final _ood = OODService();
  CameraController? _cameraController;
  bool _flashOn = false;
  final _history = ScanHistoryService();
  final _collections = CollectionService();

  // Runtime model selection (V1/V2)
  final List<Map<String, String>> _modelOptions = const [
    {
      'key': 'v1',
      'name': 'Model V1',
      'model': 'assets/models/herbal_classifier.tflite',
      'labels': 'assets/models/class_labels.txt',
      'extractor': 'assets/models/feature_extractor.tflite',
      'ood': 'assets/models/complete_ood_stats.json',
    },
    {
      'key': 'kaggle',
      'name': 'Model Kaggle',
      'model': 'assets/models/kaggle_herbal_classifier.tflite',
      'labels': 'assets/models/kaggle_class_labels.txt',
      'extractor': 'assets/models/kaggle_feature_extractor.tflite',
      'ood': 'assets/models/kaggle_complete_ood_stats.json',
    },
  ];
  String _selectedModelKey = 'v1';

  // Last scan context for saving to collection
  String _lastLabel = 'Unknown';
  double _lastConfidence = 0.0;
  bool _lastIsOod = false;
  List<Map<String, dynamic>> _lastCandidates = const [];
  bool _savedToCollection = false;
  String? _oodReason; // e.g., LOW_CONFIDENCE, HUMAN_DETECTED, etc.
  double? _oodConf;
  double? _oodScore;
  double? _skinRatio;
  double? _edgeDensity;
  double? _greenRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initModel();
    _initCamera();
    // Load OOD profile for selected model; non-blocking
    _loadOodProfileForSelectedModel();
    // Temporarily disable auto tutorial to avoid blocking UI interactions
    // You can open it anytime via the help icon in the header.
    // _maybeShowTutorial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tflite.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Release camera when app goes to background to avoid freezes on return
      ctrl.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app resumes
      _initCamera();
    }
  }

  Future<void> _switchModel(String key) async {
    if (_selectedModelKey == key) return;
    setState(() { _selectedModelKey = key; _loading = true; _results = []; _error = null; });
    try {
      // Re-init TFLite with new assets
      _tflite.dispose();
      await _initModel();
      await _loadOodProfileForSelectedModel();
      // Reset OOD state
      _oodReason = null; _oodConf = null; _oodScore = null; _skinRatio = null; _edgeDensity = null; _greenRatio = null;
      // Re-run classification on the last preview if available
      if (_previewBytes != null) {
        await _classify(_previewBytes!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Model switch failed: $e'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model switch failed: $e')),
      );
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _initModel() async {
    try {
      final cfg = _modelOptions.firstWhere((m) => m['key'] == _selectedModelKey, orElse: () => _modelOptions.first);
      await _tflite.init(
        modelAsset: cfg['model']!,
        labelsAsset: cfg['labels']!,
        extractorAsset: cfg['extractor']!,
      );
    } catch (e) {
      if (!mounted) return;
      // Debug: surface the exact error in the console for troubleshooting
      // ignore: avoid_print
      print('TFLite init error: $e');
      // Also show on UI so it's visible without console
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TFLite init error: $e')),
      );
      setState(() { _error = 'Model or labels not found. Ensure assets/models/herbal_classifier.tflite and assets/models/class_labels.txt exist and are listed in pubspec.yaml.'; });
    }
  }

  Future<void> _loadOodProfileForSelectedModel() async {
    try {
      final cfg = _modelOptions.firstWhere((m) => m['key'] == _selectedModelKey, orElse: () => _modelOptions.first);
      final oodAsset = cfg['ood'];
      if (oodAsset != null && oodAsset.isNotEmpty) {
        await _ood.load(oodAsset);
      }
    } catch (_) {
      // ignore OOD load errors; classification still works
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.isNotEmpty ? cams.first : throw Exception('No camera available'),
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _cameraController = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Camera not available: $e'; });
    }
  }

  Future<void> _maybeShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'seen_plant_tutorial_v1';
      final seen = prefs.getBool(key) ?? false;
      if (!seen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTutorial();
        });
        await prefs.setBool(key, true);
      }
    } catch (_) {
      // ignore storage errors
    }
  }

  void _showTutorial() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'How to scan plants',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Position the plant in the camera frame.\n'
                      '2. Ensure good lighting and keep the camera steady.\n'
                      '3. Tap "Capture Plant" to take a photo and analyze it.\n'
                      '4. Or use "Gallery" to pick an existing photo.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'What the results mean',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• Top matches: the most likely plant names.\n'
                      '• Bars and percentages show confidence (capped at 85% to avoid false certainty).\n'
                      '• This is a best guess based on visual features — always double-check important identifications.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      if (!_tflite.isInitialized) {
        await _initModel();
      }
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _previewBytes = bytes;
        _results = [];
        _error = null;
      });
      if (_tflite.isInitialized) {
        await _classify(bytes);
      } else {
        if (!mounted) return;
        setState(() { _error = 'Model not loaded. Ensure assets/models/herbal_classifier_quantized.tflite and assets/models/phase1_labels.txt exist.'; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
    }
  }

  Future<void> _captureAndClassify() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initCamera();
      }
      if (!_tflite.isInitialized) {
        await _initModel();
      }
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        setState(() { _error = 'Camera not initialized'; });
        return;
      }
      final pic = await _cameraController!.takePicture();
      final bytes = await pic.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _results = [];
        _error = null;
      });
      await _classify(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Capture failed: $e'; });
    }
  }

  Future<void> _classify(Uint8List bytes) async {
    if (!_tflite.isInitialized) return;
    setState(() {
      _loading = true;
      _results = [];
      _error = null;
      _savedToCollection = false;
      _oodReason = null;
      _oodConf = null;
      _oodScore = null;
      _skinRatio = null;
      _edgeDensity = null;
      _greenRatio = null;
    });
    try {
      // 1) Classify top-K (for UI)
      final topKRes = await _tflite.classify(bytes, topK: 3);
      // Reduce noise: omit Top-3 console print

      // 2) Prepare inputs for full OOD pipeline
      //    a) Full probability vector
      final probs = await _tflite.predictProbs(bytes);
      //    b) Embedding
      final emb = await _tflite.getEmbedding(bytes);
      //    c) Resized RGB 224 image for visual checks
      final decoded = img.decodeImage(bytes);
      final resized = decoded != null ? img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.linear) : null;

      // 3) Evaluate OOD if possible
      bool isOod = false;
      double oodScore = 0.0;
      double calibratedConf = 0.0;
      String? rejReason;
      if (resized != null && probs.isNotEmpty && emb.isNotEmpty) {
        final ev = _ood.evaluate(resizedRgb224: resized, probs: probs, embedding: emb);
        isOod = (ev['isOOD'] == true);
        oodScore = (ev['oodScore'] is num) ? (ev['oodScore'] as num).toDouble() : 0.0;
        calibratedConf = (ev['calibratedConfidence'] is num) ? (ev['calibratedConfidence'] as num).toDouble() : 0.0;
        final rr = ev['rejectionReason'];
        rejReason = (rr is String && rr.trim().isNotEmpty) ? rr.trim() : null;
        final skinRatio = (ev['skinRatio'] is num) ? (ev['skinRatio'] as num).toDouble() : null;
        final edgeDensity = (ev['edgeDensity'] is num) ? (ev['edgeDensity'] as num).toDouble() : null;
        final greenRatio = (ev['greenRatio'] is num) ? (ev['greenRatio'] as num).toDouble() : null;
        _oodConf = calibratedConf;
        _oodScore = oodScore;
        _skinRatio = skinRatio;
        _edgeDensity = edgeDensity;
        _greenRatio = greenRatio;
        // Single concise debugPrint
        // ignore: avoid_print
        debugPrint('[OOD] reason=${rejReason ?? 'null'} conf=${calibratedConf.toStringAsFixed(3)} ood=${oodScore.toStringAsFixed(3)}'
            '${skinRatio != null ? ' skin=${skinRatio.toStringAsFixed(3)}' : ''}'
            '${edgeDensity != null ? ' edge=${edgeDensity.toStringAsFixed(3)}' : ''}'
            '${greenRatio != null ? ' green=${greenRatio.toStringAsFixed(3)}' : ''}');
      }

      // 4) Final results for UI: hide predictions for hard OOD reasons
      List<Map<String, dynamic>> finalRes = topKRes;
      final hardReasons = {'HUMAN_DETECTED', 'NON_PLANT_VISUAL', 'STATISTICAL_OOD'};
      final hardOod = (rejReason != null) && hardReasons.contains(rejReason);
      if (hardOod) {
        finalRes = [ {'label': 'Unknown', 'score': 0.0} ];
      }

      if (!mounted) return;
      setState(() { _results = finalRes; _oodReason = rejReason; });

      // 5) Persist to history (mark as OOD when hard rejection)
      final top = finalRes.isNotEmpty ? finalRes.first : null;
      if (top != null) {
        final label = (top['label'] ?? 'Unknown').toString();
        final score = (top['score'] is num) ? (top['score'] as num).toDouble() : 0.0;
        final candidates = finalRes.take(3).map<Map<String, dynamic>>((e) {
          final l = (e['label'] ?? '').toString();
          final s = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
          return {'label': l, 'score': s, 'oodSim': hardOod ? oodScore : null};
        }).toList();
        // Save to local state for Save-to-Collection
        _lastLabel = label;
        _lastConfidence = hardOod ? 0.0 : (calibratedConf > 0 ? calibratedConf : score);
        _lastIsOod = hardOod;
        _lastCandidates = candidates;
        await _history.add(
          ScanEntry(
            name: label,
            confidence: hardOod ? 0.0 : (calibratedConf > 0 ? calibratedConf : score),
            timestamp: DateTime.now(),
            success: !hardOod,
            candidates: candidates,
            isOod: hardOod,
            oodSim: hardOod ? oodScore : null,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _toggleFlash() async {
    try {
      final ctrl = _cameraController;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      _flashOn = !_flashOn;
      await ctrl.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Flash not available: $e'; });
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Plant Scanner",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF81C784)
                          : AppConfig.primaryDark,
                    ),
                  ),
                  Row(children: [
                    // Model selector
                    PopupMenuButton<String>(
                      tooltip: 'Select model',
                      onSelected: (k) => _switchModel(k),
                      itemBuilder: (ctx) => _modelOptions.map((m) {
                        final key = m['key']!;
                        final name = m['name']!;
                        return PopupMenuItem<String>(
                          value: key,
                          child: Row(
                            children: [
                              if (_selectedModelKey == key)
                                const Icon(Icons.check, size: 16)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(name),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, size: 18),
                            const SizedBox(width: 6),
                            Text(_modelOptions.firstWhere((m) => m['key'] == _selectedModelKey, orElse: () => _modelOptions.first)['name']!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                    onTap: _showTutorial,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.help_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    ),
                  ]),
                ],
              ),
            ),
            
            // Camera Preview Area
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.10),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.30),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_cameraController != null && _cameraController!.value.isInitialized)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else if (_previewBytes != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.memory(
                            _previewBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Position plant in frame",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF81C784)
                                    : AppConfig.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Make sure the plant is well-lit\nand clearly visible",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Corner guides
                    Positioned(
                      top: 20,
                      left: 20,
                      child: _buildCornerGuide(true, true),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: _buildCornerGuide(true, false),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: _buildCornerGuide(false, true),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: _buildCornerGuide(false, false),
                    ),
                    if (_loading)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                    if (_error != null)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildResultCard([
                          {'label': 'Error', 'score': 0.0},
                          {'label': _error, 'score': 0.0},
                        ]),
                      )
                    else if (_results.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildResultCard(_results),
                      ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                    // Primary Action - Camera
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _captureAndClassify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 24, color: Theme.of(context).colorScheme.onPrimary),
                            const SizedBox(width: 12),
                            Text(
                              "Capture Plant",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Secondary Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: _pickFromGallery,
                              icon: Icon(
                                Icons.photo_library_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                "Gallery",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: _toggleFlash,
                              icon: Icon(
                                Icons.flash_on_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                "Flash",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerGuide(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          left: isLeft ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          right: !isLeft ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildResultCard(List<Map<String, dynamic>> results) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final percentStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    final isUnknown = results.isNotEmpty && (results.first['label']?.toString().toLowerCase() == 'unknown');
    final lowConfidence = _oodReason == 'LOW_CONFIDENCE' && !isUnknown;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnknown)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_gmailerrorred_outlined, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Only show plain 'Unknown' for HUMAN_DETECTED so the app presents just 'plants' or 'Unknown'.
                      _oodReason == 'HUMAN_DETECTED'
                        ? 'Unknown'
                        : (
                            'Unknown' + (_oodReason != null ? ' (${_oodReason})' : '') +
                            '. ' +
                            (_oodConf != null ? 'conf ${_oodConf!.toStringAsFixed(2)}  ' : '') +
                            (_oodScore != null ? 'ood ${_oodScore!.toStringAsFixed(2)}  ' : '') +
                            (_skinRatio != null ? 'skin ${_skinRatio!.toStringAsFixed(2)}  ' : '') +
                            (_edgeDensity != null ? 'edge ${_edgeDensity!.toStringAsFixed(2)}  ' : '') +
                            (_greenRatio != null ? 'green ${_greenRatio!.toStringAsFixed(2)}' : '')
                          ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange[800], fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          // Save to Collection action + Saved badge
          Row(
            children: [
              if (_savedToCollection)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Saved', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await _collections.saveScan(
                      name: _lastLabel,
                      confidence: _lastConfidence,
                      isOod: _lastIsOod,
                      candidates: _lastCandidates,
                    );
                    if (!mounted) return;
                    setState(() { _savedToCollection = true; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to your collection')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Save failed: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save to collection'),
              ),
            ],
          ),
          Text('Top matches', style: titleStyle),
          const SizedBox(height: 4),
          Text(
            'Best guess based on visual features',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7), fontWeight: FontWeight.w500) ?? const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final item in results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (item['label'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        // Cap visual confidence at 85%
                        value: (item['score'] is num)
                            ? ((item['score'] as num).toDouble().clamp(0.0, 1.0)).clamp(0.0, 0.85)
                            : 0.0,
                        minHeight: 8,
                        backgroundColor: theme.dividerColor.withOpacity(0.25),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    // Cap displayed percent at 85%
                    () {
                      final v = (item['score'] is num) ? ((item['score'] as num).toDouble()) : 0.0;
                      final capped = v.clamp(0.0, 0.85) as double;
                      return '${(capped * 100).toStringAsFixed(0)}%';
                    }(),
                    style: percentStyle,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  builder: (ctx) {
                    final controller = TextEditingController();
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Report Error', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Describe what looks incorrect...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thanks for the feedback!')),
                                  );
                                },
                                child: const Text('Submit'),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Text('Report error'),
            ),
          ),
        ],
      ),
    );
  }
}
