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

  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    // Resize image
    var resized = img.copyResize(image, width: inputSize, height: inputSize);

    // Convert to float and normalize
    var input = List.generate(
        1,
        (b) => List.generate(
            inputSize,
            (y) => List.generate(
                inputSize,
                (x) => List.generate(3, (c) {
                      var pixel = resized.getPixel(x, y);
                      double value = 0.0;
                      if (c == 0)
                        value = img.getRed(pixel) / 255.0;
                      else if (c == 1)
                        value = img.getGreen(pixel) / 255.0;
                      else
                        value = img.getBlue(pixel) / 255.0;

                      // Apply ImageNet normalization
                      var mean = [0.485, 0.456, 0.406][c];
                      var std = [0.229, 0.224, 0.225][c];
                      return (value - mean) / std;
                    }))));

    return input;
  }

  void dispose() {
    _interpreter?.close();
  }
}
