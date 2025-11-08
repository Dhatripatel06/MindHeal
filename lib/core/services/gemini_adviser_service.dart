// lib/core/services/gemini_adviser_service.dart
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
// Import flutter_dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiAdviserService {
  // Make the instance nullable and static
  static GeminiAdviserService? _instance;

  // Make the model and key late final instance variables
  late final GenerativeModel _model;
  late final String _modelName;
  late final String _apiKey;

  // Private constructor now takes the key
  GeminiAdviserService._internal(this._apiKey) {
    _modelName = 'gemini-1.5-flash-latest'; // Use a standard, available model
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
        maxOutputTokens: 1000,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  // Factory constructor now initializes the singleton on first use
  factory GeminiAdviserService() {
    // If the instance doesn't exist, create it.
    if (_instance == null) {
      // Read the key from dotenv *now*. By this time, main() should have run.
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'MISSING_GEMINI_KEY';
      _instance = GeminiAdviserService._internal(apiKey);
    }
    return _instance!;
  }

  // --- NEW METHOD for Audio "Friend" Feature ---
  /// Get a conversational response based on user's speech and emotion.
  Future<String> getConversationalAdvice({
    required String userSpeech,
    required String detectedEmotion,
    String? userName,
    String language = 'English', // Target language for the AI's response
  }) async {
    try {
      log('🤖 Getting conversational advice for: "$userSpeech" (Emotion: $detectedEmotion) in $language');

      final prompt = _buildConversationalPrompt(
        userSpeech: userSpeech,
        emotion: detectedEmotion,
        language: language,
        userName: userName,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      } else {
        log('❌ Empty response from Gemini API for conversational advice');
        throw Exception('Empty response from Gemini API');
      }
    } catch (e) {
      log('❌ Error getting conversational advice: $e');
      // --- *** FIX: This method is now defined below *** ---
      return _getFallbackAdvice(detectedEmotion, language);
    }
  }

  /// Build personalized prompt for the virtual friend
  String _buildConversationalPrompt({
    required String userSpeech,
    required String emotion,
    String language = 'English',
    String? userName,
  }) {
    final languageInstruction = _getLanguageInstruction(language);
    final userNameInfo =
        userName != null ? " The user's name is $userName." : "";

    return '''
    You are MindHeal AI, a compassionate, warm, and wise virtual best friend and counselor.
    A user is talking to you. You have analyzed WHAT they said and HOW they said it (their emotional tone).$userNameInfo

    **CRITICAL LANGUAGE REQUIREMENT:**
    $languageInstruction

    **Analysis of User's Input:**
    - **What they said (Text):** "$userSpeech"
    - **How they said it (Emotion):** ${emotion.toUpperCase()}

    **Your Role & Guidelines:**
    1.  **Act as a supportive friend, NOT a robot.** Be warm, empathetic, and conversational. Use "you".
    2.  **Acknowledge BOTH text and emotion.** This is crucial.
    3.  **If Text and Emotion conflict** (e.g., Text: "I'm fine", Emotion: "SAD"), gently explore it.
        (e.g., "You say you're fine, but I'm sensing some sadness in your voice. It's okay to not be okay. What's on your mind?")
    4.  **If Text and Emotion match** (e.g., Text: "I'm so tired of this", Emotion: "SAD"), validate their feelings.
        (e.g., "I hear that. It sounds like you're feeling completely exhausted and sad, and that's a really tough place to be.")
    5.  **Handle distressing text (like "I an tired of this life i don't want this life") with extreme care:**
        -   Validate their pain immediately (e.g., "I hear how much pain you're in. That sounds incredibly heavy and difficult.").
        -   Offer gentle, hopeful perspective (e.g., "Please hold on. That feeling, as overwhelming as it is, can pass. Life is very beautiful, and there is strength in you, even when it's hard to see. God is with you. Let's focus just on this moment.").
    6.  **Handle positive text/emotion** (e.g., "I think I am good today"):
        -   Encourage them! (e.g., "That's wonderful to hear! And why just 'think' you are good? Be actual good! Live your life, enjoy it! What's making today feel good?")
    7.  **Keep responses to 2-4 supportive sentences.**
    
    Please provide your compassionate, friendly response now:
    ''';
  }

  // --- ORIGINAL METHOD for Image Detection ---
  /// Get personalized emotional advice based on detected mood (for images/camera)
  Future<String> getEmotionalAdvice({
    required String detectedEmotion,
    required double confidence,
    String? additionalContext,
    String language = 'English',
  }) async {
    // --- THIS IS THE FIX ---
    // Check if the API key is loaded *before* trying to make a call.
    if (!isConfigured) {
      log('❌ GeminiAdviserService is not configured. API key is missing or is a placeholder. Returning fallback.');
      log('❌ Current key: $_apiKey'); // This will show you what's loaded (or not)
      return _getFallbackAdvice(detectedEmotion, language);
    }
    // --- END OF FIX ---

    try {
      log('🤖 Getting emotional advice for: $detectedEmotion with confidence: ${(confidence * 100).toInt()}% in $language');
      log('🔑 API Key configured: ${isConfigured}');

      final prompt = _buildAdvicePrompt(
        emotion: detectedEmotion,
        confidence: confidence,
        context: additionalContext,
        language: language,
      );

      log('📝 Generated prompt length: ${prompt.length} characters');
      log('📝 First 200 chars of prompt: ${prompt.substring(0, prompt.length > 200 ? 200 : prompt.length)}...');

      final content = [Content.text(prompt)];

      log('🌐 Calling Gemini API with model: $_modelName');
      final response = await _model.generateContent(content);

      log('📨 Received response from Gemini API');

      if (response.text != null && response.text!.isNotEmpty) {
        log('✅ Received advice response length: ${response.text!.length} characters');
        log('✅ First 100 chars: ${response.text!.substring(0, response.text!.length > 100 ? 100 : response.text!.length)}...');
        return response.text!;
      } else {
        log('❌ Empty response from Gemini API for emotional advice');
        throw Exception('Empty response from Gemini API');
      }
    } catch (e) {
      log('❌ Error getting emotional advice: $e');
      log('🔄 Using fallback advice for $detectedEmotion in $language');
      // --- *** FIX: This method is now defined below *** ---
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

**CRITICAL LANGUAGE REQUIREMENT:**
$languageInstruction

**Analysis Results:**
- Detected Emotion: ${emotion.toUpperCase()}
- Confidence Level: ${(confidence * 100).toInt()}% ($confidenceLevel)
${context != null ? '- Additional Context: $context' : ''}

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

  // --- *** ALL HELPER METHODS ARE NOW INCLUDED *** ---

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
        return '''
IMPORTANT: You MUST respond ONLY in Hindi (हिंदी) language using Devanagari script. 
- Do NOT use any English words in your response
- Use natural, compassionate Hindi expressions
- Write everything in Hindi including all advice, techniques, and encouragement
- Example of proper Hindi response style: "मैं समझ सकता हूं कि आप चिंतित या डरे हुए महसूस कर रहे हैं..."
''';
      case 'ગુજરાતી':
        return '''
IMPORTANT: You MUST respond ONLY in Gujarati (ગુજરાતી) language using Gujarati script.
- Do NOT use any English words in your response
- Use natural, compassionate Gujarati expressions
- Write everything in Gujarati including all advice, techniques, and encouragement
- Example of proper Gujarati response style: "હું સમજી શકું છું કે તમે ચિંતિત અથવા ડરતા અનુભવો છો..."
''';
      case 'English':
      default:
        return 'Please respond in clear, compassionate English language that feels warm and supportive.';
    }
  }

  /// Provide fallback advice when API fails
  String _getFallbackAdvice(String emotion, [String language = 'English']) {
    if (language == 'हिंदी') {
      return _getHindiFallbackAdvice(emotion);
    } else if (language == 'ગુજરાતી') {
      return _getGujaratiFallbackAdvice(emotion);
    }

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

  /// Hindi fallback advice
  String _getHindiFallbackAdvice(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return "क्या अद्भुत क्षण है! 😊 आपकी यह खुशी बहुत कीमती है - इसे महसूस करने के लिए एक पल रुकें। इस खुशी को किसी अपने के साथ साझा करने पर विचार करें। याद रखें, आपके पास ऐसे और पल बनाने की शक्ति है।";

      case 'sad':
      case 'sadness':
        return "मैं देख सकता हूं कि आप इस समय कठिन दौर से गुजर रहे हैं। 💙 उदास होना बिल्कुल सामान्य है - ये भावनाएं वैध हैं। कुछ गहरी सांसें लें, किसी विश्वसनीय मित्र से बात करें। यह भावना बीत जाएगी, और उज्जवल दिन आने वाले हैं।";

      case 'angry':
      case 'anger':
        return "मैं समझ सकता हूं कि आप इस समय गुस्से में हैं। 🔥 कुछ गहरी सांसें लें और दस तक गिनती करें। टहलने जाने या कुछ शारीरिक व्यायाम करने पर विचार करें। याद रखें, गुस्सा होना ठीक है, लेकिन इसे कैसे व्यक्त करते हैं यह मायने रखता है।";

      case 'fear':
        return "मैं समझ सकता हूं कि आप चिंतित या डरे हुए महसूस कर रहे हैं। 🤗 याद रखें कि आप जितना सोचते हैं उससे कहीं अधिक मजबूत हैं। ५-४-३-२-१ ग्राउंडिंग तकनीक आजमाएं: ५ चीजें जो आप देखते हैं, ४ जिन्हें छू सकते हैं, ३ जो सुनते हैं, २ जिन्हें सूंघ सकते हैं, और १ जिसका स्वाद ले सकते हैं। धीमी, गहरी सांसें लें।";

      case 'surprise':
        return "लगता है कुछ अप्रत्याશિત हुआ है! 😮 आश्चर्य भारी लग सकता है, लेकिन ये विकास के अवसर भी होते हैं। एक पल लेकर सोचें कि आप क्या महसूस कर रहे हैं। कभी-कभी सबसे अच्छी चीजें अप्रत्याशित बदलावों से आती हैं।";

      case 'disgust':
        return "मैं देख सकता हूं कि कुछ चीज आपको परेशान कर रही है। 😔 इन भावनाओं को स्वीकार करना और समझना महत्वपूर्ण है कि इन्हें क्या ट्रिગર करता है। यदि संभव हो तो स्थिति से खुद को दूर करें, कुछ शांत करने वाली तकनीकें अपनाएं।";

      case 'neutral':
        return "आप इस समय शांत, संतुलित अवस्था में लग रहे हैं। 😌 यह वास्तव में आत्मचिंतन और योजना बनाने का एक अद्भुत अवसर है। सोचें कि आप आज क्या महसूस करना या हासिल करना चाहते हैं।";

      default:
        return "आप इस समय जो भी महसूस कर रहे हैं वह वैध और महत्वपूर्ण है। 💙 अपनी भावनाओं को बिना किसी जजमेंट के स्वीकार करने के लिए एक पल लें। याद रखें कि भावनाएं अस्थायी आगंतુક हैं। आपमें इससे निपटने की शक्ति है।";
    }
  }

  /// Gujarati fallback advice
  String _getGujaratiFallbackAdvice(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return "કેટલો અદ્ભુત ક્ષણ છે! 😊 તમારી આ ખુશી ખૂબ કીમતી છે - આને અનુભવવા માટે એક ક્ષણ રોકાઓ. આ આનંદને કોઈ પ્રિયજન સાથે શેર કરવાનું વિચારો. યાદ રાખો, તમારી પાસે આવી વધુ ક્ષણો બનાવવાની શક્તિ છે.";

      case 'sad':
      case 'sadness':
        return "હું જોઈ શકું છું કે તમે આ સમયે કઠિન દોરમાંથી પસાર થઈ રહ્યા છો. 💙 ઉદાસ થવું સાવ સામાન્ય છે - આ લાગણીઓ યોગ્ય છે. થોડી ઊંડી શ્વાસ લો, કોઈ વિશ્વસનીય મિત્ર સાથે વાત કરો. આ લાગણી પસાર થઈ જશે, અને ઉજળા દિવસો આવનારા છે.";

      case 'angry':
      case 'anger':
        return "હું સમજી શકું છું કે તમે આ સમયે ગુસ્સામાં છો. 🔥 થોડી ઊંડી શ્વાસ લો અને દસ સુધી ગણતરી કરો. ફરવા જવાનું અથવા થોડી શારીરિક કસરત કરવાનું વિચારો. યાદ રાખો, ગુસ્સો થવો ઠીક છે, પરંતુ તેને કેવી રીતે વ્યક્ત કરો છો તે મહત્વનું છે.";

      case 'fear':
        return "હું સમજી શકું છું કે તમે ચિંતિત અથવા ડરતા અનુભવો છો. 🤗 યાદ રાખો કે તમે તમે વિચારો છો તેના કરતાં વધુ મજબૂત છો. ૫-૪-૩-૨-૧ ગ્રાઉન્ડિંગ ટેકનિક અજમાવો: ૫ વસ્તુઓ જે તમે જુઓ છો, ૪ જેને સ્પર્શ કરી શકો, ૩ જે સાંભળો, ૨ જેની સુગંધ લઈ શકો, અને ૧ જેનો સ્વાદ લઈ શકો. ધીમી, ઊંડી શ્વાસ લો.";

      case 'surprise':
        return "લાગે છે કંઈક અણધાર્યું થયું છે! 😮 આશ્ચર્ય ભારે લાગી શકે, પરંતુ તે વિકાસની તકો પણ હોય છે. એક ક્ષણ લઈને વિચારો કે તમે શું અનુભવો છો. કેટલીકવાર શ્રેષ્ઠ વસ્તુઓ અણધાર્યા ફેરફારોથી આવે છે.";

      case 'disgust':
        return "હું જોઈ શકું છું કે કંઈક વસ્તુ તમને પરેશાન કરી રહી છે. 😔 આ લાગણીઓને સ્વીકારવી અને સમજવી મહત્વપૂર્ણ છે કે તેમને શું ટ્રિગર કરે છે. જો શક્ય હોય તો સ્થિતિથી તમારી જાતને દૂર કરો, કેટલીક શાંત કરનારી તકનીકો અપનાવો.";

      case 'neutral':
        return "તમે આ સમયે શાંત, સંતુલિત અવસ્થામાં લાગો છો. 😌 આ ખરેખર આત્મચિંતન અને યોજના બનાવવાની અદ્ભુત તક છે. વિચારો કે તમે આજે શું અનુભવવા અથવા હાંસલ કરવા માંગો છો.";

      default:
        return "તમે આ સમયે જે પણ અનુભવો છો તે યોગ્ય અને મહત્વપૂર્ણ છે. 💙 તમારી લાગણીઓને કોઈ ન્યાય કર્યા વિના સ્વીકારવા માટે એક ક્ષણ લો. યાદ રાખો કે લાગણીઓ અસ્થાયી મુલાકાતીઓ છે. તમારામાં આનો સામનો કરવાની શક્તિ છે.";
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

  /// Test API connection and model availability
  Future<bool> testApiConnection() async {
    try {
      log('🧪 Testing Gemini API connection...');

      if (!isConfigured) {
        log('❌ API key not configured properly');
        return false;
      }

      final testPrompt =
          'Respond with "API_TEST_SUCCESS" if you can read this message.';
      final content = [Content.text(testPrompt)];

      final response = await _model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        log('✅ API test successful. Response: ${response.text}');
        return true;
      } else {
        log('❌ API test failed: Empty response');
        return false;
      }
    } catch (e) {
      log('❌ API test failed with error: $e');
      return false;
    }
  }

  /// Check if the service is properly configured
  bool get isConfigured =>
      _apiKey != 'AIzaSyCo-W4OLgEIx0mKVIqdMmlsk7XydSTmDw4' && // Example key
      _apiKey != 'YOUR_API_KEY_HERE' &&
      _apiKey != 'MISSING_GEMINI_KEY' &&
      _apiKey.isNotEmpty;

  /// Public accessor for fallback advice so other libraries can call it
  String getFallbackAdvice(String emotion, [String language = 'English']) {
    return _getFallbackAdvice(emotion, language);
  }
}