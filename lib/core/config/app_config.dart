class AppConfig {
  // Gemini API Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue:
        'AIzaSyAlMRu3tsO7ShCnB3uoOWWOMdpO0OnWyO0', // Replace with your actual API key
  );

  // Add other configuration constants here
  static const String appName = 'MindHeal';
  static const String appVersion = '1.0.0';

  // Feature flags
  static const bool enableGeminiAdviser = true;
  static const bool enableDebugMode = false;
}
