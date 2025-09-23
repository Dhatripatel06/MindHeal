
# Flutter Integration Guide for Emotion Recognition Model

## 1. Add TFLite dependencies to pubspec.yaml

```yaml
dependencies:
  tflite_flutter: ^0.10.4
  image: ^4.0.17
  camera: ^0.10.5+5
```

## 2. Add the model file to assets

```yaml
flutter:
  assets:
    - assets/models/emotion_model.tflite
```

## 3. Dart code for emotion recognition

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class EmotionRecognizer {
  static const List<String> emotionClasses = ['anger', 'disgust', 'fear', 'happiness', 'neutral', 'sadness', 'surprise'];
  static const int inputSize = 224;
  
  Interpreter? _interpreter;
  
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/emotion_model.tflite');
    print('Model loaded successfully');
  }
  
  Future<Map<String, dynamic>> recognizeEmotion(img.Image image) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded');
    }
    
    // Preprocess image
    var input = preprocessImage(image);
    
    // Prepare output
    var output = List.filled(emotionClasses.length, 0.0).reshape([1, emotionClasses.length]);
    
    // Run inference
    _interpreter!.run(input, output);
    
    // Get results
    var predictions = output[0];
    var maxIndex = predictions.indexOf(predictions.reduce((a, b) => a > b ? a : b));
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
            var value = 0.0;
            if (c == 0) value = pixel.r / 255.0;
            else if (c == 1) value = pixel.g / 255.0;
            else value = pixel.b / 255.0;
            
            // Apply ImageNet normalization
            var mean = [0.485, 0.456, 0.406][c];
            var std = [0.229, 0.224, 0.225][c];
            return (value - mean) / std;
          })
        )
      )
    );
    
    return input;
  }
  
  void dispose() {
    _interpreter?.close();
  }
}
```

## 4. Usage example

```dart
class EmotionDetectionScreen extends StatefulWidget {
  @override
  _EmotionDetectionScreenState createState() => _EmotionDetectionScreenState();
}

class _EmotionDetectionScreenState extends State<EmotionDetectionScreen> {
  EmotionRecognizer? _recognizer;
  CameraController? _cameraController;
  String _currentEmotion = 'Unknown';
  double _confidence = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }
  
  Future<void> _loadModel() async {
    _recognizer = EmotionRecognizer();
    await _recognizer!.loadModel();
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController!.initialize();
    setState(() {});
  }
  
  Future<void> _detectEmotion() async {
    if (_cameraController == null || _recognizer == null) return;
    
    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      
      // Load and process image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        // Run emotion recognition
        final result = await _recognizer!.recognizeEmotion(image);
        
        setState(() {
          _currentEmotion = result['emotion'];
          _confidence = result['confidence'];
        });
      }
    } catch (e) {
      print('Error detecting emotion: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emotion Detection')),
      body: Column(
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Expanded(child: CameraPreview(_cameraController!)),
          
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Emotion: $_currentEmotion',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _detectEmotion,
                  child: Text('Detect Emotion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _recognizer?.dispose();
    super.dispose();
  }
}
```

## Model Information:
- Classes: anger, disgust, fear, happiness, neutral, sadness, surprise
- Input Size: 224x224x3
- Preprocessing: Resize + ImageNet normalization
- Output: Softmax probabilities for each emotion class

## Performance Tips:
1. Use quantized model (emotion_model.tflite) for better performance
2. Consider using GPU delegate for faster inference
3. Implement proper error handling
4. Cache the model loading for better user experience
