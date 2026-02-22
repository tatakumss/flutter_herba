// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps, unused_local_variable

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert' as convert;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../utils/snackbar_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../services/tflite_service.dart';
import '../services/scan_history_service.dart';
import '../services/ood_service.dart';
import 'package:image/image.dart' as img;
import '../services/collection_service.dart';
import '../services/feedback_service.dart';
import '../services/scan_service.dart';
import '../widgets/feedback_action_button.dart';
import '../widgets/app_text_field.dart';

class PlantScreen extends StatefulWidget {
  const PlantScreen({super.key});

  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> with WidgetsBindingObserver {
  Uint8List? _previewBytes;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _resultsA = [];
  List<Map<String, dynamic>> _resultsB = [];
  bool _resultsCollapsed = false;
  bool _loading = false;
  String? _error;

  final _picker = ImagePicker();
  final _tflite = TFLiteService.create();
  TFLiteService? _tfliteB; // used only for combo
  final _ood = OODService();
  final _oodKaggle = OODService();
  CameraController? _cameraController;
  bool _flashOn = false;
  bool _didAutoOnce = false;
  // Disable auto first-capture to avoid showing results before user acts
  final bool _enableAutoOnce = false;
  final _history = ScanHistoryService();
  final _collections = CollectionService();
  final _feedback = FeedbackService();
  final _scanService = ScanService();
  
  // Current scan ID for linking reports
  String? _currentScanId;
  
  // Track if feedback has been submitted to prevent duplicates
  bool _feedbackSubmitted = false;
  
  // Track which plant is marked as correct
  int? _selectedCorrectPlantIndex;

  // Model configuration for dataset assessment (combo mode only)
  final List<Map<String, String>> _modelOptions = const [
    {
      'key': 'mendeley',
      'name': 'Mendeley',
      'model': 'assets/models/herbal_classifier.tflite',
      'labels': 'assets/models/class_labels.txt',
      'extractor': 'assets/models/feature_extractor.tflite',
      'ood': 'assets/models/complete_ood_stats.json',
    },
    {
      'key': 'kaggle',
      'name': 'Kaggle',
      'model': 'assets/models/kaggle_herbal_classifier.tflite',
      'labels': 'assets/models/kaggle_class_labels.txt',
      'extractor': 'assets/models/kaggle_feature_extractor.tflite',
      'ood': 'assets/models/kaggle_complete_ood_stats.json',
    },
  ];
  // Always use combo mode for dataset assessment
  final String _selectedModelKey = 'combo';
  
  // Track capture state and OOD detection
  bool _hasTriedCapture = false;
  String? _oodReason;
  double? _oodScore;
  double? _skinRatio;
  double? _edgeDensity;
  double? _greenRatio;

  // Last scan context for saving to collection
  String _lastLabel = 'Unknown';
  double _lastConfidence = 0.0;
  bool _lastIsOod = false;
  List<Map<String, dynamic>> _lastCandidates = const [];
  bool _savedToCollection = false;
  String? _preferredDataset; // 'mendeley' | 'kaggle'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reset any previous preview/results so no results panel shows until user acts
    _hasTriedCapture = false;
    _previewBytes = null;
    _results = [];
    _resultsA = [];
    _resultsB = [];
    _error = null;
    _initModel();
    _initCamera();
    // Load OOD profile for selected model; non-blocking
    _loadOodProfileForSelectedModel();
    // Temporarily disable auto tutorial to avoid blocking UI interactions
    // You can open it anytime via the help icon in the header.
    // _maybeShowTutorial();
  }

