import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

class AudioConverterService {
  static final AudioConverterService _instance = AudioConverterService._internal();
  factory AudioConverterService() => _instance;
  AudioConverterService._internal();

  final FlutterSoundHelper _soundHelper = FlutterSoundHelper();
  final Logger _logger = Logger();

  /// Ensures the audio file is a valid PCM WAV.
  /// If uploaded file is MP3/AAC/etc, it converts it.
  Future<File> ensureWavFormat(File inputFile) async {
    final String extension = p.extension(inputFile.path).toLowerCase();

    // 1. If likely already WAV, return as is (validation happens in analysis)
    if (extension == '.wav') {
      return inputFile;
    }

    _logger.i("🔄 Converting $extension to WAV...");

    try {
      final tempDir = await getTemporaryDirectory();
      final String inputName = p.basenameWithoutExtension(inputFile.path);
      // Create a temp file path with .wav extension
      final String outputPath = p.join(tempDir.path, '${inputName}_converted.wav');

      // 2. Convert using FlutterSound (uses native FFmpeg-like capability on OS)
      await _soundHelper.convertFile(
        inputFile.path,
        Codec.pcm16WAV,
        outputPath,
      );

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        _logger.i("✅ Conversion successful: $outputPath");
        return outputFile;
      } else {
        throw Exception("Conversion output file not found.");
      }
    } catch (e) {
      _logger.e("❌ Audio Conversion Failed: $e");
      // Fallback: Return original and let the WAV parser try (or fail gracefully later)
      return inputFile;
    }
  }
}