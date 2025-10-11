# Todo Reminder App (scaffold)

This folder contains a minimal Flutter scaffold created for the `todo-reminder-app` spec.

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
    flutter build apk --debug
    Profile APK (performance profiling):
    flutter build apk --profile
    Release APK (optimized for publishing):
    flutter build apk --release
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