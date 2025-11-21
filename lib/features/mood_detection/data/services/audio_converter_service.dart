import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

class AudioConverterService {
  static final AudioConverterService _instance = AudioConverterService._internal();
  factory AudioConverterService() => _instance;
  AudioConverterService._internal();

  final Logger _logger = Logger();

  /// Ensures the audio file is a valid PCM WAV.
  /// Since we are avoiding FFmpeg, we strictly check for WAV files.
  Future<File> ensureWavFormat(File inputFile) async {
    final String extension = p.extension(inputFile.path).toLowerCase();

    // 1. Check if it is a WAV file
    if (extension == '.wav') {
      _logger.i("✅ File is already WAV: ${inputFile.path}");
      return inputFile;
    }

    // 2. If not WAV, we throw an error because pure Flutter cannot 
    // decode MP3/AAC to PCM without FFmpeg or native platform channels.
    _logger.e("❌ Unsupported format: $extension");
    throw Exception(
      "Unsupported audio format ($extension). Please upload a WAV file.\n"
      "Automatic conversion requires FFmpeg which is disabled."
    );
  }
}