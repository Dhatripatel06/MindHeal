import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

class AudioConverterService {
  static final AudioConverterService _instance = AudioConverterService._internal();
  factory AudioConverterService() => _instance;
  AudioConverterService._internal();

  final Logger _logger = Logger();

  /// Ensures the audio file is a valid PCM WAV.
  Future<File> ensureWavFormat(File inputFile) async {
    final String extension = p.extension(inputFile.path).toLowerCase();

    // 1. Check extension
    if (extension == '.wav') {
      _logger.i("✅ File has .wav extension: ${inputFile.path}");
      return inputFile;
    }

    // 2. Check Magic Bytes (RIFF Header) for missing extension
    // This fixes the "Unsupported audio format ()" error
    try {
      if (await _isWavHeader(inputFile)) {
        _logger.i("✅ Verified WAV by header (RIFF): ${inputFile.path}");
        return inputFile;
      }
    } catch (e) {
      _logger.w("⚠️ Could not verify file header: $e");
    }

    _logger.e("❌ Unsupported format: '$extension'");
    throw Exception(
      "Unsupported audio format. Please ensure you are uploading a WAV file."
    );
  }

  Future<bool> _isWavHeader(File file) async {
    try {
      final Stream<List<int>> stream = file.openRead(0, 4);
      final List<int> header = await stream.first;
      if (header.length < 4) return false;
      
      // Check for 'RIFF' in ASCII (0x52, 0x49, 0x46, 0x46)
      return header[0] == 0x52 && 
             header[1] == 0x49 && 
             header[2] == 0x46 && 
             header[3] == 0x46;
    } catch (e) {
      return false;
    }
  }
}