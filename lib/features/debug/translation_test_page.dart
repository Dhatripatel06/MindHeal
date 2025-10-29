import 'package:flutter/material.dart';
import '../core/services/gemini_adviser_service.dart';

/// Test page to verify Hindi/Gujarati translations
class TranslationTestPage extends StatefulWidget {
  const TranslationTestPage({Key? key}) : super(key: key);

  @override
  State<TranslationTestPage> createState() => _TranslationTestPageState();
}

class _TranslationTestPageState extends State<TranslationTestPage> {
  final GeminiAdviserService _adviserService = GeminiAdviserService();
  String? _englishAdvice;
  String? _hindiAdvice;
  String? _gujaratiAdvice;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Test'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Gemini Translation',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testTranslations,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Fear Emotion in All Languages'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_englishAdvice != null)
              _buildAdviceCard('English', _englishAdvice!, Colors.blue),
            if (_hindiAdvice != null)
              _buildAdviceCard('हिंदी', _hindiAdvice!, Colors.orange),
            if (_gujaratiAdvice != null)
              _buildAdviceCard('ગુજરાતી', _gujaratiAdvice!, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceCard(String language, String advice, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: color),
                const SizedBox(width: 8),
                Text(
                  language,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                advice,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testTranslations() async {
    setState(() {
      _isLoading = true;
      _englishAdvice = null;
      _hindiAdvice = null;
      _gujaratiAdvice = null;
    });

    try {
      // Test English
      final english = await _adviserService.getEmotionalAdvice(
        detectedEmotion: 'fear',
        confidence: 0.85,
        language: 'English',
      );

      // Test Hindi
      final hindi = await _adviserService.getEmotionalAdvice(
        detectedEmotion: 'fear',
        confidence: 0.85,
        language: 'हिंदी',
      );

      // Test Gujarati
      final gujarati = await _adviserService.getEmotionalAdvice(
        detectedEmotion: 'fear',
        confidence: 0.85,
        language: 'ગુજરાતી',
      );

      setState(() {
        _englishAdvice = english;
        _hindiAdvice = hindi;
        _gujaratiAdvice = gujarati;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing translations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
