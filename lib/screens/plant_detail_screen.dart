// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/plant_library_service.dart';
import '../config/app_config.dart';

class PlantDetailScreen extends StatelessWidget {
  final PlantItem plant;
  const PlantDetailScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF81C784) : AppConfig.primaryDark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with back
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),
                  Text(
                    plant.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(width: 44), // balance
                ],
              ),
            ),

            // Hero image area
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: plant.color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (plant.assetImages.isNotEmpty)
                      Image.asset(
                        plant.assetImages.first,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [plant.color.withOpacity(0.35), plant.color.withOpacity(0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(child: Icon(Icons.image_not_supported_outlined, color: plant.color, size: 64)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [plant.color.withOpacity(0.35), plant.color.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(child: Icon(Icons.local_florist, size: 80, color: plant.color)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: plant.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            plant.category,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: plant.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...plant.tags.map((t) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plant.description.isNotEmpty ? plant.description : 'No description available.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Common uses',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (plant.uses.isEmpty)
                      Text('No uses listed.', style: theme.textTheme.bodyMedium)
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: plant.uses
                            .map((u) => Chip(
                                  label: Text(u),
                                  backgroundColor: theme.cardColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ))
                            .toList(),
                      ),

                    const SizedBox(height: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
