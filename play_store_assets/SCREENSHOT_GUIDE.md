# 📸 SCREENSHOT GUIDE - AI Reminder

## 🎯 REQUIRED SCREENSHOTS (2-8 images, 1080x1920 pixels):

### 📱 Screenshot Plan:

#### 1. **Main Screen** (phone_01.png)
- Show task list with several tasks
- Include different due dates/times
- Show both completed and pending tasks
- Highlight the clean, organized interface

#### 2. **Voice Input** (phone_02.png)  
- Show the "Add Task" screen
- Display microphone icon active
- Show voice input in progress or speech text
- Highlight the AI voice feature

#### 3. **Calendar View** (phone_03.png)
- Display calendar with tasks on different dates
- Show current date highlighted
- Include various task types/priorities
- Show the intuitive date-based organization

#### 4. **Task Details/Settings** (phone_04.png)
- Show individual task with notification settings
- Display voice reminder toggle
- Show scheduling options
- Highlight customization features

#### 5. **Google Sign-In** (phone_05.png) [Optional]
- Show Google Sign-In button/screen
- Display sync status
- Highlight cloud backup feature

## 📐 TECHNICAL REQUIREMENTS:

### Image Specs:
- **Size**: 1080 x 1920 pixels (portrait)
- **Format**: PNG or JPG
- **Quality**: High resolution, crisp text
- **Content**: Real app interface (not mockups)

### Best Practices:
- **Clean Data**: Remove personal/test information
- **Good Lighting**: Bright, clear screenshots
- **Full Screen**: No notification bars or navigation
- **Consistent**: Same device, same theme
- **Progressive**: Show user journey flow

## 🚀 HOW TO TAKE SCREENSHOTS:

### Method 1: Android Emulator
1. Run: `flutter run -d emulator-5554`
2. Navigate to each screen
3. Use emulator's camera button
4. Screenshots saved to desktop

### Method 2: Real Device
1. Install APK: `build\app\outputs\flutter-apk\app-release.apk`
2. Open app and navigate to screens
3. Take screenshots (Power + Volume Down)
4. Transfer to computer

### Method 3: Flutter Screenshot Tool
1. Add to pubspec.yaml:
   ```yaml
   dev_dependencies:
     integration_test: ^any
   ```
2. Create screenshot test
3. Run automated screenshots

## 💡 SCREENSHOT TIPS:

### Content Suggestions:
- **Tasks**: "Buy groceries", "Team meeting at 3 PM", "Call mom"
- **Dates**: Mix of today, tomorrow, next week
- **Times**: Various times (9 AM, 2:30 PM, 6 PM)
- **Status**: Mix completed/pending tasks

### Visual Appeal:
- Use light theme for better visibility
- Ensure text is readable
- Show app in action (not empty states)
- Include realistic, relatable tasks

## 📁 SAVE LOCATIONS:

Save screenshots as:
- `play_store_assets/screenshots/phone_01.png` (Main screen)
- `play_store_assets/screenshots/phone_02.png` (Voice input)
- `play_store_assets/screenshots/phone_03.png` (Calendar)
- `play_store_assets/screenshots/phone_04.png` (Settings/Details)
- `play_store_assets/screenshots/phone_05.png` (Optional extras)

## ✅ AFTER TAKING SCREENSHOTS:

1. **Review**: Check all images are 1080x1920
2. **Quality**: Ensure text is crisp and readable
3. **Content**: Verify no personal data visible
4. **Rename**: Use descriptive filenames
5. **Ready**: Upload to Google Play Console

---
Total Time: ~30-45 minutes
Priority: High - Required for Play Store submission