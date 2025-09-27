import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class OODProfile {
  // Visual thresholds
  final double skinThreshold; // proportion 0..1
  final double edgeThreshold; // proportion 0..1

  // Confidence/temperature thresholds
  final double temperature; // softmax temperature
  final double confThreshold; // calibrated confidence minimum

  // Statistical thresholds and weights
  final Map<String, double> statThresholds; // entropy/max_softmax/mahalanobis/feature_variance
  final Map<String, double> weights; // weight per method
  final double oodThreshold; // combined threshold
  final double strictThreshold; // strict rejection threshold

  // Feature statistics (Mahalanobis)
  final List<double>? featureMeans; // flattened mean vector
  final List<List<double>>? invCov; // inverse covariance matrix

  const OODProfile({
    required this.skinThreshold,
    required this.edgeThreshold,
    required this.temperature,
    required this.confThreshold,
    required this.statThresholds,
    required this.weights,
    required this.oodThreshold,
    required this.strictThreshold,
    this.featureMeans,
    this.invCov,
  });
}

class OODService {
  OODProfile? _profile;

  bool get ready => _profile != null;

  Future<void> load(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final m = json.decode(raw) as Map<String, dynamic>;

      final thresholds = (m['thresholds'] as Map?)?.cast<String, dynamic>() ?? const {};
      final statThresh = (m['statistical_thresholds'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v is Map && v['threshold'] is num) ? (v['threshold'] as num).toDouble() : (v as num?)?.toDouble() ?? 0.0)) ?? <String, double>{};
      final weights = (m['weights'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? <String, double>{};

      List<double>? means;
      List<List<double>>? invCov;
      final feat = (m['feature_statistics'] as Map?)?.cast<String, dynamic>();
      if (feat != null) {
        if (feat['means'] is List) {
          means = (feat['means'] as List).map((e) => (e as num).toDouble()).toList();
        }
        if (feat['inv_covariance'] is List) {
          invCov = (feat['inv_covariance'] as List)
              .map<List<double>>((row) => (row as List).map((e) => (e as num).toDouble()).toList())
              .toList();
        }
      }

      _profile = OODProfile(
        skinThreshold: (thresholds['skin_detection'] as num?)?.toDouble() ?? 0.35,
        edgeThreshold: (thresholds['edge_density'] as num?)?.toDouble() ?? 0.05,
        temperature: (m['temperature'] as num?)?.toDouble() ?? 1.0,
        confThreshold: (thresholds['confidence'] as num?)?.toDouble() ?? 0.3,
        statThresholds: statThresh,
        weights: weights,
        oodThreshold: (thresholds['ood_detection'] as num?)?.toDouble() ?? 0.5,
        strictThreshold: (thresholds['strict_rejection'] as num?)?.toDouble() ?? 0.8,
        featureMeans: means,
        invCov: invCov,
      );
    } catch (_) {
      _profile = null;
    }
  }

  // Cosine-based quick check remains available for simple centroids JSON
  Map<String, dynamic> score(List<double> embedding) {
    // For backward compatibility: treat absence of profile as in-distribution
    if (_profile == null) return {"isOOD": false, "label": null, "similarity": 1.0};
    // Not used in the full pipeline; return neutral result
    return {"isOOD": false, "label": null, "similarity": 1.0};
  }

