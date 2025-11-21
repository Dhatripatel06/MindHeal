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
    // This handles cases where Android temp files might lack an extension
    try {
      if (await _isWavHeader(inputFile)) {
        _logger.i("✅ Verified WAV by header (RIFF): ${inputFile.path}");
        return inputFile;
      }
    } catch (e) {
      _logger.w("⚠️ Could not verify file header: $e");
    }

    // 3. Failure case
    // Since we cannot use FFmpeg, we cannot convert MP3/AAC to WAV.
    // We must inform the user to provide valid input.
    _logger.e("❌ Unsupported format: '$extension'");
    throw Exception(
      "Unsupported audio format ($extension). Please upload a valid WAV file.\n"
      "Automatic conversion is disabled to avoid FFmpeg dependency."
    );
  }

  Future<bool> _isWavHeader(File file) async {
    try {
      final Stream<List<int>> stream = file.openRead(0, 12);
      final List<int> header = await stream.first;
      if (header.length < 12) return false;
      
      // Check for 'RIFF' (0-3) and 'WAVE' (8-11) in ASCII
      // RIFF = 0x52, 0x49, 0x46, 0x46
      // WAVE = 0x57, 0x41, 0x56, 0x45
      bool hasRiff = header[0] == 0x52 && 
                     header[1] == 0x49 && 
                     header[2] == 0x46 && 
                     header[3] == 0x46;
                     
      bool hasWave = header[8] == 0x57 && 
                     header[9] == 0x41 && 
                     header[10] == 0x56 && 
                     header[11] == 0x45;
                     
      return hasRiff && hasWave;
    } catch (e) {
      return false;
    }
  }
}