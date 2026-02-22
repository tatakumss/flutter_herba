// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../services/collection_service.dart';
import '../utils/date_formatter.dart';
import '../utils/snackbar_utils.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final CollectionService _collectionService = CollectionService();
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final collections = await _collectionService.getCollections();
      if (mounted) {
        setState(() {
          _collections = collections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCollections {
    if (_searchQuery.isEmpty) return _collections;
    return _collections.where((collection) {
      final plantName = collection['plantName']?.toString().toLowerCase() ?? '';
      return plantName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collections'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppConfig.primaryDark,
        actions: [
          IconButton(
            tooltip: 'Delete all',
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirmed = await _confirmDeleteAll();
              if (!confirmed) return;
              await _deleteAllCollections();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search collections...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ),
          
          // Collections list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCollections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadCollections,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCollections.length,
                          itemBuilder: (context, index) {
                            final collection = _filteredCollections[index];
                            return _buildCollectionCard(collection);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? 'No collections yet'
                : 'No collections found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start scanning plants to build your collection'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final plantName = collection['plantName']?.toString() ?? 'Unknown Plant';
    final addedAt = DateTime.tryParse(collection['addedAt']?.toString() ?? '') ?? DateTime.now();
    final plantInfo = collection['plantInfo'] as Map<String, dynamic>?;
    final confidence = plantInfo?['confidence'] as double?;
    final isOod = plantInfo?['isOod'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCollectionDetail(collection),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Plant image or icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: collection['imageData'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(collection['imageData']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.local_florist,
                              color: Colors.grey[500],
                              size: 30,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.local_florist,
                        color: Colors.grey[500],
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Plant info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plantName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (confidence != null && !isOod)
                      Text(
                        '${(confidence * 100).toInt()}% confidence',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (isOod)
                      Text(
                        'Uncertain identification',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatRelativeDate(addedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action button
              IconButton(
                onPressed: () => _showCollectionOptions(collection),
                icon: const Icon(Icons.more_vert),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showCollectionDetail(Map<String, dynamic> collection) {
    final plantInfo = collection['plantInfo'] as Map<String, dynamic>?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collection['plantName']?.toString() ?? 'Unknown Plant'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (collection['imageData'] != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(collection['imageData']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              const Text(
                'Scan Details:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              
              if (plantInfo != null) ...[
                if (plantInfo['confidence'] != null)
                  Text('Confidence: ${((plantInfo['confidence'] as double) * 100).toInt()}%'),
                if (plantInfo['isOod'] == true)
                  const Text('Status: Uncertain identification', style: TextStyle(color: Colors.orange)),
                if (plantInfo['oodReason'] != null)
                  Text('Reason: ${plantInfo['oodReason']}'),
                if (plantInfo['candidates'] != null && (plantInfo['candidates'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Alternative matches:', style: TextStyle(fontWeight: FontWeight.w600)),
                  ...(plantInfo['candidates'] as List).take(3).map((candidate) {
                    final name = candidate['label']?.toString() ?? 'Unknown';
                    final score = candidate['score'] as double? ?? 0.0;
                    return Text('• $name (${(score * 100).toInt()}%)');
                  }),
                ],
              ],
              
              
              const SizedBox(height: 8),
              Text('Added: ${DateFormatter.formatRelativeDate(DateTime.tryParse(collection['addedAt']?.toString() ?? '') ?? DateTime.now())}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCollectionOptions(Map<String, dynamic> collection) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showCollectionDetail(collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove from Collection', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete(collection);
                if (confirmed) {
                  await _deleteCollection(collection);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> collection) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Collection'),
        content: Text('Are you sure you want to remove "${collection['plantName']}" from your collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteCollection(Map<String, dynamic> collection) async {
    try {
      final success = await _collectionService.deleteCollection(collection);
      if (mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, 'Removed from collection');
        } else {
          SnackBarUtils.showError(context, 'Failed to remove');
        }
        if (success) {
          _loadCollections(); // Refresh the list
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $e');
      }
    }
  }

  Future<bool> _confirmDeleteAll() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete all items'),
            content: const Text('Are you sure you want to delete all items from your collection? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAllCollections() async {
    try {
      final success = await _collectionService.removeAll();
      if (!mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(context, 'All items deleted');
        _loadCollections();
      } else {
        SnackBarUtils.showError(context, 'Failed to delete all');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Error: $e');
    }
  }
}
