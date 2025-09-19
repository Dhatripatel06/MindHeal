import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class TFLiteInitialization {
  static Future<void> copyTFLiteLibraries() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String libPath = '${tempDir.path}/libtensorflowlite_c.so';
      
      // Check if library already exists
      if (!File(libPath).existsSync()) {
        // Copy from assets if available
        try {
          final ByteData data = await rootBundle.load('assets/lib/libtensorflowlite_c.so');
          final List<int> bytes = data.buffer.asUint8List();
          await File(libPath).writeAsBytes(bytes);
          print('✅ TensorFlow Lite library copied successfully');
        } catch (e) {
          print('⚠️ TensorFlow Lite library not found in assets: $e');
          // Library will be provided by the plugin
        }
      }
    } catch (e) {
      print('❌ Error copying TensorFlow Lite libraries: $e');
    }
  }
}