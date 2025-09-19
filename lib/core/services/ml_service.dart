import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

class MLService {
  static Interpreter? _emotionInterpreter;
  static Interpreter? _stressInterpreter;
  
  static Future<void> loadModels() async {
    try {
      _emotionInterpreter = await Interpreter.fromAsset('assets/models/emotion_model.tflite');
      _stressInterpreter = await Interpreter.fromAsset('assets/models/stress_model.tflite');
    } catch (e) {
      print('Error loading models: $e');
    }
  }
  
  static Future<List<double>> predictEmotion(List<List<List<double>>> input) async {
    if (_emotionInterpreter == null) await loadModels();
    
    var output = List.filled(7, 0.0).reshape([1, 7]); // 7 emotions
    _emotionInterpreter!.run(input, output);
    
    return output[0];
  }
  
  static Future<double> predictStress(List<double> biometricData) async {
    if (_stressInterpreter == null) await loadModels();
    
    var output = List.filled(1, 0.0).reshape([1, 1]);
    _stressInterpreter!.run([biometricData], output);
    
    return output[0][0];
  }
}
