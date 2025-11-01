import 'package.google_generative_ai/google_generative_ai.dart';

class TranslationService {
  final GenerativeModel _model;

  // We can reuse the Gemini API key from your existing service
  TranslationService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash', // Use a fast model for translation
          apiKey: apiKey,
        );

  Future<String> translate(String text, String targetLanguage, String sourceLanguage) async {
    try {
      final prompt =
          "Translate the following text from $sourceLanguage to $targetLanguage. "
          "Respond with *only* the translated text, nothing else. "
          "Text: \"$text\"";
          
      final response = await _model.generateContent([Content.text(prompt)]);
      
      return response.text?.trim() ?? text;
    } catch (e) {
      print("Error in TranslationService: $e");
      // Fallback to original text in case of error
      return text; 
    }
  }
}