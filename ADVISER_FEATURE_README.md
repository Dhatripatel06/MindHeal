# MindHeal Adviser Feature Setup

## Features Added

### 1. Multilingual AI Adviser
- **Languages Supported**: English, Hindi (हिंदी), Gujarati (ગુજરાતી)
- **AI-Powered**: Uses Google Gemini AI for personalized emotional counseling
- **Humanoid Approach**: Acts as both a caring friend and professional counselor

### 2. Text-to-Speech Integration
- **Read Aloud**: AI advice can be read aloud in the selected language
- **Language-Specific TTS**: Supports proper pronunciation for Hindi and Gujarati
- **Speech Controls**: Play, Pause, Resume, and Stop functionality
- **Visual Feedback**: Real-time indication of speech status

### 3. Emotional Context Awareness
- **Emotion-Specific Guidance**: Tailored advice based on detected emotion
- **Confidence Level Integration**: Advice quality consideration based on detection accuracy
- **Fallback System**: Offline advice when API is unavailable

## Setup Instructions

### 1. Get Gemini API Key
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new API key
4. Copy the generated API key

### 2. Configure API Key
Update the API key in: `lib/core/config/app_config.dart`
```dart
static const String geminiApiKey = 'YOUR_ACTUAL_GEMINI_API_KEY_HERE';
```

### 3. Permissions
Ensure the following permissions are in your `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## How to Use

### 1. Detect Mood
1. Open the Image Mood Detection feature
2. Capture or select an image
3. Wait for AI analysis to complete

### 2. Get Advice
1. Click the "Adviser" button (purple button with psychology icon)
2. Select your preferred language (English/Hindi/Gujarati)
3. Wait for personalized advice to load

### 3. Listen to Advice
1. Use the "Read Aloud" section in the advice dialog
2. Click Play button to start speech
3. Use Pause/Resume as needed
4. Click Stop to end speech

## Features Overview

### Language Switching
- Instant language change with automatic advice regeneration
- UI elements translated to selected language
- TTS configured for proper language pronunciation

### Speech Controls
- **Play**: Start reading the advice aloud
- **Pause**: Temporarily stop speech
- **Resume**: Continue from where paused
- **Stop**: End speech completely

### Error Handling
- Graceful fallback to offline advice if API fails
- Network error detection and user feedback
- Retry functionality for failed requests

## File Structure

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart           # API configuration
│   └── services/
│       └── gemini_adviser_service.dart # AI service
├── features/
│   └── mood_detection/
│       ├── presentation/
│       │   ├── pages/
│       │   │   └── image_mood_detection_page.dart # Updated with adviser button
│       │   └── widgets/
│       │       └── advice_dialog.dart  # New multilingual TTS dialog
```

## Troubleshooting

### Common Issues

1. **No Advice Loading**
   - Check internet connection
   - Verify API key is correctly set
   - Check if you have API quota remaining

2. **TTS Not Working**
   - Ensure device volume is up
   - Check if TTS language pack is installed
   - Try switching between languages

3. **Language Display Issues**
   - Ensure device supports Unicode fonts
   - Check if language fonts are available on the device

### Development Notes

- The adviser service includes comprehensive error handling
- Fallback advice is provided in multiple languages
- TTS initialization is handled asynchronously
- All UI text is properly localized

## Next Steps

To further enhance the feature:
1. Add more languages
2. Implement voice input for emotion context
3. Add emotion history tracking
4. Create personalized advice based on user patterns