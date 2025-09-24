import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

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

    // Preprocess image to nested list [1,224,224,3]
    var input = preprocessImage(image);
    // Debug: Print input type and shape
    print('TFLite input type: \\${input.runtimeType}');
    try {
      print(
          'TFLite input shape: [batch: \\${input.length}, height: \\${input[0].length}, width: \\${input[0][0].length}, channels: \\${input[0][0][0].length}]');
    } catch (e) {
      print('TFLite input shape error: \\${e.toString()}');
    }
    // Runtime check for shape and type
    if (input is! List ||
        input.length != 1 ||
        input[0] is! List ||
        input[0].length != 224 ||
        input[0][0] is! List ||
        input[0][0].length != 224 ||
        input[0][0][0] is! List ||
        input[0][0][0].length != 3) {
      throw Exception(
          'TFLite input shape/type mismatch: expected [1,224,224,3] of uint8');
    }
    if (input[0][0][0][0] is! int) {
      throw Exception('TFLite input type mismatch: expected uint8 (int)');
    }

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

  // Returns nested List<List<List<List<int>>>> shape [1,224,224,3]
  List<List<List<List<int>>>> preprocessImage(img.Image image) {
    var resized = img.copyResize(image, width: inputSize, height: inputSize);
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
