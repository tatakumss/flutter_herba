import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// A showcase widget demonstrating all reusable colors from AppConfig
/// This can be used for testing and documentation purposes
class ColorShowcase extends StatelessWidget {
  const ColorShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Showcase'),
        backgroundColor: AppConfig.transparentColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Primary Brand Colors', [
            _buildColorTile('Primary Color', AppConfig.primaryColor),
            _buildColorTile('Primary Dark', AppConfig.primaryDark),
            _buildColorTile('Background Color', AppConfig.backgroundColor),
          ]),
          
          _buildSection('Semantic Colors', [
            _buildColorTile('Error Color', AppConfig.errorColor),
            _buildColorTile('Success Color', AppConfig.successColor),
            _buildColorTile('Warning Color', AppConfig.warningColor),
            _buildColorTile('Info Color', AppConfig.infoColor),
          ]),
          
          _buildSection('Action Colors', [
            _buildColorTile('Delete Color', AppConfig.deleteColor),
            _buildColorTile('Confirm Color', AppConfig.confirmColor),
            _buildColorTile('Cancel Color', AppConfig.cancelColor),
          ]),
          
          _buildSection('Feedback Colors', [
            _buildColorTile('Report Error Color', AppConfig.reportErrorColor),
            _buildColorTile('Suggestion Color', AppConfig.suggestionColor),
          ]),
          
          _buildSection('Theme-Aware Colors', [
            _buildColorTile('Text Primary', AppConfig.getTextPrimary(isDark)),
            _buildColorTile('Text Secondary', AppConfig.getTextSecondary(isDark)),
            _buildColorTile('Card Color', AppConfig.getCardColor(isDark)),
            _buildColorTile('Shadow Color', AppConfig.getShadowColor(isDark)),
          ]),
          
          _buildSection('Opacity Variants (50%)', [
            _buildColorTile('Primary 50%', AppConfig.getPrimaryWithOpacity(0.5)),
            _buildColorTile('Error 50%', AppConfig.getErrorWithOpacity(0.5)),
            _buildColorTile('Success 50%', AppConfig.getSuccessWithOpacity(0.5)),
            _buildColorTile('Warning 50%', AppConfig.getWarningWithOpacity(0.5)),
          ]),
          
          _buildSection('Usage Examples', [
            _buildUsageExample('Success SnackBar', AppConfig.successColor, 'Operation completed successfully!'),
            _buildUsageExample('Error SnackBar', AppConfig.errorColor, 'Something went wrong!'),
            _buildUsageExample('Warning SnackBar', AppConfig.warningColor, 'Please check your input!'),
            _buildUsageExample('Info SnackBar', AppConfig.infoColor, 'Here\'s some information for you.'),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildColorTile(String name, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        title: Text(name),
        subtitle: Text(
          'Color(0x${color.value.toRadixString(16).toUpperCase().padLeft(8, '0')})',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }
  
  Widget _buildUsageExample(String name, Color color, String message) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(name),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
