// File: lib/core/services/gemini_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';

class GeminiService {
  // --- *** MOST LIKELY CAUSE OF API ERROR: Ensure this key is VALID, NEW, and the associated project has the API ENABLED *** ---
  final String _apiKey = "<AIzaSyB8N31cpFFUQ-qD0C1Yfxw1RzwqiuFP4x8>"; // Replace with your actual, valid key
  // ---

  GenerativeModel? _model;
  final Logger _logger = Logger();
  // Store the model name used for initialization
  final String _modelName = 'gemini-pro'; // Using the standard model name

  GeminiService() {
    if (_apiKey.startsWith("<")) {
      _logger.e("API Key not set in gemini_service.dart. Replace <YOUR_API_KEY>.");
    } else {
      try {
        _model = GenerativeModel(
          model: _modelName, // Use the stored name
          apiKey: _apiKey,
        );
         _logger.i("GeminiService initialized with model: $_modelName");
      } catch (e) {
        _logger.e("Failed to initialize Gemini Model", error: e);
      }
    }
  }

  bool get isAvailable => _model != null;

  Future<String?> getAdvice({
    required String mood,
    required String language,
  }) async {
    if (_model == null) {
      _logger.w("Gemini model not initialized, cannot get advice.");
      return "Error: Advice service is currently unavailable (Model init failed).";
    }

    String targetLanguage;
    switch (language.toLowerCase()) {
      case 'hindi': targetLanguage = 'Hindi'; break;
      case 'gujarati': targetLanguage = 'Gujarati'; break;
      default: targetLanguage = 'English';
    }

    final prompt = '''
      You are a compassionate mental wellness assistant.
      A person is currently feeling "$mood".
      Provide brief, constructive, and supportive advice (2-3 short sentences) suitable for someone feeling this way.
      Respond ONLY in the $targetLanguage language. Do not include any introductory phrases like "Here is some advice:" or translations. Do not add quotation marks around your response.
      ''';

    // ******** FIX: Removed invalid access to '.model' ********
    _logger.i("Generating advice for mood: $mood in language: $targetLanguage with model: $_modelName"); // Log the stored name

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        _logger.i("Advice generated successfully.");
        return response.text!.trim().replaceAll(RegExp(r'^"|"$'), '').trim();
      } else {
        _logger.w("Received empty response from Gemini API.");
        if (response.promptFeedback?.blockReason != null) {
            _logger.w("Response blocked. Reason: ${response.promptFeedback?.blockReason}");
            return "Error: Request blocked for safety reasons (${response.promptFeedback?.blockReason}).";
        }
        return "Sorry, I couldn't think of any advice right now.";
      }
    } catch (e) {
      _logger.e("Error generating content with Gemini API", error: e);
      String errorMessage = "Sorry, an error occurred while getting advice.";
      final eString = e.toString().toLowerCase();
      if (eString.contains('api key not valid')) {
          errorMessage = "Error: Invalid API Key. Please check GeminiService.";
      } else if (eString.contains('not found') || eString.contains('not supported')) {
           // ******** FIX: Log the correct model name variable ********
          errorMessage = "Error: Configured AI model ($_modelName) unavailable. Check API key project permissions or model name in GeminiService.";
      } else if (eString.contains('quota') || eString.contains('limit')) {
           errorMessage = "Error: API quota exceeded. Please check your usage limits.";
      } else if (eString.contains('billing')) {
          errorMessage = "Error: Billing issue with the associated Google Cloud project.";
      } else if (eString.contains('permission denied')) {
           errorMessage = "Error: Permission denied. Ensure the Generative AI API is enabled in your Google Cloud project.";
      }
      return errorMessage;
    }
  }
}