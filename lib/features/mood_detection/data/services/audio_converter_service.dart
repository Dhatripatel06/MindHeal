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
  Future<File> ensureWavFormat(File inputFile) async {
    final String extension = p.extension(inputFile.path).toLowerCase();

    // 1. Fast Check: Extension
    if (extension == '.wav') {
      _logger.i("✅ File has .wav extension: ${inputFile.path}");
      return inputFile;
    }

    // 2. Robust Check: Magic Bytes (RIFF Header)
    // Fixes "Unsupported format ''" when Android temp files have no extension
    bool isWav = await _checkWavHeader(inputFile);
    if (isWav) {
      _logger.i("✅ Verified WAV via Header (RIFF): ${inputFile.path}");
      return inputFile;
    }

    // 3. If not WAV, we throw error because FFmpeg is disabled per requirements.
    _logger.e("❌ Unsupported format extension: '$extension' and invalid WAV header.");
    throw Exception(
      "Unsupported audio format. Please ensure you are recording or uploading a valid WAV file.\n"
      "Note: MP3/AAC conversion requires external libraries."
    );
  }

  Future<bool> _checkWavHeader(File file) async {
    try {
      // Read first 4 bytes
      final Stream<List<int>> stream = file.openRead(0, 4);
      final List<int> header = await stream.first;
      if (header.length < 4) return false;
      
      // Check for 'RIFF' in ASCII: 0x52, 0x49, 0x46, 0x46
      return header[0] == 0x52 && 
             header[1] == 0x49 && 
             header[2] == 0x46 && 
             header[3] == 0x46;
    } catch (e) {
      _logger.w("⚠️ Error reading file header: $e");
      return false;
    }
  }
}