class EmotionResult {
  final String dominantEmotion;
  final double confidence;
  final Map<String, double> allEmotions;
  final DateTime timestamp;
  final String analysisType;

  EmotionResult({
    required this.dominantEmotion,
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.analysisType,
  });

  Map<String, dynamic> toJson() {
    return {
      'dominantEmotion': dominantEmotion,
      'confidence': confidence,
      'allEmotions': allEmotions,
      'timestamp': timestamp.toIso8601String(),
      'analysisType': analysisType,
    };
  }

  factory EmotionResult.fromJson(Map<String, dynamic> json) {
    return EmotionResult(
      dominantEmotion: json['dominantEmotion'],
      confidence: json['confidence'],
      allEmotions: Map<String, double>.from(json['allEmotions']),
      timestamp: DateTime.parse(json['timestamp']),
      analysisType: json['analysisType'],
    );
  }
}