  Future<void> _toggleFlash() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      if (!mounted) return;
      SnackBarUtils.showWarning(context, 'Camera not ready');
      return;
    }
    try {
      final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await ctrl.setFlashMode(newMode);
      if (!mounted) return;
      setState(() {
        _flashOn = !_flashOn;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Flash not available: $e');
    }
  }

  Widget _buildResultCardCombo(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    final theme = Theme.of(context);
    
    // Combine and deduplicate results from both models
    final combinedResults = <String, Map<String, dynamic>>{};
    
    // Helper to add results to the combined map
    void addResults(List<Map<String, dynamic>> results, String source) {
      for (final result in results) {
        final label = (result['label'] ?? '').toString();
        if (label.isEmpty) continue;
        
        final score = (result['score'] is num) ? (result['score'] as num).toDouble() : 0.0;
        final prev = (combinedResults[label]?['score'] is num)
            ? (combinedResults[label]?['score'] as num).toDouble()
            : 0.0;
        if (!combinedResults.containsKey(label) || (prev < score)) {
          combinedResults[label] = {
            'label': label,
            'score': score,
            'source': source,
          };
        }
      }
    }
    
    // Add results from both models
    addResults(a, 'Mendeley');
    addResults(b, 'Kaggle');
    
    // Sort by score
    final sortedResults = combinedResults.values.toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    // Take top 3 results
    final topResults = sortedResults.take(3).toList();
    
    // Build a read-only result item (no checkbox)
    Widget buildResultItem(Map<String, dynamic> result, int index) {
      final label = result['label'] as String;
      final score = (result['score'] as num).toDouble();
      final source = result['source'] as String? ?? 'Unknown';
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!, width: 1.0),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
                        ),
                        child: Text(
                          source,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(score * 100).toStringAsFixed(1)}% confidence • $source',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (index == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Text(
                  'Top match',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

<<<<<<< HEAD
    return ConstrainedBox(
      constraints: BoxConstraints(
        // cap card height so it fits above bottom controls; scroll if overflow
        maxHeight: MediaQuery.of(context).size.height * (_resultsCollapsed ? 0.22 : 0.55),
=======
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConfig.shadowColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              const Text(
                'Identification Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _resultsCollapsed ? 'Expand' : 'Minimize',
                icon: Icon(_resultsCollapsed ? Icons.unfold_more : Icons.unfold_less),
                onPressed: () {
                  setState(() { _resultsCollapsed = !_resultsCollapsed; });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_resultsCollapsed) ...topResults.asMap().entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            return buildResultItem(result, index);
          }).toList(),
          const SizedBox(height: 12),
          if (_resultsCollapsed) const SizedBox.shrink(),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                // Save action (mirrors single card)
                Row(
                  children: [
                    if (_savedToCollection)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
<<<<<<< HEAD
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.4)),
=======
                          color: AppConfig.getSuccessWithOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConfig.getSuccessWithOpacity(0.4)),
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_outline, size: 16, color: AppConfig.successColor),
                            SizedBox(width: 4),
                            Text('Saved', style: TextStyle(color: AppConfig.successColor, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const Spacer(),
<<<<<<< HEAD
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          if (_preferredDataset == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select which dataset performed better (Mendeley or Kaggle).')),
                            );
                            return;
                          }

                          if (_previewBytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nothing to save: capture or pick an image first.')),
                            );
                            return;
                          }

                          // Compare with per-dataset top-1 and warn if mismatch
                          double? mTop;
                          double? kTop;
                          if (_resultsA.isNotEmpty && (_resultsA.first['score'] is num)) {
                            mTop = (_resultsA.first['score'] as num).toDouble();
                          }
                          if (_resultsB.isNotEmpty && (_resultsB.first['score'] is num)) {
                            kTop = (_resultsB.first['score'] as num).toDouble();
                          }
                          if (mTop != null && kTop != null && _preferredDataset != 'both') {
                            final autoPref = (mTop >= kTop) ? 'mendeley' : 'kaggle';
                            if (_preferredDataset != autoPref) {
                              final keep = await showDialog<String>(
                                context: context,
                                barrierDismissible: true,
                                builder: (ctx) {
                                  final autoTitle = autoPref == 'mendeley' ? 'Mendeley' : 'Kaggle';
                                  final otherTitle = _preferredDataset == 'mendeley' ? 'Mendeley' : 'Kaggle';
                                  return AlertDialog(
                                    title: const Text('Confirm dataset preference'),
                                    content: Text(
                                      '$autoTitle has higher confidence (${((autoPref == 'mendeley' ? mTop : kTop)!*100).toStringAsFixed(0)}% vs ${((autoPref == 'mendeley' ? kTop : mTop)!*100).toStringAsFixed(0)}%).\nKeep $otherTitle as preferred?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop('cancel'),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop('switch'),
                                        child: Text('Switch to $autoTitle'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(ctx).pop('keep'),
                                        child: Text('Keep $otherTitle'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (keep == 'cancel') return;
                              if (keep == 'switch') {
                                setState(() { _preferredDataset = autoPref; });
                              }
                            }
                          }
                          
                          // Use the selected dataset's top-1 as the chosen plant
                          String chosenLabel = _lastLabel;
                          double chosenConf = _lastConfidence;
                          if (_preferredDataset == 'mendeley' && a.isNotEmpty) {
                            chosenLabel = (a.first['label'] ?? 'Unknown').toString();
                            chosenConf = (a.first['score'] is num) ? (a.first['score'] as num).toDouble() : chosenConf;
                          } else if (_preferredDataset == 'kaggle' && b.isNotEmpty) {
                            chosenLabel = (b.first['label'] ?? 'Unknown').toString();
                            chosenConf = (b.first['score'] is num) ? (b.first['score'] as num).toDouble() : chosenConf;
                          } else if (_preferredDataset == 'both') {
                            // When both are selected, choose the higher top-1 for saving while recording 'both'
                            if (a.isNotEmpty && b.isNotEmpty) {
                              final aTop = (a.first['score'] is num) ? (a.first['score'] as num).toDouble() : 0.0;
                              final bTop = (b.first['score'] is num) ? (b.first['score'] as num).toDouble() : 0.0;
                              final useA = aTop >= bTop;
                              final pick = useA ? a.first : b.first;
                              chosenLabel = (pick['label'] ?? 'Unknown').toString();
                              chosenConf = (pick['score'] is num) ? (pick['score'] as num).toDouble() : chosenConf;
                            } else if (a.isNotEmpty) {
                              chosenLabel = (a.first['label'] ?? 'Unknown').toString();
                              chosenConf = (a.first['score'] is num) ? (a.first['score'] as num).toDouble() : chosenConf;
                            } else if (b.isNotEmpty) {
                              chosenLabel = (b.first['label'] ?? 'Unknown').toString();
                              chosenConf = (b.first['score'] is num) ? (b.first['score'] as num).toDouble() : chosenConf;
                            }
                          }

                          // Build image and candidates
                          final imgB64 = convert.base64Encode(_previewBytes!);
                          final cands = topResults.map((c) => {
                            'label': c['label'] ?? 'Unknown',
                            'score': c['score'] ?? 0.0,
                          }).toList();
                          
                          final plantData = {
                            'plantName': chosenLabel,
                            'imageData': imgB64,
                            'isFavorite': false,
                            'confidence': chosenConf,
                            // Persist selection metadata
                            'selectedLabel': chosenLabel,
                            'selectedConfidence': chosenConf,
                            'selectedFrom': 'combo',
                            if (_preferredDataset != null) 'preferredDataset': _preferredDataset,
                            'isOod': (_oodReason == 'HUMAN_DETECTED' || _oodReason == 'NON_PLANT_VISUAL' || _oodReason == 'STATISTICAL_OOD'),
                            'oodReason': _oodReason,
                            'oodScore': _oodScore,
                            'candidates': cands,
                            'scannedAt': DateTime.now().toIso8601String(),
                          };
                          
                          final success = await _collections.addToCollection(plantData);
                          if (!mounted) return;
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Saved to collection' : 'Save failed'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                          
                          if (success) {
                            setState(() { _savedToCollection = true; });
                            // Update local history for percentage stats
                            try {
                              await _history.updateLast(
                                preferredDataset: _preferredDataset,
                                mendeleyTop: mTop,
                                kaggleTop: kTop,
                              );
                            } catch (_) {}
                          }
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
                const SizedBox(height: 8),
                // Dataset selector
                Text('Which dataset performed better?', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mendeley', label: Text('Mendeley')),
                    ButtonSegment(value: 'kaggle', label: Text('Kaggle')),
                  ],
                  selected: () {
                    if (_preferredDataset == null) return <String>{};
                    if (_preferredDataset == 'both') return {'mendeley', 'kaggle'};
                    return {_preferredDataset!};
                  }(),
                  multiSelectionEnabled: true,
                  emptySelectionAllowed: true,
                  onSelectionChanged: (sel) {
                    setState(() {
                      if (sel.isEmpty) {
                        _preferredDataset = null;
                      } else if (sel.length == 2) {
                        _preferredDataset = 'both';
                      } else {
                        _preferredDataset = sel.first;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Feedback actions (responsive)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
                      child: TextButton.icon(
                        onPressed: () => _showFeedbackModal('error'),
                        icon: const Icon(Icons.report_problem_outlined, size: 16),
                        label: const Text('Report Error', overflow: TextOverflow.ellipsis),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
                      ),
=======
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        if (_previewBytes == null) {
                          SnackBarUtils.showWarning(context, 'Nothing to save: capture or pick an image first.');
                          return;
                        }
                        
                        // Create comprehensive plant data like the results section
                        final imgB64 = _previewBytes != null ? convert.base64Encode(_previewBytes!) : null;
                        final cands = _lastCandidates.map((c) => {
                          'label': c['label'] ?? 'Unknown',
                          'score': c['score'] ?? 0.0,
                        }).toList();
                        
                        final plantData = {
                          'plantName': _lastLabel,
                          'imageData': imgB64,
                          'isFavorite': false,
                          'confidence': _lastConfidence,
                          'isOod': (_oodReason == 'HUMAN_DETECTED' || _oodReason == 'NON_PLANT_VISUAL' || _oodReason == 'STATISTICAL_OOD'),
                          'oodReason': _oodReason,
                          'oodScore': _oodScore,
                          'candidates': cands,
                          'scannedAt': DateTime.now().toIso8601String(),
                        };
                        
                        final success = await _collections.addToCollection(plantData);
                        if (!mounted) return;
                        
                        if (success) {
                          SnackBarUtils.showSuccess(context, 'Saved to collection');
                        } else {
                          SnackBarUtils.showError(context, 'Save failed');
                        }
                        
                        if (success) {
                          setState(() { _savedToCollection = true; });
                        }
                      } catch (e) {
                        if (!mounted) return;
                        SnackBarUtils.showError(context, 'Save failed: $e');
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save to collection'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (ctx, c) {
                  final twoCols = c.maxWidth > 520;
                  if (twoCols) {
                    return Row(
                      children: [
                        Expanded(child: col('Mendeley', aTop, theme.colorScheme.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: col('Kaggle', bTop, const Color(0xFF66BB6A))),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      col('Mendeley', aTop, theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      col('Kaggle', bTop, const Color(0xFF66BB6A)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Feedback actions (responsive)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showFeedbackModal('error'),
                      icon: const Icon(Icons.report_problem_outlined, size: 16),
                      label: const Text('Report Error', overflow: TextOverflow.ellipsis),
                      style: TextButton.styleFrom(foregroundColor: AppConfig.reportErrorColor),
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showFeedbackModal('suggestion'),
                      icon: const Icon(Icons.lightbulb_outline, size: 16),
                      label: const Text('Suggest Improvement', overflow: TextOverflow.ellipsis),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
<<<<<<< HEAD
        ],
      ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tflite.dispose();
    _tfliteB?.dispose();
    super.dispose();
  }

  Future<void> _initModel() async {
    try {
      // Always use combo mode for dataset assessment
      // Init Mendeley model
      final mendeley = _modelOptions.firstWhere((m) => m['key'] == 'mendeley');
      await _tflite.init(
        modelAsset: mendeley['model']!,
        labelsAsset: mendeley['labels']!,
        extractorAsset: mendeley['extractor']!,
      );
      
      // Init Kaggle model
      _tfliteB = TFLiteService.create();
      final kaggle = _modelOptions.firstWhere((m) => m['key'] == 'kaggle');
      await _tfliteB!.init(
        modelAsset: kaggle['model']!,
        labelsAsset: kaggle['labels']!,
        extractorAsset: kaggle['extractor']!,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load model: $e';
        });
      }
      rethrow;
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
      }
      
      // Auto-capture first frame if enabled and this is the first time
      if (_enableAutoOnce && !_didAutoOnce) {
        _didAutoOnce = true;
        _autoClassifyOnce();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize camera: $e';
        });
      }
      rethrow;
    }
  }

  Future<void> _loadOodProfileForSelectedModel() async {
    try {
      // Always load both OOD profiles for dataset assessment
      final mCfg = _modelOptions.firstWhere((m) => m['key'] == 'mendeley');
      final kCfg = _modelOptions.firstWhere((m) => m['key'] == 'kaggle');
      
      if ((mCfg['ood'] ?? '').isNotEmpty) {
        await _ood.load(mCfg['ood']!);
      }
      
      if ((kCfg['ood'] ?? '').isNotEmpty) {
        await _oodKaggle.load(kCfg['ood']!);
      }
    } catch (e) {
      debugPrint('Failed to load OOD profile: $e');
      // Don't block the UI if OOD fails to load
    }
  }

  // Build model selector UI (simplified for dataset assessment mode)
  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assessment, size: 18),
          SizedBox(width: 6),
          Text('Dataset Assessment Mode'),
        ],
      ),
    );
  }

  Future<void> _submitDatasetFeedback(String selectedDataset) async {
    if (_currentScanId == null || _results.isEmpty || _feedbackSubmitted) return;
    
    setState(() {
      _feedbackSubmitted = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final plantIdentified = _results.isNotEmpty ? _results[0]['label'] : 'unknown';
      final confidence = _results.isNotEmpty ? _results[0]['score'] : 0.0;
      
      await FirebaseFirestore.instance.collection('dataset_feedback').add({
        'scanId': _currentScanId,
        'selectedDataset': selectedDataset,
        'rejectedDataset': selectedDataset == 'mendeley' ? 'kaggle' : 'mendeley',
        'plantIdentified': plantIdentified,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackSubmitted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
=======
          crossFadeState: _resultsCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    ),
  );
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _tflite.dispose();
  _tfliteB?.dispose();
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
    _tfliteB?.dispose();
    await _initModel();
    await _loadOodProfileForSelectedModel();
    // Reset OOD state
    _oodReason = null; _oodConf = null; _oodScore = null; _skinRatio = null; _edgeDensity = null; _greenRatio = null;
    // Re-run classification on the last preview if available
    if (_previewBytes != null) {
      await _classify(_previewBytes!);
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
    }
  } catch (e) {
    if (!mounted) return;
    setState(() { _error = 'Model switch failed: $e'; });
    SnackBarUtils.showError(context, 'Model switch failed: $e');
  } finally {
    if (mounted) setState(() { _loading = false; });
  }
}

<<<<<<< HEAD
=======
Future<void> _initModel() async {
  try {
    if (_selectedModelKey == 'combo') {
      // Init primary as V1
      final v1 = _modelOptions.firstWhere((m) => m['key'] == 'v1');
      await _tflite.init(
        modelAsset: v1['model']!,
        labelsAsset: v1['labels']!,
        extractorAsset: v1['extractor']!,
      );
      // Init secondary as Kaggle
      _tfliteB = TFLiteService.create();
      final kaggle = _modelOptions.firstWhere((m) => m['key'] == 'kaggle');
      await _tfliteB!.init(
        modelAsset: kaggle['model']!,
        labelsAsset: kaggle['labels']!,
        extractorAsset: kaggle['extractor']!,
      );
    } else {
      final cfg = _modelOptions.firstWhere((m) => m['key'] == _selectedModelKey, orElse: () => _modelOptions.first);
      await _tflite.init(
        modelAsset: cfg['model']!,
        labelsAsset: cfg['labels']!,
        extractorAsset: cfg['extractor']!,
      );
    }
  } catch (e) {
    if (!mounted) return;
    SnackBarUtils.showError(context, 'TFLite init error: $e');
    setState(() { _error = 'Model or labels not found. Ensure assets/models/herbal_classifier.tflite and assets/models/class_labels.txt exist and are listed in pubspec.yaml.'; });
  }
}

Future<void> _loadOodProfileForSelectedModel() async {
  try {
      if (_selectedModelKey == 'combo') {
        final mCfg = _modelOptions.firstWhere((m) => m['key'] == 'v1');
        final kCfg = _modelOptions.firstWhere((m) => m['key'] == 'kaggle');
        if ((mCfg['ood'] ?? '').isNotEmpty) {
          await _ood.load(mCfg['ood']!);
        }
        if ((kCfg['ood'] ?? '').isNotEmpty) {
          await _oodKaggle.load(kCfg['ood']!);
        }
      } else {
        final cfg = _modelOptions.firstWhere((m) => m['key'] == _selectedModelKey, orElse: () => _modelOptions.first);
        final oodAsset = cfg['ood'];
        if (oodAsset != null && oodAsset.isNotEmpty) {
          await _ood.load(oodAsset);
        }
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
      // Ensure torch is off on init and sync UI flag
      try { await controller.setFlashMode(FlashMode.off); } catch (_) {}
      if (!mounted) return;
      setState(() { _flashOn = false; });
      // Optionally run a one-time automatic classification; disabled by default
      if (_enableAutoOnce && !_didAutoOnce) {
        _didAutoOnce = true;
        Future.delayed(const Duration(milliseconds: 500), _autoClassifyOnce);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Camera not available: $e'; });
    }
  }

>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
  Future<void> _autoClassifyOnce() async {
    try {
      final ctrl = _cameraController;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      if (!_tflite.isInitialized && (_selectedModelKey != 'combo' || (_tfliteB == null || !_tfliteB!.isInitialized))) {
        await _initModel();
      }
      final pic = await ctrl.takePicture();
      final bytes = await pic.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _results = [];
        _resultsA = [];
        _resultsB = [];
        _error = null;
        _savedToCollection = false;
      });
      await _classify(bytes);
    } catch (_) {
      // Ignore auto errors; user can still tap Capture manually
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
      if (!_tflite.isInitialized || (_selectedModelKey == 'combo' && (_tfliteB == null || !_tfliteB!.isInitialized))) {
        await _initModel();
      }
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _hasTriedCapture = true;
        _previewBytes = bytes;
        _results = [];
        _error = null;
        _savedToCollection = false; // Reset save status for new image
      });
      if (_tflite.isInitialized && (_selectedModelKey != 'combo' || (_tfliteB != null && _tfliteB!.isInitialized))) {
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
      setState(() { _hasTriedCapture = true; });
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initCamera();
      }
      if (!_tflite.isInitialized || (_selectedModelKey == 'combo' && (_tfliteB == null || !_tfliteB!.isInitialized))) {
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
        _savedToCollection = false; // Reset save status for new image
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
      _resultsA = [];
      _resultsB = [];
      _error = null;
      _savedToCollection = false;
      _oodReason = null;
      _oodScore = null;
      _skinRatio = null;
      _edgeDensity = null;
      _greenRatio = null;
      _preferredDataset = null;
    });
    try {
      // 1) Classify top-K (for UI)
      List<Map<String, dynamic>> topKRes;
      List<double> probs = const [];
      List<double> emb = const [];
      bool usingPrimary = true; // which model feeds OOD

      if (_selectedModelKey == 'combo' && _tfliteB != null && _tfliteB!.isInitialized) {
        final aTop = await _tflite.classify(bytes, topK: 3);
        final bTop = await _tfliteB!.classify(bytes, topK: 3);
        // ignore: avoid_print
        print('[Combo] Mendeley top: ${aTop.map((e)=>'${e['label']}:${(e['score'] as num).toDouble().toStringAsFixed(3)}').join(', ')}');
        // ignore: avoid_print
        print('[Combo] Kaggle top: ${bTop.map((e)=>'${e['label']}:${(e['score'] as num).toDouble().toStringAsFixed(3)}').join(', ')}');

        // Pick better top score model for OOD inputs
        final aBest = aTop.isNotEmpty ? (aTop.first['score'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final bBest = bTop.isNotEmpty ? (bTop.first['score'] as num?)?.toDouble() ?? 0.0 : 0.0;
        usingPrimary = aBest >= bBest;

        // Merge unique labels by highest score
        final Map<String, double> merged = {};
        void addAll(List<Map<String, dynamic>> src) {
          for (final e in src) {
            final l = (e['label'] ?? '').toString();
            final s = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
            if (l.isEmpty) continue;
            if (!merged.containsKey(l) || s > merged[l]!) merged[l] = s;
          }
        }
        addAll(aTop);
        addAll(bTop);
        final mergedList = merged.entries
            .map((e) => {'label': e.key, 'score': e.value})
            .toList()
          ..sort((x, y) => (y['score'] as double).compareTo(x['score'] as double));

        // Ensure at least one from each model if available
        final List<Map<String, dynamic>> seeded = [];
        if (aTop.isNotEmpty) {
          seeded.add({
            'label': (aTop.first['label'] ?? '').toString(),
            'score': ((aTop.first['score'] as num?)?.toDouble() ?? 0.0),
            'src': 'mendeley',
          });
        }
        if (bTop.isNotEmpty) {
          // Prefer a Kaggle label that differs; else allow duplicate with suffix
          Map<String, dynamic>? pickB;
          for (final e in bTop) {
            final l = (e['label'] ?? '').toString();
            if (l.isEmpty) continue;
            if (!seeded.any((x) => x['label'] == l)) { pickB = e; break; }
          }
          pickB ??= bTop.first;
          final bLabel = (pickB['label'] ?? '').toString();
          final duplicate = seeded.any((x) => x['label'] == bLabel);
          seeded.add({
            'label': duplicate ? '$bLabel (Kaggle)' : bLabel,
            'score': ((pickB['score'] as num?)?.toDouble() ?? 0.0),
            'src': 'kaggle',
          });
        }
        for (final e in mergedList) {
          if (seeded.length >= 3) break;
          if (!seeded.any((x) => x['label'] == e['label'])) seeded.add(e);
        }
        // Sort by score for display
        seeded.sort((x, y) => (y['score'] as double).compareTo(x['score'] as double));
        topKRes = seeded.take(3).toList();

        // Prepare group displays (preserve original labels without suffixes)
        List<Map<String, dynamic>> normalize(List<Map<String, dynamic>> src) => src
            .map((e) => {
                  'label': (e['label'] ?? '').toString(),
                  'score': (e['score'] is num) ? (e['score'] as num).toDouble().clamp(0.0, 1.0) : 0.0,
                })
            .toList();
        _resultsA = normalize(aTop);
        _resultsB = normalize(bTop);

        // Collect both models' inputs for OOD
        final probsA = await _tflite.predictProbs(bytes);
        final embA = await _tflite.getEmbedding(bytes);
        final probsB = await _tfliteB!.predictProbs(bytes);
        final embB = await _tfliteB!.getEmbedding(bytes);
        // Default to using primary for downstream fields; we'll evaluate both below
        probs = usingPrimary ? probsA : probsB;
        emb = usingPrimary ? embA : embB;
      } else {
        topKRes = await _tflite.classify(bytes, topK: 3);
        probs = await _tflite.predictProbs(bytes);
        emb = await _tflite.getEmbedding(bytes);
      }
      // Reduce noise: omit Top-3 console print

      // 2) Prepare inputs for full OOD pipeline
      //    a) Full probability vector: prepared above
      //    b) Embedding: prepared above
      //    c) Resized RGB 224 image for visual checks
      final decoded = img.decodeImage(bytes);
      final resized = decoded != null ? img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.linear) : null;

      // 3) Evaluate OOD if possible
      bool isOod = false;
      double oodScore = 0.0;
      double calibratedConf = 0.0;
      String? rejReason;
      if (resized != null) {
        if (_selectedModelKey == 'combo' && _tfliteB != null && _tfliteB!.isInitialized) {
          final probsA = await _tflite.predictProbs(bytes);
          final embA = await _tflite.getEmbedding(bytes);
          final probsB = await _tfliteB!.predictProbs(bytes);
          final embB = await _tfliteB!.getEmbedding(bytes);
          final evA = _ood.evaluate(resizedRgb224: resized, probs: probsA, embedding: embA);
          final evB = _oodKaggle.evaluate(resizedRgb224: resized, probs: probsB, embedding: embB);
          final order = { 'HUMAN_DETECTED': 3, 'STATISTICAL_OOD': 2, 'LOW_CONFIDENCE': 1, null: 0 };
          final isA = (evA['isOOD'] as bool?) ?? false;
          final isB = (evB['isOOD'] as bool?) ?? false;
          isOod = isA || isB;
          final scoreA = (evA['oodScore'] as num?)?.toDouble() ?? 0.0;
          final scoreB = (evB['oodScore'] as num?)?.toDouble() ?? 0.0;
          oodScore = (scoreA >= scoreB) ? scoreA : scoreB;
          final rA = evA['rejectionReason']?.toString();
          final rB = evB['rejectionReason']?.toString();
          rejReason = (order[rA] ?? 0) >= (order[rB] ?? 0) ? rA : rB;
          final cA = (evA['calibratedConfidence'] as num?)?.toDouble() ?? 0.0;
          final cB = (evB['calibratedConfidence'] as num?)?.toDouble() ?? 0.0;
          calibratedConf = math.min(cA, cB);
          final pick = (order[rA] ?? 0) >= (order[rB] ?? 0) ? evA : evB;
          _skinRatio = (pick['skinRatio'] as num?)?.toDouble();
          _edgeDensity = (pick['edgeDensity'] as num?)?.toDouble();
          _greenRatio = (pick['greenRatio'] as num?)?.toDouble();
          _oodScore = oodScore;
          debugPrint('[OOD] combo: A={is:$isA, score:$scoreA, reason:$rA} B={is:$isB, score:$scoreB, reason:$rB} -> is:$isOod reason:$rejReason conf=${calibratedConf.toStringAsFixed(3)} ood=${oodScore.toStringAsFixed(3)}');
        } else if (probs.isNotEmpty && emb.isNotEmpty) {
          final ev = _ood.evaluate(resizedRgb224: resized, probs: probs, embedding: emb);
          isOod = (ev['isOOD'] == true);
          oodScore = (ev['oodScore'] is num) ? (ev['oodScore'] as num).toDouble() : 0.0;
          calibratedConf = (ev['calibratedConfidence'] is num) ? (ev['calibratedConfidence'] as num).toDouble() : 0.0;
          final rr = ev['rejectionReason'];
          rejReason = (rr is String && rr.trim().isNotEmpty) ? rr.trim() : null;
          final skinRatio = (ev['skinRatio'] is num) ? (ev['skinRatio'] as num).toDouble() : null;
          final edgeDensity = (ev['edgeDensity'] is num) ? (ev['edgeDensity'] as num).toDouble() : null;
          final greenRatio = (ev['greenRatio'] is num) ? (ev['greenRatio'] as num).toDouble() : null;
          _oodScore = oodScore;
          _skinRatio = skinRatio;
          _edgeDensity = edgeDensity;
          _greenRatio = greenRatio;
          debugPrint('[OOD] reason=${rejReason ?? 'null'} conf=${calibratedConf.toStringAsFixed(3)} ood=${oodScore.toStringAsFixed(3)}'
              '${skinRatio != null ? ' skin=${skinRatio.toStringAsFixed(3)}' : ''}'
              '${edgeDensity != null ? ' edge=${edgeDensity.toStringAsFixed(3)}' : ''}'
              '${greenRatio != null ? ' green=${greenRatio.toStringAsFixed(3)}' : ''}');
        }
        // Heuristic: flat/glossy green objects (e.g., appliances) often have
        // high green ratio but very low edge density and no skin. If OOD didn't
        // trigger, add a conservative NON_PLANT_VISUAL rule to avoid false plant IDs.
        if (!isOod) {
          final g = (_greenRatio ?? 0.0);
          final e = (_edgeDensity ?? 1.0);
          final s = (_skinRatio ?? 0.0);
          // Primary heuristic (uniform glossy green with very low edges and skin)
          final ruleA = (g > 0.48 && e < 0.20 && s < 0.25);
          // If the top guess is a leafy class, allow lower green and slightly higher edges when skin is near-zero
          final topLabel = (topKRes.isNotEmpty ? (topKRes.first['label'] ?? '').toString().toLowerCase() : '');
          final leafy = {'pandan','guava','banaba','tulsi','chakte','betel','calamansi'};
          final ruleB = (leafy.contains(topLabel) && g > 0.25 && e < 0.24 && s < 0.10);
          if (ruleA || ruleB) {
            isOod = true;
            rejReason = 'NON_PLANT_VISUAL';
            // Boost OOD score to a sensible floor; reduce confidence conservatively
            if (oodScore < 0.60) oodScore = 0.60;
            calibratedConf = math.min(calibratedConf, 0.20);
            _oodScore = oodScore;
            debugPrint('[OOD] heuristic NON_PLANT_VISUAL applied g=${g.toStringAsFixed(3)} e=${e.toStringAsFixed(3)} s=${s.toStringAsFixed(3)} top=$topLabel');
          }
        }
      }

      // 3b) Force OOD if a classifier predicts 'non_herbal' with sufficient score
      double maxNonHerbalScore(List<Map<String, dynamic>> src) {
        double best = 0.0;
        for (final e in src) {
          final l = (e['label'] ?? '').toString().toLowerCase();
          final s = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
          if (l == 'non_herbal' && s > best) best = s;
        }
        return best;
      }
      final nhA = maxNonHerbalScore(_resultsA);
      final nhB = maxNonHerbalScore(_resultsB);
      final nhMerged = maxNonHerbalScore(topKRes);
      final nonHerbalScore = [nhA, nhB, nhMerged].fold<double>(0.0, (p, c) => c > p ? c : p);
      // Flag OOD if 'non_herbal' is reasonably present, or modest with a weak top1
      const nonHerbalMin = 0.12; // lowered so 0.152 will trigger
      final top1Score = topKRes.isNotEmpty && (topKRes.first['score'] is num)
          ? (topKRes.first['score'] as num).toDouble()
          : 0.0;
      final weakTop1 = top1Score < 0.65;
      if (nonHerbalScore >= nonHerbalMin || (nonHerbalScore >= 0.08 && weakTop1)) {
        isOod = true;
        rejReason = 'NON_PLANT_VISUAL';
        if (oodScore < 0.60) oodScore = 0.60;
        calibratedConf = math.min(calibratedConf, 0.20);
        _oodScore = oodScore;
      }

      // 4) Final results for UI: hide predictions for hard OOD reasons
      List<Map<String, dynamic>> finalRes = topKRes;
      final hardReasons = {'HUMAN_DETECTED', 'NON_PLANT_VISUAL', 'STATISTICAL_OOD'};
      final hardOod = (rejReason != null) && hardReasons.contains(rejReason);
      if (hardOod) {
        finalRes = [ {'label': 'Unknown', 'score': 0.0} ];
      }

      if (!mounted) return;

      // Prepare top result and candidates before setState
      final top = finalRes.isNotEmpty ? finalRes.first : null;
      final String label = top != null ? (top['label'] ?? 'Unknown').toString() : 'Unknown';
      final double scoreVal = top != null && (top['score'] is num)
          ? (top['score'] as num).toDouble()
          : 0.0;
      final List<Map<String, dynamic>> candidates = finalRes.take(3).map<Map<String, dynamic>>((e) {
        final l = (e['label'] ?? '').toString();
        final s = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
        return {'label': l, 'score': s, 'oodSim': hardOod ? oodScore : null};
      }).toList();

      setState(() {
        _results = finalRes;
        _oodReason = rejReason;
        _selectedCorrectPlantIndex = null;

        if (hardOod) {
          _resultsA = [];
          _resultsB = [];
        }

        // Save to local state for Save-to-Collection
        _lastLabel = label;
        _lastConfidence = hardOod ? 0.0 : (calibratedConf > 0 ? calibratedConf : scoreVal);
        _lastIsOod = hardOod;
        _lastCandidates = candidates;
      });

      // Save scan result to database and get scan ID for potential reports
      // Note: at classify-time, user selections may not exist yet; we still include per-dataset tops and mark selectedFrom if in combo
      final double? mTopAtScan = _resultsA.isNotEmpty && (_resultsA.first['score'] is num)
          ? (_resultsA.first['score'] as num).toDouble()
          : null;
      final double? kTopAtScan = _resultsB.isNotEmpty && (_resultsB.first['score'] is num)
          ? (_resultsB.first['score'] as num).toDouble()
          : null;
      _currentScanId = await _scanService.saveScan(
        plantName: label,
        confidence: hardOod ? 0.0 : (calibratedConf > 0 ? calibratedConf : scoreVal),
        isOod: hardOod,
        candidates: candidates,
        oodReason: rejReason,
        oodScore: hardOod ? oodScore : null,
        preferredDataset: _preferredDataset,
        selectedLabel: _selectedCorrectPlantIndex != null && _selectedCorrectPlantIndex! >= 0 && _selectedCorrectPlantIndex! < _results.length
            ? (_results[_selectedCorrectPlantIndex!]['label'] ?? 'Unknown').toString()
            : null,
        selectedConfidence: _selectedCorrectPlantIndex != null && _selectedCorrectPlantIndex! >= 0 && _selectedCorrectPlantIndex! < _results.length
            ? ((_results[_selectedCorrectPlantIndex!]['score'] is num) ? (_results[_selectedCorrectPlantIndex!]['score'] as num).toDouble() : null)
            : null,
        mendeleyTop: mTopAtScan,
        kaggleTop: kTopAtScan,
        selectedFrom: (_resultsA.isNotEmpty || _resultsB.isNotEmpty) ? 'combo' : null,
      );

      // Also save to local history, including per-dataset top confidences if available
      final double? mendeleyTop = _resultsA.isNotEmpty && (_resultsA.first['score'] is num)
          ? (_resultsA.first['score'] as num).toDouble()
          : null;
      final double? kaggleTop = _resultsB.isNotEmpty && (_resultsB.first['score'] is num)
          ? (_resultsB.first['score'] as num).toDouble()
          : null;
      await _history.add(
        ScanEntry(
          name: label,
          confidence: hardOod ? 0.0 : (calibratedConf > 0 ? calibratedConf : scoreVal),
          timestamp: DateTime.now(),
          success: !hardOod,
          candidates: candidates,
          isOod: hardOod,
          oodSim: hardOod ? oodScore : null,
          mendeleyTop: mendeleyTop,
          kaggleTop: kaggleTop,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
                  Expanded(
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.arrow_back,
                                size: 24,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Plant Scanner",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppConfig.getTitleColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Model selector
<<<<<<< HEAD
                      _buildModelSelector(),
=======
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
                                color: AppConfig.shadowColor.withOpacity(0.1),
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
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
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
                                color: AppConfig.shadowColor.withOpacity(0.1),
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
                    ],
                  ),
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
                                    color: AppConfig.shadowColor.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 64,
                                color: AppConfig.getTitleColor(context),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Position plant in frame",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.getTitleColor(context),
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
                              color: AppConfig.shadowColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                    if (_error != null && _hasTriedCapture)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildResultCardCombo([
                          {'label': 'Error', 'score': 0.0},
                          {'label': _error ?? 'Unknown error', 'score': 0.0},
                        ], const []),
                      )
                    else if (_hasTriedCapture && (_resultsA.isNotEmpty || _resultsB.isNotEmpty))
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildResultCardCombo(_resultsA, _resultsB),
                      )
                    else if (_hasTriedCapture && _results.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildResultCardCombo(_results, const []),
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
                    SizedBox(
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
                                  color: AppConfig.shadowColor.withOpacity(0.08),
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
                                  color: AppConfig.shadowColor.withOpacity(0.08),
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

  void _showFeedbackModal(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        bool isSubmitting = false;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        type == 'error' ? Icons.report_problem_outlined : Icons.lightbulb_outline,
                        color: type == 'error' ? AppConfig.reportErrorColor : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type == 'error' ? 'Report Error' : 'Suggest Improvement',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type == 'error' 
                        ? 'Help us improve by describing what looks incorrect:'
                        : 'Share your ideas to make the app better:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField.multiline(
                    controller: controller,
                    hintText: type == 'error' 
                        ? 'e.g., "The plant was identified as X but it\'s actually Y"'
                        : 'e.g., "It would be great if the app could..."',
                    maxLines: 4,
                    maxLength: 500,
                    showCounter: false,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          final message = controller.text.trim();
                          if (message.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your feedback')),
                            );
                            return;
                          }

                          setState(() { isSubmitting = true; });

                          try {
                            bool success;
                            if (type == 'error') {
                              // For error reports, we need a scan ID
                              if (_currentScanId != null) {
                                success = await _feedback.submitErrorReportWithScan(
                                  message: message,
                                  scanId: _currentScanId!,
                                );
                              } else {
                                // Fallback: create scan first, then report
                                final scanId = await _scanService.saveScan(
                                  plantName: _lastLabel,
                                  confidence: _lastConfidence,
                                  isOod: _lastIsOod,
                                  candidates: _lastCandidates,
                                  oodReason: _oodReason,
                                  oodScore: _oodScore,
                                );
                                if (scanId != null) {
                                  success = await _feedback.submitErrorReportWithScan(
                                    message: message,
                                    scanId: scanId,
                                  );
                                } else {
                                  success = false;
                                }
                              }
                            } else {
                              success = await _feedback.submitImprovementSuggestion(
                                message: message,
                              );
                            }

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            
                            if (success) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    type == 'error' 
                                        ? 'Error report submitted. Thanks for helping us improve!'
                                        : 'Suggestion submitted. Thanks for your feedback!'
                                  ),
                                  backgroundColor: AppConfig.successColor,
                                ),
                              );
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to submit feedback. Please try again.'),
                                  backgroundColor: AppConfig.errorColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppConfig.errorColor,
                              ),
                            );
                          }
                        },
                        child: isSubmitting 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCornerGuide(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Color(0xFF4CAF50), width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Color(0xFF4CAF50), width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Color(0xFF4CAF50), width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Color(0xFF4CAF50), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

<<<<<<< HEAD
  
=======
  Widget _buildResultCard(List<Map<String, dynamic>> results) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final percentStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    final isUnknown = results.isNotEmpty && (results.first['label']?.toString().toLowerCase() == 'unknown');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConfig.shadowColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse toggle
          Row(
            children: [
              Icon(Icons.local_florist, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Results', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
              ),
              IconButton(
                tooltip: _resultsCollapsed ? 'Expand' : 'Minimize',
                onPressed: () => setState(() => _resultsCollapsed = !_resultsCollapsed),
                icon: Icon(_resultsCollapsed ? Icons.expand_more : Icons.expand_less),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: const SizedBox(height: 8),
            crossFadeState: _resultsCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
          ),
          if (isUnknown)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppConfig.getWarningWithOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConfig.getWarningWithOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.report_gmailerrorred_outlined, color: AppConfig.warningColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Only show plain 'Unknown' for HUMAN_DETECTED so the app presents just 'plants' or 'Unknown'.
                      (_oodReason == 'HUMAN_DETECTED' || _oodReason == 'STATISTICAL_OOD')
                        ? 'Unknown'
                        : (
                            'Unknown${_oodReason != null ? ' (${_oodReason})' : ''}. ${_oodConf != null ? 'conf ${_oodConf!.toStringAsFixed(2)}  ' : ''}${_oodScore != null ? 'ood ${_oodScore!.toStringAsFixed(2)}  ' : ''}${_skinRatio != null ? 'skin ${_skinRatio!.toStringAsFixed(2)}  ' : ''}${_edgeDensity != null ? 'edge ${_edgeDensity!.toStringAsFixed(2)}  ' : ''}${_greenRatio != null ? 'green ${_greenRatio!.toStringAsFixed(2)}' : ''}'
                          ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppConfig.warningColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          // Save to Collection action + Saved badge
          if (!_resultsCollapsed)
          Row(
            children: [
              if (_savedToCollection)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppConfig.getSuccessWithOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConfig.getSuccessWithOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 16, color: AppConfig.successColor),
                      SizedBox(width: 4),
                      Text('Saved', style: TextStyle(color: AppConfig.successColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  try {
                    if (_previewBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nothing to save: capture or pick an image first.')),
                      );
                      return;
                    }
                    // OOD / low-confidence gating to reduce false positives
                    // Compute top1 and top2 from current results
                    final src = _results.isNotEmpty ? _results : (_resultsA.isNotEmpty ? _resultsA : _resultsB);
                    final top1 = src.isNotEmpty && (src.first['score'] is num)
                        ? (src.first['score'] as num).toDouble()
                        : _lastConfidence;
                    final top2 = src.length > 1 && (src[1]['score'] is num)
                        ? (src[1]['score'] as num).toDouble()
                        : 0.0;
                    const identifyMin = 0.90; // require at least 90% to allow saving
                    const separationMin = 0.25; // require top1-top2 >= 0.25
                    final flaggedOod = (_oodReason == 'HUMAN_DETECTED' || _oodReason == 'NON_PLANT_VISUAL' || _oodReason == 'STATISTICAL_OOD');
                    if (flaggedOod || top1 < identifyMin || (top1 - top2) < separationMin) {
                      final msg = flaggedOod
                          ? 'Out-of-domain detected. Try capturing a single leaf on a plain background.'
                          : 'Low confidence. Improve lighting and fill the frame with a single leaf to save.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                      return;
                    }
                    // Prepare base64 image and metadata
                    final imgB64 = convert.base64Encode(_previewBytes!);
                    // Build top-3 candidates from current results
                    List<Map<String, dynamic>> cands = [];
                    for (final e in src.take(3)) {
                      final l = (e['label'] ?? '').toString();
                      final s = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
                      cands.add({'name': l, 'confidence': s});
                    }
                    final plantData = {
                      'plantName': _lastLabel.isNotEmpty ? _lastLabel : (src.isNotEmpty ? (src.first['label'] ?? 'Unknown').toString() : 'Unknown'),
                      'imageData': imgB64,
                      'isFavorite': false,
                      // Store popup info inside plantInfo so Home can render it
                      'confidence': _lastConfidence,
                      'isOod': (_oodReason == 'HUMAN_DETECTED' || _oodReason == 'NON_PLANT_VISUAL' || _oodReason == 'STATISTICAL_OOD'),
                      'oodReason': _oodReason,
                      'oodScore': _oodScore,
                      'candidates': cands,
                      'scannedAt': DateTime.now().toIso8601String(),
                    };
                    final ok = await _collections.addToCollection(plantData);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Saved to collection' : 'Save failed'),
                        backgroundColor: ok ? AppConfig.successColor : AppConfig.errorColor,
                      ),
                    );
                    if (ok) {
                      setState(() { _savedToCollection = true; });
                    }
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
          if (!_resultsCollapsed)
            Text('Top matches', style: titleStyle),
          const SizedBox(height: 4),
          if (!_resultsCollapsed)
            Text(
              'Best guess based on visual features',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7), fontWeight: FontWeight.w500) ?? const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 8),
          if (!_resultsCollapsed)
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
                      final capped = v.clamp(0.0, 0.85);
                      return '${(capped * 100).toStringAsFixed(0)}%';
                    }(),
                    style: percentStyle,
                  ),
                ],
              ),
            ),
          if (!_resultsCollapsed) const SizedBox(height: 8),
          if (!_resultsCollapsed)
            // Feedback Actions (responsive layout)
            Row(
              children: [
                Expanded(
                  child: FeedbackActionButton.error(
                    onPressed: () => _showFeedbackModal('error'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FeedbackActionButton.suggestion(
                    onPressed: () => _showFeedbackModal('suggestion'),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
>>>>>>> 09cd3b64a437793519ebf3d20dd8f6251c691fdd
}
