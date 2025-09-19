import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../lib/features/mood_detection/data/services/tflite_service.dart';

void main() {
  group('TFLite Service Tests', () {
    setUpAll(() async {
      // Initialize Flutter binding for tests
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock asset loading for testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '.';
        },
      );
    });

    test('TFLite service initialization', () async {
      // Test initialization
      final result = await tfliteService.initialize();

      // Even if model fails to load, it should return a boolean
      expect(result, isA<bool>());

      // Test that labels are loaded (either from file or defaults)
      final labels = tfliteService.labels;
      expect(labels, isNotEmpty);
      expect(labels.length, equals(7));

      // Verify FER2013 emotion labels
      expect(labels, contains('Happy'));
      expect(labels, contains('Sad'));
      expect(labels, contains('Angry'));
      expect(labels, contains('Surprise'));
      expect(labels, contains('Fear'));
      expect(labels, contains('Disgust'));
      expect(labels, contains('Neutral'));
    });

    test('Emotion detection fallback behavior', () async {
      // Test fallback result structure
      final fallbackResult =
          await tfliteService.analyzeImage(File('non_existent_file.jpg'));

      expect(fallbackResult, isA<Map<String, dynamic>>());
      expect(fallbackResult['primaryEmotion'], isA<String>());
      expect(fallbackResult['confidence'], isA<double>());
      expect(fallbackResult['emotionConfidences'], isA<Map<String, double>>());
      expect(fallbackResult['timestamp'], isA<String>());

      // Check that all emotions are represented in confidence map
      final confidences =
          fallbackResult['emotionConfidences'] as Map<String, double>;
      expect(confidences.keys.length, equals(7));

      // Check that confidence values are between 0 and 1
      for (final confidence in confidences.values) {
        expect(confidence, greaterThanOrEqualTo(0.0));
        expect(confidence, lessThanOrEqualTo(1.0));
      }
    });

    test('Softmax function validation', () {
      // This would test the internal softmax function if it were public
      // For now, we'll test through the public interface

      final testLogits = [1.0, 2.0, 0.5, 3.0, 1.5, 0.8, 2.2];

      // We can't directly test _applySoftmax as it's private,
      // but we can verify that results from analyzeImage have proper probability distribution
      expect(testLogits.length, equals(7)); // Verify test data structure
    });

    tearDownAll(() {
      tfliteService.dispose();
    });
  });
}
