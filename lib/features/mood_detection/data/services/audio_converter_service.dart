import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

class AudioConverterService {
  static final AudioConverterService _instance = AudioConverterService._internal();
  factory AudioConverterService() => _instance;
  AudioConverterService._internal();

  final Logger _logger = Logger();

  /// Ensures the audio file is a valid PCM WAV.
  /// Since FFmpeg is disabled, we strictly enforce WAV inputs.
  Future<File> ensureWavFormat(File inputFile) async {
    final String extension = p.extension(inputFile.path).toLowerCase();

    // 1. Fast Check: Extension
    if (extension == '.wav') {
      _logger.i("✅ File has .wav extension: ${inputFile.path}");
      return inputFile;
    }

    // 2. Robust Check: Magic Bytes (RIFF Header)
    // This fixes "Unsupported format" errors when temp files lack extensions
    if (await _isWavHeader(inputFile)) {
      _logger.i("✅ Verified WAV via Header (RIFF): ${inputFile.path}");
      return inputFile;
    }

    // 3. Failure
    _logger.e("❌ Unsupported format: '$extension'");
    throw Exception(
      "Unsupported audio format ($extension). Please ensure you are recording or uploading a valid WAV file."
    );
  }

  /// Reads first 12 bytes to check for RIFF....WAVE header
  Future<bool> _isWavHeader(File file) async {
    try {
      if (await file.length() < 44) return false; // Header is 44 bytes
      
      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      final List<int> header = await raf.read(12);
      await raf.close();
      
      if (header.length < 12) return false;
      
      // Check 'RIFF' (Bytes 0-3) in ASCII: 0x52, 0x49, 0x46, 0x46
      // Check 'WAVE' (Bytes 8-11) in ASCII: 0x57, 0x41, 0x56, 0x45
      bool hasRiff = header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46;
      bool hasWave = header[8] == 0x57 && header[9] == 0x41 && header[10] == 0x56 && header[11] == 0x45;
      
      return hasRiff && hasWave;
    } catch (e) {
      _logger.w("⚠️ Error reading file header: $e");
      return false;
    }
  }
}