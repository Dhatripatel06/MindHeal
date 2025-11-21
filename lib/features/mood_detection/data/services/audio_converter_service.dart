import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:flutter_sound/flutter_sound.dart';

class AudioConverterService {
  static final AudioConverterService _instance = AudioConverterService._internal();
  factory AudioConverterService() => _instance;
  AudioConverterService._internal();

  final Logger _logger = Logger();
  final FlutterSoundHelper _soundHelper = FlutterSoundHelper();

  Future<File> ensureWavFormat(File inputFile) async {
    // 1. Validate Input Existence and Size
    if (!await inputFile.exists() || await inputFile.length() == 0) {
      _logger.e("❌ Recording failed: File is empty or does not exist.");
      throw Exception("Recording failed (Empty File). Please try again.");
    }

    final String extension = p.extension(inputFile.path).toLowerCase();

    // 2. Check Header (Reliable for missing extensions)
    bool isWav = await _isWavHeader(inputFile);
    if (isWav) {
      _logger.i("✅ Verified WAV via Header: ${inputFile.path}");
      return inputFile;
    }

    _logger.i("🔄 Format '$extension' not standard WAV. Converting...");

    // 3. Convert fallback (MP3/AAC -> WAV)
    try {
      final tempDir = await getTemporaryDirectory();
      final String outputName = '${DateTime.now().millisecondsSinceEpoch}_converted.wav';
      final String outputPath = p.join(tempDir.path, outputName);
      final File outputFile = File(outputPath);

      if (await outputFile.exists()) await outputFile.delete();

      await _soundHelper.convertFile(
        inputFile.path,
        Codec.pcm16WAV,
        outputPath,
      );

      if (await outputFile.exists() && await outputFile.length() > 0) {
        return outputFile;
      } else {
        throw Exception("Conversion output is empty.");
      }
    } catch (e) {
      _logger.e("❌ Conversion Failed: $e");
      // Attempt to return original as Hail Mary, but likely will fail analysis
      return inputFile;
    }
  }

  Future<bool> _isWavHeader(File file) async {
    try {
      if (await file.length() < 44) return false;
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();
      
      // RIFF = 0x52, 0x49, 0x46, 0x46 | WAVE = 0x57, 0x41, 0x56, 0x45
      return header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
             header[8] == 0x57 && header[9] == 0x41 && header[10] == 0x56 && header[11] == 0x45;
    } catch (e) {
      return false;
    }
  }
}