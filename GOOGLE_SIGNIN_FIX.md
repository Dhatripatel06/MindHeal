# Google Sign-in Fix Instructions

## Current Issue
The error shows: "PlatformException(channel-error, Unable to establish connection on channel: 'dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi.init'"

## Root Cause
This is typically caused by:
1. Incorrect SHA-1 fingerprint in Firebase Console
2. Missing OAuth client configuration
3. Missing Google Sign-in configuration in Android

## Current Configuration Status
✅ **SHA-1 Fingerprint**: `15:FE:8C:71:89:B3:D8:F8:E1:1F:1F:5C:99:A3:63:AD:61:CD:0A:94`
✅ **Package Name**: `com.mentalwellness.app`
✅ **google-services.json**: Present and correctly configured

## Fix Steps

### Step 1: Update Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `mental-wellness-app-64cb6`
3. Go to **Project Settings** → **General** → **Your apps**
4. Find your Android app (`com.mentalwellness.app`)
5. Scroll down to **SHA certificate fingerprints**
6. Ensure this SHA-1 is added: `15:FE:8C:71:89:B3:D8:F8:E1:1F:1F:5C:99:A3:63:AD:61:CD:0A:94`

### Step 2: Configure Google Sign-in
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** provider
3. Add your email as a test user
4. Copy the **Web client ID** from the Google provider settings

### Step 3: Add Web Client ID to App
Add this to your `android/app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="default_web_client_id">934484241138-klno99cg01iiildql4lfkpc76qh2bjqj.apps.googleusercontent.com</string>
</resources>
```

### Step 4: Clean and Rebuild
```bash
cd "c:\Users\PC\mental_wellness_a"
flutter clean
flutter pub get
cd android
.\gradlew clean
cd ..
flutter run
```

### Step 5: Alternative Fix - Update google-services.json
If the above doesn't work, download a fresh `google-services.json` from Firebase Console and replace the existing one.

## Test the Fix
After implementing the steps above, test Google Sign-in to ensure it works correctly.