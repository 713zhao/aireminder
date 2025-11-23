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
    
    ⚠️ Note: Development server may have different behavior than production build
    For latest AI image compression features, use the production build instead:

build for web app:
    flutter build web
    cd build\web
    python -m http.server 8888 --bind 0.0.0.0

Web release and deployment:
    flutter build web --release   
    copy the web folder to https://dash.cloudflare.com/b4eb700e01a66453ef2d341ca0f6cce5/pages/view/spell
    
    ✅ Latest update (2025-10-18): Added AI image compression system
    - Automatic compression to 512KB for both camera and gallery images
    - Two-layer compression: ImagePicker + Smart compression
    - Works on both web and Android platforms
    - Eliminates MAX_TOKENS errors from large images
    - Production build required for latest compression features


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
    - Configured with production AdMob IDs:
      * Production App ID: ca-app-pub-3737089294643612~3737089294
      * Production Banner ID: ca-app-pub-3737089294643612/5965493414
    - Added proper AdMob initialization in main.dart
    - Added AdMob App ID to Android manifest
        🔊 Voice Reminder Testing & Debug (2025-10-12):
    /* Lines 110-145 omitted */
    - Banner ads load with fallback display if ads fail to load

    📱 Device Compatibility Improvements (2025-10-28):
    - Made camera feature optional (android:required="false") for broader device compatibility
    - Made autofocus feature optional for devices without advanced camera hardware
    - Made microphone feature optional for devices without microphone
    - Enables installation on e-readers like ONyX Poke5 and other specialized Android devices
    - Camera and voice features will gracefully disable on devices lacking hardware
    - App now installable on 99%+ of Android devices running Android 7.0+

    🔐 Authentication Fix for E-Readers (2025-10-28):
    - Fixed automatic anonymous login issue on Boox and other e-reader devices
    - Added proper login dialog with 3 clear options: Google Account, Anonymous, or Offline
    - Removed automatic fallback to anonymous authentication
    - Users now have explicit control over authentication method
    - Google sign-in failures no longer silently switch to anonymous mode
    - Offline mode available for devices without Google Play Services

    📱 Google Sign-in Mobile Fix (2025-10-28):
    - Improved Google sign-in compatibility for mobile devices and e-readers
    - Added multiple sign-in methods (provider + popup) with automatic fallback
    - Better error messages for different failure scenarios
    - Enhanced support for devices with limited Google Play Services
    - Clear guidance when Google sign-in isn't available (suggests Anonymous/Offline mode)
    - Debug logging for troubleshooting authentication issues

    📧 Email Authentication for Huawei/Restricted Devices (2025-10-29):
    - Added Email/Password authentication as Google sign-in alternative
    - Works perfectly on Huawei devices without Google Play Services restrictions
    - Create account or sign in with any email address
    - Full cloud sync functionality without Google account dependency
    - Better compatibility with e-readers and modified Android devices
    - Automatic error handling with user-friendly messages (wrong password, account exists, etc.)
    - Automatic username restoration: Previous email automatically filled in login form
    - NEW (2025-11-23): Credential auto-fill & auto-login of last account (password stored locally with light obfuscation)
    - Recommended solution for users experiencing Google sign-in issues

    👨‍👩‍👧‍👦 Family Sharing Feature (2025-10-30):
    - Share reminder events with family members via email addresses
    - Real-time collaboration: family members can view and update shared reminders
    - Family Sharing screen accessible via people icon (👥) in app bar (when signed in)
    - Individual task sharing: Share specific reminders with selected family members
    - Bulk sharing options: "Share All" and "Unshare All" buttons for convenience
    - Smart sharing status: Visual indicators show which tasks are shared and by whom
    - Last modified tracking: See who made the most recent changes to shared tasks
    - Comprehensive sharing management: Easy-to-use interface for adding/removing family members
    - Works with both Google Sign-in and Email authentication methods
    - Perfect for families, couples, and roommates managing household tasks together
    
    🔐 Firestore Security Rules Setup (Required for Family Sharing):
    For family sharing to work, you need to update Firebase Firestore security rules:
    1. Go to Firebase Console > Firestore Database > Rules
    2. Replace the default rules with the content from `firestore.rules` file
    3. Publish the rules
    
    The rules allow:
    - Users to access their own tasks
    - Shared task access for owner and shared users
    - Proper permission control for family sharing features
    
    ⚠️ Note: If you see "permission-denied" errors, ensure the Firestore rules are properly configured.
    
    🤖 Enhanced AI Configuration (2025-10-31):
    - Multiple AI Provider Support: Choose from Google Gemini, OpenAI, DeepSeek, or Qianwen (Alibaba)
    - Smart Model Selection: Popular models pre-selected as defaults (e.g., gemini-2.5-flash, gpt-4o-mini)
    - Editable Model Names: Users can modify or change model names for custom configurations
    - Provider-Specific Settings: Each provider has tailored model options and API key guidance
    - Backwards Compatibility: Existing Gemini API keys automatically migrate to new system
    - Unified API Key Management: Single interface for managing different provider credentials
    - Intelligent Validation: System checks provider compatibility before image analysis
    - Default Provider: Google Gemini (gemini-2.5-flash) for optimal image analysis performance
    - Easy Provider Switching: Change AI providers on-the-fly without losing configurations
    - Collapsible UI: AI configuration is hidden by default, expandable with one click for cleaner settings
    
    Available Providers & Popular Models:
    • Google Gemini: gemini-2.5-flash (default), gemini-1.5-flash, gemini-1.5-pro, gemini-2.0-flash-exp, gemini-1.0-pro
    • OpenAI: gpt-4o-mini (default), gpt-4o, gpt-4-turbo, gpt-3.5-turbo
    • DeepSeek: deepseek-chat (default), deepseek-coder, deepseek-reasoner
    • Qianwen: qwen-turbo (default), qwen-plus, qwen-max, qwen-coder-turbo
    
    📋 Manual-Only Family Sharing (2025-10-31):
    - Removed automatic family sync to give users full control
    - All family sharing operations are now manual-only
    - Use "Manual Sync Family Tasks" from the menu to update shared tasks
    - No background auto-sync activity - sync only when you want to
    - Better battery life and network usage with on-demand synchronization

    🔁 Repeat Tasks (Daily / Weekly / Monthly / One Time) (2025-11-23):
    - Tasks can now repeat Daily, Weekly (with selectable weekdays), Monthly, or be One Time
    - Weekly tasks: choose any combination of weekdays (Mon–Sun) via chips in the task form
    - Monthly tasks: repeat on the same day-of-month after the start date
    - Daily tasks: shown on every day from their start date onward
    - End date option: limit how long a recurring task keeps appearing
    - Virtual occurrences are generated automatically (no need to create copies)
    - Recurring tasks display an icon (day/week/month) for quick visual identification
    - Editing a recurring task immediately updates all future virtual occurrences

    🔐 Auto Login & Credential Recall (2025-11-23):
    - Stores last successful email + password locally with light obfuscation
    - Automatically signs in on app launch (unless standalone mode is enabled)
    - Email field auto-fills previous credentials; typing a matching email restores its password
    - Fast frictionless re-entry for frequent users on personal devices
    - Implementation uses reversible obfuscation (NOT strong encryption) – replace with secure storage for production hardening
    - Disable auto-login by switching to Standalone Mode in Settings
    
    🔁 Repeat / Recurrence Support (2025-11-23):
    - Repeat attribute added: None (one-time), Daily, Weekly, Monthly
    - Weekly tasks support multiple day selection (e.g., Mon/Wed/Fri)
    - Optional end date limits repetition window
    - Virtual occurrences automatically displayed on matching dates (no duplicate storage)
    - Daily repeats schedule repeating notifications; others appear per-occurrence
    - AI image extraction pre-fills recurrence when detected (e.g., "every Monday")
    - Future roadmap: yearly recurrence & custom interval rules

    🔐 Credential Storage Note:
    - Email/password stored locally with reversible obfuscation for convenience (NOT strong encryption)
    - For higher security deployments integrate platform secure storage (Android Keystore / iOS Keychain)