  // Full OOD evaluation inspired by the provided Python reference.
  // Returns: {isOOD, rejectionReason, calibratedConfidence, oodScore, skinRatio, edgeDensity, entropy, maxSoftmax, mahalanobis}
  Map<String, dynamic> evaluate({
    required img.Image resizedRgb224,
    required List<double> probs, // raw model outputs (pre-softmax or probs), length N
    required List<double> embedding, // from feature_extractor
  }) {
    final prof = _profile;
    if (prof == null) {
      return {"isOOD": false, "rejectionReason": null, "calibratedConfidence": _max(probs)};
    }

    // 1) Temperature scaling + softmax
    final scaled = _softmax(_div(probs, prof.temperature));
    final calibratedConf = _max(scaled);

    // 2) Confidence threshold
    if (calibratedConf < prof.confThreshold) {
      return {
        'isOOD': true,
        'rejectionReason': 'LOW_CONFIDENCE',
        'calibratedConfidence': calibratedConf,
        'oodScore': 1.0 - calibratedConf,
      };
    }

    // 3) Visual OOD checks: skin detection (HSV) and edge density
    final skinRatio = _skinRatio(resizedRgb224);
    final edgeDensity = _edgeDensity(resizedRgb224);
    if (skinRatio > prof.skinThreshold) {
      return {
        'isOOD': true,
        'rejectionReason': 'HUMAN_DETECTED',
        'calibratedConfidence': calibratedConf,
        'skinRatio': skinRatio,
        'edgeDensity': edgeDensity,
      };
    }
    if (edgeDensity < prof.edgeThreshold) {
      return {
        'isOOD': true,
        'rejectionReason': 'NON_PLANT_VISUAL',
        'calibratedConfidence': calibratedConf,
        'skinRatio': skinRatio,
        'edgeDensity': edgeDensity,
      };
    }

    // 4) Statistical OOD features
    final scores = <String, double>{};
    if (prof.statThresholds.containsKey('entropy')) {
      final entropy = _entropy(scaled);
      final th = prof.statThresholds['entropy']!;
      scores['entropy'] = math.min(1.0, entropy / (th + 1e-10));
    }
    if (prof.statThresholds.containsKey('max_softmax')) {
      final ms = calibratedConf;
      final th = prof.statThresholds['max_softmax']!;
      scores['max_softmax'] = math.max(0.0, 1.0 - ms / (th + 1e-10));
    }
    if (prof.featureMeans != null && prof.invCov != null && prof.statThresholds.containsKey('mahalanobis')) {
      final mDist = _mahalanobis(embedding, prof.featureMeans!, prof.invCov!);
      final th = prof.statThresholds['mahalanobis']!;
      scores['mahalanobis'] = math.min(1.0, mDist / (th + 1e-10));
    }
    if (prof.statThresholds.containsKey('feature_variance')) {
      final v = _variance(embedding);
      final th = prof.statThresholds['feature_variance']!;
      scores['feature_variance'] = math.max(0.0, 1.0 - v / (th + 1e-10));
    }

    // 5) Weighted combination
    double total = 0.0, wsum = 0.0;
    scores.forEach((k, s) {
      final w = prof.weights[k] ?? 1.0;
      total += w * s;
      wsum += w;
    });
    final oodScore = wsum > 0 ? total / wsum : 0.0;

    if (oodScore > prof.strictThreshold || calibratedConf < 0.3) {
      return {
        'isOOD': true,
        'rejectionReason': 'STATISTICAL_OOD',
        'calibratedConfidence': calibratedConf,
        'oodScore': oodScore,
        'individualScores': scores,
        'skinRatio': skinRatio,
        'edgeDensity': edgeDensity,
      };
    } else if (oodScore > prof.oodThreshold) {
      return {
        'isOOD': true,
        'rejectionReason': 'STATISTICAL_OOD',
        'calibratedConfidence': calibratedConf,
        'oodScore': oodScore,
        'individualScores': scores,
        'skinRatio': skinRatio,
        'edgeDensity': edgeDensity,
      };
    }

    return {
      'isOOD': false,
      'rejectionReason': null,
      'calibratedConfidence': calibratedConf,
      'oodScore': oodScore,
      'individualScores': scores,
      'skinRatio': skinRatio,
      'edgeDensity': edgeDensity,
    };
  }

