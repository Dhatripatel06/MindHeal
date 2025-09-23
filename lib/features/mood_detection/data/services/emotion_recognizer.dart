import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class EmotionRecognizer {
  static const List<String> emotionClasses = [
    'anger',
    'disgust',
    'fear',
    'happiness',
    'neutral',
    'sadness',
    'surprise'
  ];
  static const int inputSize = 224;

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter =
        await Interpreter.fromAsset('assets/models/emotion_model.tflite');
    print('Model loaded successfully');
  }

  Future<Map<String, dynamic>> recognizeEmotion(img.Image image) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded');
    }

    // Preprocess image
    var input = preprocessImage(image);

    // Prepare output
    var output = List.filled(emotionClasses.length, 0.0)
        .reshape([1, emotionClasses.length]);

    // Run inference
    _interpreter!.run(input, output);

    // Get results
    var predictions = output[0];
    var maxIndex =
        predictions.indexOf(predictions.reduce((a, b) => a > b ? a : b));
    var confidence = predictions[maxIndex];

    return {
      'emotion': emotionClasses[maxIndex],
      'confidence': confidence,
      'all_predictions': Map.fromIterables(emotionClasses, predictions)
    };
  }

  List<List<List<List<int>>>> preprocessImage(img.Image image) {
    // Resize image
    var resized = img.copyResize(image, width: inputSize, height: inputSize);

    // Convert to uint8 (no normalization, no division)
    var input = List.generate(
      1,
      (b) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) => List.generate(3, (c) {
            var pixel = resized.getPixel(x, y);
            if (c == 0) return img.getRed(pixel);
            if (c == 1) return img.getGreen(pixel);
            return img.getBlue(pixel);
          }),
        ),
      ),
    );
    return input;
  }

  void dispose() {
    _interpreter?.close();
  }
}
