import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// A reusable constrained text button widget for feedback actions
/// with consistent styling and responsive constraints.
class FeedbackActionButton extends StatelessWidget {
  /// The text to display on the button
  final String text;
  
  /// The icon to display before the text
  final IconData icon;
  
  /// The callback function when the button is pressed
  final VoidCallback onPressed;
  
  /// The color of the button text and icon
  final Color? color;
  
  /// The minimum width constraint for the button
  final double minWidth;
  
  /// The maximum width constraint for the button
  final double maxWidth;
  
  /// The size of the icon
  final double iconSize;

  const FeedbackActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
    this.minWidth = 140,
    this.maxWidth = 220,
    this.iconSize = 16,
  });

  /// Factory constructor for error report button with default styling
  factory FeedbackActionButton.error({
    required VoidCallback onPressed,
    String text = 'Report Error',
    IconData icon = Icons.report_problem_outlined,
  }) {
    return FeedbackActionButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: AppConfig.reportErrorColor,
      minWidth: 140,
      maxWidth: 220,
    );
  }

  /// Factory constructor for suggestion button with default styling
  factory FeedbackActionButton.suggestion({
    required VoidCallback onPressed,
    String text = 'Suggest Improvement',
    IconData icon = Icons.lightbulb_outline,
    Color? color,
  }) {
    return FeedbackActionButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: color,
      minWidth: 160,
      maxWidth: 260,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          foregroundColor: color ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}
