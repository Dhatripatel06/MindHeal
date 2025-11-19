import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioProcessingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final StreamController<List<double>> _audioDataController = StreamController<List<double>>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  
  Stream<List<double>> get audioDataStream => _audioDataController.stream;
  Stream<Duration> get recordingDurationStream => _durationController.stream;

  Timer? _timer;
  Duration _duration = Duration.zero;
  String? _currentPath;

  Future<void> startRecording() async {
    try {
      // 1. Check Permissions explicitly
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception("Microphone permission denied");
      }

      // 2. Prepare File
      final directory = await getTemporaryDirectory();
      _currentPath = '${directory.path}/emotion_recording.wav';
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete(); // Clean up old file
      }

      // 3. Config: WAV, 16k, Mono (Critical for AI)
      const config = RecordConfig(
        encoder: AudioEncoder.wav, 
        sampleRate: 16000,         
        numChannels: 1,
      );

      // 4. Start
      await _audioRecorder.start(config, path: _currentPath!);
      print("🎙️ Recording started at $_currentPath");
      
      _duration = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _duration += const Duration(seconds: 1);
        _durationController.add(_duration);
        _audioDataController.add([0.5, 0.5, 0.5, 0.5, 0.5]); 
      });
    } catch (e) {
      print("❌ Error starting recording: $e");
      throw e;
    }
  }

  Future<File?> stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    print("🛑 Recording stopped. File saved at: $path");
    
    if (path != null) {
      return File(path);
    }
    return null;
  }

  Future<void> playLastRecording() async {
    if (_currentPath != null) {
      try {
        await _audioPlayer.setFilePath(_currentPath!);
        await _audioPlayer.play();
      } catch (e) {
        print("Error playing audio: $e");
      }
    }
  }

  void clearRecording() {
    _currentPath = null;
    _duration = Duration.zero;
    _durationController.add(Duration.zero);
    _audioDataController.add([]);
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _audioDataController.close();
    _durationController.close();
    _timer?.cancel();
  }
}