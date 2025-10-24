import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/onnx_emotion_detection/data/services/onnx_emotion_service.dart';

void main() {
  group('OnnxEmotionService Tests', () {
    late OnnxEmotionService service;

    setUpAll(() async {
      // Mock the asset bundle
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock asset loading for proper bundle handling
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          final String key =
              const StandardMessageCodec().decodeMessage(message) as String;

          if (key == 'assets/models/labels.txt') {
            const String labels =
                'Anger\nContempt\nDisgust\nFear\nHappy\nNeutral\nSad\nSurprise';
            return const StandardMessageCodec().encodeMessage(
                ByteData.sublistView(Uint8List.fromList(labels.codeUnits)));
          } else if (key == 'assets/models/enet_b0_8_best_afew.onnx') {
            // Mock model data - just return some bytes
            return const StandardMessageCodec().encodeMessage(
                ByteData.sublistView(
                    Uint8List.fromList(List.generate(1024, (i) => i % 256))));
          }

          throw FlutterError('Asset not found: $key');
        },
      );
    });

    setUp(() {
      service = OnnxEmotionService.instance;
    });

    tearDownAll(() {
      // Clean up mock message handler
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    test('should initialize successfully', () async {
      final result = await service.initialize();
      expect(result, true);
      expect(service.isReady, true);
      expect(service.emotionClasses.length, 8);
    });

    test('should load correct emotion classes', () async {
      await service.initialize();
      final expectedClasses = [
        'Anger',
        'Contempt',
        'Disgust',
        'Fear',
        'Happy',
        'Neutral',
        'Sad',
        'Surprise'
      ];
      expect(service.emotionClasses, expectedClasses);
    });

    test('should detect emotions from image bytes', () async {
      await service.initialize();

      // Create a minimal valid PNG image (1x1 white pixel)
      final Uint8List testImageBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 image
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // RGB mode
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, // Data
        0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // White pixel
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
        0x82 // IEND
      ]);

      final result = await service.detectEmotions(testImageBytes);

      expect(result.emotion, isNotNull);
      expect(result.confidence, greaterThan(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.allEmotions.length, 8);
      expect(result.processingTimeMs, greaterThan(0));

      // Verify all emotion probabilities sum to approximately 1.0
      final totalProbability =
          result.allEmotions.values.reduce((a, b) => a + b);
      expect(totalProbability, closeTo(1.0, 0.1));
    });

    test('should produce realistic confidence scores', () async {
      await service.initialize();

      // Create a minimal valid PNG image (1x1 white pixel)
      final Uint8List testImageBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 image
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // RGB mode
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, // Data
        0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // White pixel
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
        0x82 // IEND
      ]);

      final result = await service.detectEmotions(testImageBytes);

      // Check that confidence score is above 30% (addressing the low confidence issue)
      expect(result.confidence, greaterThan(0.3),
          reason: 'Confidence scores should be realistic, not 10-19%');

      // Verify total confidence approximately sums to 1.0 (softmax output)
      final totalConfidence = result.allEmotions.values.reduce((a, b) => a + b);
      expect(totalConfidence, closeTo(1.0, 0.1));

      print(
          'Detected: ${result.emotion} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('should handle batch processing', () async {
      await service.initialize();

      // Create minimal valid PNG images for batch processing
      final List<Uint8List> testImages = List.generate(
          3,
          (index) => Uint8List.fromList([
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 image
                0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
                0xDE, // RGB mode
                0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
                0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, // Data
                0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00,
                0x01, // White pixel
                0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
                0x60, 0x82 // IEND
              ]));

      final batchResults = await service.detectEmotionsBatch(testImages);

      expect(batchResults, hasLength(3));

      for (final result in batchResults) {
        expect(result, isNotNull);
        expect(result.emotion, isNotNull);
        expect(result.confidence, greaterThan(0.0));
        expect(result.allEmotions.length, 8);

        // Verify realistic confidence scores for each result
        expect(result.confidence, greaterThan(0.3));
      }
    });

    test('should provide performance statistics', () async {
      await service.initialize();

      // Create a minimal valid PNG image (1x1 white pixel)
      final Uint8List testImageBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 image
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // RGB mode
        0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, // Data
        0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // White pixel
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
        0x82 // IEND
      ]);

      await service.detectEmotions(testImageBytes);

      final stats = service.getPerformanceStats();

      expect(stats, isNotNull);
      expect(stats.totalInferences, greaterThan(0));
      expect(stats.averageInferenceTimeMs, greaterThan(0));
    });
  });
}
