import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';

class GeminiAdviserService {
  static const String _apiKey = AppConfig.geminiApiKey;
  late final GenerativeModel _model;

  static final GeminiAdviserService _instance =
      GeminiAdviserService._internal();
  factory GeminiAdviserService() => _instance;
  GeminiAdviserService._internal() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
        maxOutputTokens: 500,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// Get personalized emotional advice based on detected mood
  Future<String> getEmotionalAdvice({
    required String detectedEmotion,
    required double confidence,
    String? additionalContext,
    String language = 'English',
  }) async {
    try {
      log('Getting emotional advice for: $detectedEmotion with confidence: ${(confidence * 100).toInt()}% in $language');

      final prompt = _buildAdvicePrompt(
        emotion: detectedEmotion,
        confidence: confidence,
        context: additionalContext,
        language: language,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        log('Received advice response: ${response.text!.substring(0, 100)}...');
        return response.text!;
      } else {
        throw Exception('Empty response from Gemini API');
      }
    } catch (e) {
      log('Error getting emotional advice: $e');
      return _getFallbackAdvice(detectedEmotion, language);
    }
  }

  /// Build personalized prompt based on emotion and context
  String _buildAdvicePrompt({
    required String emotion,
    required double confidence,
    String? context,
    String language = 'English',
  }) {
    final confidenceLevel = _getConfidenceDescription(confidence);
    final languageInstruction = _getLanguageInstruction(language);

    return '''
You are MindHeal AI, a compassionate and professional mental wellness counselor and supportive friend. A person has just had their emotional state analyzed, and you need to provide personalized, empathetic advice.

**Analysis Results:**
- Detected Emotion: ${emotion.toUpperCase()}
- Confidence Level: ${(confidence * 100).toInt()}% ($confidenceLevel)
${context != null ? '- Additional Context: $context' : ''}

**Language Requirement:**
$languageInstruction

**Your Role:**
Act as both a caring friend and a professional counselor. Provide advice that is:
- Warm, empathetic, and understanding
- Practical and actionable
- Supportive without being overly clinical
- Encouraging and hope-filled
- Personalized to the specific emotion detected

**Response Guidelines:**
1. Start with validation and understanding of their current emotional state
2. Provide 2-3 specific, actionable suggestions tailored to this emotion
3. Include a gentle encouragement or affirmation
4. Keep the tone conversational yet professional
5. Limit response to 3-4 sentences for easy reading
6. Use "you" to make it personal

**Emotion-Specific Focus:**
${_getEmotionSpecificGuidance(emotion)}

Please provide your compassionate advice now:
''';
  }

  /// Get emotion-specific guidance for the prompt
  String _getEmotionSpecificGuidance(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return 'For happiness: Help them savor and extend this positive state, suggest ways to share joy with others, and encourage mindful appreciation of the moment.';

      case 'sad':
      case 'sadness':
        return 'For sadness: Offer gentle comfort, validate their feelings, suggest healthy coping mechanisms, and remind them that this feeling is temporary.';

      case 'angry':
      case 'anger':
        return 'For anger: Help them process this emotion safely, suggest breathing techniques, physical outlets, and ways to address the underlying cause constructively.';

      case 'fear':
        return 'For fear: Provide reassurance, suggest grounding techniques, breathing exercises, and gentle ways to face or understand their concerns.';

      case 'surprise':
        return 'For surprise: Help them process unexpected events, suggest ways to adapt to new situations, and encourage openness to change.';

      case 'disgust':
        return 'For disgust: Help them identify what triggered this feeling, suggest healthy boundaries, and ways to process difficult experiences.';

      case 'neutral':
        return 'For neutral state: Encourage self-reflection, suggest activities for emotional growth, and ways to connect with their inner feelings.';

      default:
        return 'Focus on providing general emotional support and practical coping strategies appropriate for their current state.';
    }
  }

  /// Get confidence level description
  String _getConfidenceDescription(double confidence) {
    if (confidence >= 0.9) return 'Very High Accuracy';
    if (confidence >= 0.8) return 'High Accuracy';
    if (confidence >= 0.7) return 'Good Accuracy';
    if (confidence >= 0.6) return 'Moderate Accuracy';
    return 'Lower Accuracy';
  }

  /// Get language-specific instructions for the AI
  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'हिंदी':
        return 'Please respond in Hindi (हिंदी) language using Devanagari script. Use natural, compassionate Hindi expressions that feel warm and supportive.';
      case 'ગુજરાતી':
        return 'Please respond in Gujarati (ગુજરાતી) language using Gujarati script. Use natural, compassionate Gujarati expressions that feel warm and supportive.';
      case 'English':
      default:
        return 'Please respond in English language using clear, compassionate expressions that feel warm and supportive.';
    }
  }

  /// Provide fallback advice when API fails
  String _getFallbackAdvice(String emotion, [String language = 'English']) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return "What a wonderful moment! 😊 This happiness you're feeling is precious - take a moment to really savor it. Consider sharing this joy with someone you care about, or write down what made you feel this way. Remember, you have the power to create more moments like this.";

      case 'sad':
      case 'sadness':
        return "I can see you're going through a difficult time right now. 💙 It's completely okay to feel sad - these emotions are valid and part of being human. Try taking some deep breaths, reaching out to a trusted friend, or engaging in a gentle activity that usually comforts you. This feeling will pass, and brighter days are ahead.";

      case 'angry':
      case 'anger':
        return "I understand you're feeling frustrated or angry right now. 🔥 Take a few deep breaths and count to ten. Consider going for a walk, doing some physical exercise, or writing down your thoughts. Remember, it's okay to feel angry, but how you express it matters. You have the strength to handle this constructively.";

      case 'fear':
        return "I can sense you're feeling anxious or fearful. 🤗 Remember that you're stronger than you know. Try the 5-4-3-2-1 grounding technique: name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, and 1 you taste. Take slow, deep breaths. You've overcome challenges before, and you can do it again.";

      case 'surprise':
        return "Looks like something unexpected happened! 😮 Surprises can be overwhelming, but they're also opportunities for growth. Take a moment to process what you're feeling. Sometimes the best things come from unexpected changes. Trust in your ability to adapt and make the most of new situations.";

      case 'disgust':
        return "I can see something has really bothered you. 😔 It's important to acknowledge these feelings and understand what triggered them. Consider removing yourself from the situation if possible, practice some calming techniques, and remember that you have the right to set healthy boundaries.";

      case 'neutral':
        return "You seem to be in a calm, balanced state right now. 😌 This is actually a wonderful opportunity for self-reflection and planning. Consider what you'd like to feel or achieve today. Sometimes our most peaceful moments give us clarity about what truly matters to us.";

      default:
        return "Whatever you're feeling right now is valid and important. 💙 Take a moment to acknowledge your emotions without judgment. Remember that feelings are temporary visitors - they come and go. You have the strength to navigate through this, and it's okay to ask for support when you need it.";
    }
  }

  /// Get appropriate emoji for emotion
  String getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return '😊';
      case 'sad':
      case 'sadness':
        return '💙';
      case 'angry':
      case 'anger':
        return '🔥';
      case 'fear':
        return '🤗';
      case 'surprise':
        return '😮';
      case 'disgust':
        return '😔';
      case 'neutral':
        return '😌';
      default:
        return '💙';
    }
  }

  /// Check if the service is properly configured
  bool get isConfigured =>
      _apiKey != 'AIzaSyCo-W4OLgEIx0mKVIqdMmlsk7XydSTmDw4' && _apiKey.isNotEmpty;
}
