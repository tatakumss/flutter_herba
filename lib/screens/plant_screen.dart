import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/tflite_service.dart';

class PlantScreen extends StatefulWidget {
  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> {
  Uint8List? _previewBytes;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  final _picker = ImagePicker();
  final _tflite = TFLiteService();

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _tflite.init();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Model not found. Please add assets/models/plant_classifier.tflite and labels.txt'; });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      // Ensure model is initialized before classification
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

  Future<void> _classify(Uint8List bytes) async {
    if (!_tflite.isInitialized) return;
    setState(() { _loading = true; _results = []; _error = null; });
    try {
      final res = await _tflite.classify(bytes, topK: 3);
      if (!mounted) return;
      setState(() { _results = res; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _tflite.dispose();
    super.dispose();
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      color: AppConfig.primaryColor,
                      size: 24,
                    ),
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
                      const Color(0xFF4CAF50).withOpacity(0.1),
                      const Color(0xFF2E7D32).withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_previewBytes != null)
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
                                color: Colors.white,
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
                                color: AppConfig.primaryColor,
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
                                color: Colors.grey[600],
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
                child: Column(
                  children: [
                    // Primary Action - Camera
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: integrate camera capture; for now prefer gallery
                          _pickFromGallery();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 24),
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
                              color: Colors.white,
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
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              label: Text(
                                "Gallery",
                                style: TextStyle(
                                  color: AppConfig.primaryColor,
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
                              color: Colors.white,
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
                              onPressed: () {},
                              icon: Icon(
                                Icons.flash_on_outlined,
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              label: Text(
                                "Flash",
                                style: TextStyle(
                                  color: AppConfig.primaryColor,
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
    // Card background is white; enforce dark text for readability
    const titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87);
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87);
    const percentStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text('Top matches', style: titleStyle),
          const SizedBox(height: 4),
          Text(
            'Best guess based on visual features',
            style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
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
                        backgroundColor: Colors.grey.shade200,
                        color: AppConfig.primaryColor,
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
