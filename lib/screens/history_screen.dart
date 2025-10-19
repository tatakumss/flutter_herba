// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/scan_history_service.dart';
import '../config/app_config.dart';
import '../utils/date_formatter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = ScanHistoryService();
  List<ScanEntry> _scans = [];
  bool _loading = true;
  bool _filterSuccessOnly = false;
  bool _sortDesc = true; // newest first

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<ScanEntry> _filtered() {
    var list = List<ScanEntry>.from(_scans);
    if (_filterSuccessOnly) {
      list = list.where((e) => e.success).toList();
    }
    list.sort((a, b) => _sortDesc
        ? b.timestamp.compareTo(a.timestamp)
        : a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Future<void> _load() async {
    final data = await _service.load();
    if (!mounted) return;
    setState(() {
      _scans = data;
      _loading = false;
    });
  }


  void _showTop3(ScanEntry scan) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: theme.cardColor,
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Top matches', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        if (scan.isOod)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppConfig.getWarningWithOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.report_gmailerrorred_outlined, size: 14, color: AppConfig.warningColor),
                                const SizedBox(width: 4),
                                Text('Unknown', style: TextStyle(color: AppConfig.warningColor, fontWeight: FontWeight.w700)),
                              ],
                            ),
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
                    if (scan.isOod)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'This scan was flagged as Unknown by OOD detection${scan.oodSim != null ? ' (similarity ${(scan.oodSim! * 100).toStringAsFixed(0)}%)' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppConfig.warningColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    for (final cand in scan.candidates.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (cand['label'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (cand['score'] is num) ? (cand['score'] as num).toDouble().clamp(0.0, 1.0) : 0.0,
                                  minHeight: 8,
                                  backgroundColor: theme.dividerColor.withValues(alpha: 0.25),
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(((cand['score'] is num) ? (cand['score'] as num).toDouble() : 0.0) * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                    "Scan History",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF81C784) : AppConfig.primaryDark,
                    ),
                  ),
                  Row(
                    children: [
                      if (_scans.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear history',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Clear history?'),
                                  content: const Text('This will remove all saved scans. This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirmed == true) {
                              await _service.clear();
                              await _load();
                              if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('History cleared')),
                                );
                            }
                          },
                          icon: const Icon(Icons.delete_sweep_outlined),
                          color: theme.colorScheme.error,
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (ctx) {
                              return StatefulBuilder(
                                builder: (ctx, setModalState) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.filter_list, color: theme.colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Text('Filters', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('Close'),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SwitchListTile(
                                          title: const Text('Show successful scans only'),
                                          value: _filterSuccessOnly,
                                          onChanged: (v) {
                                            setModalState(() => _filterSuccessOnly = v);
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Sort order'),
                                          subtitle: Text(_sortDesc ? 'Newest first' : 'Oldest first'),
                                          trailing: SegmentedButton<bool>(
                                            segments: const [
                                              ButtonSegment(value: true, label: Text('Newest')),
                                              ButtonSegment(value: false, label: Text('Oldest')),
                                            ],
                                            selected: {_sortDesc},
                                            onSelectionChanged: (sel) {
                                              final val = sel.first;
                                              setModalState(() => _sortDesc = val);
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Total Scans",
                      "${_filtered().length}",
                      Icons.camera_alt,
                      const Color(0xFF4CAF50),
                      context,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      "Success Rate",
                      _filtered().isEmpty
                          ? "—"
                          : "${((_filtered().where((e) => e.success).length / _filtered().length) * 100).toStringAsFixed(0)}%",
                      Icons.check_circle,
                      AppConfig.primaryColor,
                      context,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // History List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_filtered().isEmpty
                      ? Center(
                          child: Text(
                            'No scans yet. Try scanning a plant!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filtered().length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final scan = _filtered()[index];
                            return _buildHistoryCard(scan, context);
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConfig.getTitleColor(context),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ScanEntry scan, BuildContext context) {
    final isSuccess = scan.success;
    final color = isSuccess ? const Color(0xFF4CAF50) : Colors.orange;
    
    return InkWell(
      onTap: () => _showTop3(scan),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
        children: [
          // Plant Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSuccess ? Icons.local_florist : Icons.help_outline,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // Plant Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scan.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.getTitleColor(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSuccess 
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(scan.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSuccess ? const Color(0xFF4CAF50) : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.formatDateTime(scan.timestamp),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
