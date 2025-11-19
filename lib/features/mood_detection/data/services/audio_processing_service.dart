import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class AudioProcessingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Streams
  final StreamController<List<double>> _audioDataController = StreamController<List<double>>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  
  Stream<List<double>> get audioDataStream => _audioDataController.stream;
  Stream<Duration> get recordingDurationStream => _durationController.stream;

  Timer? _timer;
  Duration _duration = Duration.zero;
  String? _currentPath;

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _currentPath = '${directory.path}/temp_recording.wav';

        // --- KEY CONFIGURATION FOR ONNX MODEL ---
        // We record directly into the format the AI needs.
        // No FFmpeg conversion required later!
        const config = RecordConfig(
          encoder: AudioEncoder.wav, // Record as WAV directly
          sampleRate: 16000,         // 16k Hz (Required by Wav2Vec2)
          numChannels: 1,            // Mono (Required by Wav2Vec2)
        );

        await _audioRecorder.start(config, path: _currentPath!);
        
        _duration = Duration.zero;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _duration += const Duration(seconds: 1);
          _durationController.add(_duration);
          
          // Simulate waveform data since raw stream isn't always available on all platforms in v5+
          // In a real app with more complex needs, we'd use a stream, but this suffices for UI visualization
          _audioDataController.add([0.1, 0.5, 0.3, 0.7, 0.4]); 
        });
      }
    } catch (e) {
      print("Error starting recording: $e");
      throw e;
    }
  }

  Future<File?> stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    
    if (path != null) {
      return File(path);
    }
    return null;
  }

  Future<void> playLastRecording() async {
    if (_currentPath != null) {
      await _audioPlayer.setFilePath(_currentPath!);
      await _audioPlayer.play();
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