  // Utilities
  List<double> _softmax(List<double> x) {
    final m = x.reduce(math.max);
    final exps = x.map((v) => math.exp(v - m)).toList();
    final sum = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / (sum + 1e-10)).toList();
  }

  List<double> _div(List<double> x, double t) => x.map((e) => e / (t == 0 ? 1.0 : t)).toList();

  double _max(List<double> x) => x.isEmpty ? 0.0 : x.reduce(math.max);

  double _entropy(List<double> p) {
    double s = 0.0;
    for (final v in p) {
      final vv = v.clamp(1e-10, 1.0);
      s += -vv * math.log(vv);
    }
    return s;
  }

  double _variance(List<double> x) {
    if (x.isEmpty) return 0.0;
    final mean = x.reduce((a, b) => a + b) / x.length;
    double s = 0.0;
    for (final v in x) { s += (v - mean) * (v - mean); }
    return s / x.length;
  }

  // Very light HSV conversion for skin ratio (manual channel extraction)
  double _skinRatio(img.Image rgb) {
    int count = 0;
    final total = rgb.width * rgb.height;
    for (int y = 0; y < rgb.height; y++) {
      for (int x = 0; x < rgb.width; x++) {
        final px = rgb.getPixel(x, y);
        final r = px.r.toDouble();
        final g = px.g.toDouble();
        final b = px.b.toDouble();
        final hsb = _rgbToHsv(r, g, b);
        final h = hsb[0];
        final s = hsb[1];
        final v = hsb[2];
        final cond1 = (h >= 0 && h <= 20) && (s >= 0.08) && (v >= 0.27);
        final cond2 = (h >= 170 && h <= 180) && (s >= 0.08) && (v >= 0.27);
        if (cond1 || cond2) count++;
      }
    }
    return count / (total == 0 ? 1 : total);
  }

  // Simple edge density using central differences on grayscale
  double _edgeDensity(img.Image rgb) {
    final w = rgb.width;
    final h = rgb.height;
    if (w < 3 || h < 3) return 0.0;
    // Build grayscale buffer
    final gray = List<double>.filled(w * h, 0.0, growable: false);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final px = rgb.getPixel(x, y);
        final r = px.r.toDouble();
        final g = px.g.toDouble();
        final b = px.b.toDouble();
        gray[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b;
      }
    }
    int edges = 0;
    final total = (w - 2) * (h - 2);
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final gxl = gray[y * w + (x + 1)] - gray[y * w + (x - 1)];
        final gyy = gray[(y + 1) * w + x] - gray[(y - 1) * w + x];
        final mag = math.sqrt(gxl * gxl + gyy * gyy);
        if (mag > 20.0) edges++;
      }
    }
    return edges / (total == 0 ? 1 : total);
  }

  // Mahalanobis distance \sqrt((x-μ)^T Σ^{-1} (x-μ))
  double _mahalanobis(List<double> x, List<double> mean, List<List<double>> invCov) {
    final n = math.min(x.length, mean.length);
    final d = List<double>.generate(n, (i) => x[i] - mean[i]);
    // y = invCov * d
    final y = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      double s = 0.0;
      final row = invCov[i];
      for (int j = 0; j < n && j < row.length; j++) {
        s += row[j] * d[j];
      }
      y[i] = s;
    }
    double q = 0.0;
    for (int i = 0; i < n; i++) { q += d[i] * y[i]; }
    return math.sqrt(math.max(q, 0.0));
  }

  // RGB (0..255) -> HSV(H in 0..180 like OpenCV, S,V in 0..1)
  List<double> _rgbToHsv(double r, double g, double b) {
    r /= 255.0; g /= 255.0; b /= 255.0;
    final maxc = math.max(r, math.max(g, b));
    final minc = math.min(r, math.min(g, b));
    final v = maxc;
    final d = maxc - minc;
    final s = maxc == 0 ? 0.0 : d / maxc;
    double h = 0.0;
    if (d == 0) {
      h = 0.0;
    } else if (maxc == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (maxc == g) {
      h = 60 * (((b - r) / d) + 2);
    } else {
      h = 60 * (((r - g) / d) + 4);
    }
    if (h < 0) h += 360;
    // Convert to 0..180 range as in OpenCV HSV
    h = h / 2.0;
    return [h, s, v];
  }
}
