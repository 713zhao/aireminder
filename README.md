# AI Reminder App

This folder contains the AI Reminder app - an intelligent todo and reminder application with smart scheduling.

Files added:
- `pubspec.yaml` — dependencies and metadata
- `lib/main.dart` — app entry
- `lib/screens/home.dart` — basic Home screen

Quick run (PowerShell on Windows):

```powershell
cd C:\ZJB\test
flutter pub get
flutter run
```

Notes:
- Ensure Flutter SDK is installed and on PATH. The editor may show analyzer errors until `flutter pub get` is run and the SDK is available.
- Next steps you can ask me to do: scaffold `lib/services/repeat_controller.dart`, implement `voice_service`, or create Android foreground bridge scaffolding.



Run locally:
    local network access: flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8888
    current pc debug: flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8888

build for web app:
    flutter build web
    cd build\web
    python -m http.server 8888 --bind 0.0.0.0

Web release and deployement:
    flutter build web --release   
    copy the web folder to https://dash.cloudflare.com/b4eb700e01a66453ef2d341ca0f6cce5/pages/view/spell


Build the APK
    ✅ Android support has been added with proper Gradle configuration
    
    flutter build apk --debug
    Profile APK (performance profiling):
    flutter build apk --profile
    Release APK (optimized for publishing):
    flutter build apk --release
    
    ✅ Latest successful build: 51.0MB app-release.apk (AI Reminder)
    
    4. Find the APK
    After building, the file is located in:
    project_folder/build/app/outputs/flutter-apk/app-release.apk
    5. (Optional) Split APKs by ABI
    To reduce file size:
    flutter build apk --split-per-abi
    This generates separate APKs for each architecture (e.g., armeabi-v7a, arm64-v8a, x86_64).

    👉 If you plan to publish on the Play Store, you might want to build an App Bundle (AAB) 
    flutter build appbundle --release
    project_folder/build/app/outputs/bundle/release/app-release.aab
    Google Play requires .aab files for new apps.
    
    ⚠️ Note: The project now includes Android configuration with:
    - Core library desugaring enabled (required for flutter_local_notifications)
    - Package name: com.aireminder
    - App name: AI Reminder
    - Min SDK: As defined by Flutter
    - Target SDK: As defined by Flutter
    - Internet permissions added for Firebase
    - Firebase Android configuration added
    - Google Services plugin configured
    - MultiDex enabled for Firebase support
    
    🛠️ Android Fixes Applied (2025-10-11):
    - Added INTERNET and ACCESS_NETWORK_STATE permissions to AndroidManifest.xml
    - Updated firebase_options.dart with platform-specific configurations  
    - Added Google Services plugin and google-services.json
    - Enabled MultiDex for Firebase compatibility
    - Updated Firebase initialization to use platform-specific options
    
    📱 Android Issues Fixed:
    1. Login popup should now work with proper Firebase configuration
    2. Delete confirmation dialogs should work with proper permissions and theming
    3. Task deletion now works - fixed 32-bit notification ID overflow issue
    
    🔧 Notification ID Fix (2025-10-11):
    - Added safeNotificationId() function to convert task IDs to 32-bit safe notification IDs
    - Updated all notification scheduling/canceling to use safe IDs
    - Updated payload format to include both taskId and notificationId
    - Fixed notification response handling for snooze/done actions

    🎤 Voice & UI Fixes (2025-10-12):
    - Fixed task form save issue: Added proper error handling and success messages
    - Fixed RenderFlex overflow in tasks list by making text flexible
    - Added microphone permissions (RECORD_AUDIO, MICROPHONE) for voice functionality
    - Improved VoiceButton error handling with user-friendly error messages
    - Task save now shows success messages and properly navigates back to home/list
    - Voice button should now appear and work properly on Android devices
    
    🔊 Voice Reminder Testing & Debug (2025-10-12):
    - Added manual voice reminder testing: Long-press any task to start/stop voice readout
    - Added TTS test button in Settings to verify voice functionality
    - Added overdue notification check on app startup (starts voice for recent overdue tasks)
    - Added comprehensive TTS debugging logs to help diagnose voice issues
    - Speaker icon (🔊) now appears next to tasks with active voice reminders
    - Voice reminders can be stopped by tapping the task or long-pressing again
    
    ⚠️ CRITICAL FIX: Past Date Notification Issue (2025-10-12):
    - Fixed "scheduledDate must be in the future" error when saving tasks
    - Past due dates now show immediate notification + start voice reminders
    - Added warning dialog when user selects past due dates
    - Improved error handling for notification scheduling failures
    - Tasks with past due dates are automatically marked as overdue with voice alerts
    
    🔧 CRITICAL FIX: Speaker Icon & Voice Control (2025-10-12):
    - Fixed speaker icon not appearing: Now uses correct notification IDs for matching
    - Fixed voice not stopping when tapping due events: Tap now properly stops voice
    - Fixed inconsistent ID usage between speaker display and voice control
    - Both tap and long-press now use safeNotificationId for consistent behavior
    - Speaker icon (🔊) now correctly appears when voice reminders are active
    
    🧹 UI Cleanup (2025-10-12):
    - Removed debug "Test Voice Reminder" button from Settings (testing via long-press tasks)
    - Removed debug "Check Device Time" button from Settings (no longer needed)
    - Cleaned up Settings page for production use
    - Kept "Reset audio priming" button as it's useful for troubleshooting
    
    📱 AdMob Integration (2025-10-12):
    - Integrated Google Mobile Ads SDK (google_mobile_ads: ^5.2.0)
    - Replaced custom ad bar with Google AdMob banner ads
    - Using Google's official test IDs for safe development/testing:
      * Test App ID: ca-app-pub-3940256099942544~3347511713
      * Test Banner ID: ca-app-pub-3940256099942544/6300978111
    - Added proper AdMob initialization in main.dart
    - Added AdMob App ID to Android manifest
    - Banner ads load with fallback display if ads fail to load