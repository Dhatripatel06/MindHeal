// File: lib/core/services/gemini_service.dart
// Fetched from: uploaded:dhatripatel06/mindheal/MindHeal-e7d11e8428e1bb750da91bf0de1b159359357573/lib/core/services/gemini_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart'; //

class GeminiService {
  // --- IMPORTANT: REPLACE WITH YOUR ACTUAL API KEY ---
  // Get your key from Google AI Studio: https://aistudio.google.com/app/apikey
  final String _apiKey = "AIzaSyB8N31cpFFUQ-qD0C1Yfxw1RzwqiuFP4x8"; //
  // ---

  GenerativeModel? _model; //
  final Logger _logger = Logger(); //

  GeminiService() {
    if (_apiKey.startsWith("<")) {
      //
      _logger.e(
          "API Key not set in gemini_service.dart. Replace <YOUR_API_KEY>."); //
    } else {
      try {
        _model = GenerativeModel(
          //
          // ******** FIX: Use a current, recommended model ********
          model: 'gemini-1.5-flash-latest', // Changed from 'gemini-pro'
          apiKey: _apiKey, //
        );
      } catch (e) {
        _logger.e("Failed to initialize Gemini Model", error: e); //
      }
    }
  }

  bool get isAvailable => _model != null; //

  Future<String?> getAdvice({
    required String mood,
    required String language, // 'English', 'Hindi', 'Gujarati' //
  }) async {
    if (_model == null) {
      //
      _logger.w("Gemini model not initialized, cannot get advice."); //
      return "Error: Advice service is currently unavailable (Model init failed)."; // More specific error
    }

    // --- Basic Prompt Engineering ---
    String targetLanguage; //
    switch (language.toLowerCase()) {
      //
      case 'hindi': //
        targetLanguage = 'Hindi'; //
        break;
      case 'gujarati': //
        targetLanguage = 'Gujarati'; //
        break;
      default:
        targetLanguage = 'English'; //
    }

    final prompt = '''
      You are a compassionate mental wellness assistant.
      A person is currently feeling "$mood".
      Provide brief, constructive, and supportive advice (2-3 short sentences) suitable for someone feeling this way.
      Respond ONLY in the $targetLanguage language. Do not include any introductory phrases like "Here is some advice:" or translations. Do not add quotation marks around your response.
      '''; // Added instruction to remove quotes
    // --- End Prompt ---

    _logger
        .i("Generating advice for mood: $mood in language: $targetLanguage"); //

    try {
      final content = [Content.text(prompt)]; //
      final response = await _model!.generateContent(content); //

      if (response.text != null && response.text!.isNotEmpty) {
        //
        _logger.i("Advice generated successfully."); //
        // Clean potential leading/trailing quotes or markdown
        return response.text!.trim().replaceAll(RegExp(r'^"|"$'), '').trim(); //
      } else {
        _logger.w("Received empty response from Gemini API."); //
        return "Sorry, I couldn't think of any advice right now."; //
      }
    } catch (e) {
      _logger.e("Error generating content with Gemini API", error: e); //
      // Provide a more specific error message based on the exception type if possible
      String errorMessage = "Sorry, an error occurred while getting advice.";
      if (e.toString().contains('not found for API version') ||
          e.toString().contains('not supported')) {
        errorMessage =
            "Error: Configured AI model is unavailable. Please check the GeminiService.";
      } else if (e.toString().contains('API key not valid')) {
        errorMessage = "Error: Invalid API Key for GeminiService.";
      }
      return errorMessage; // Return specific error message //
    }
  }
}
