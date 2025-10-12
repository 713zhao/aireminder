# Google Play Store Assets Guide
# AI Reminder App - Asset Organization

## 📁 FOLDER STRUCTURE CREATED:

```
play_store_assets/
├── icons/
├── graphics/
└── screenshots/
```

## 🎨 WHERE TO PUT YOUR ASSETS:

### 📱 APP ICON
**Your app icon goes here:**
- `play_store_assets/icons/app_icon_1024x1024.png`

**Requirements:**
- Size: 1024 x 1024 pixels
- Format: PNG (32-bit)
- No transparency
- High quality, sharp details
- Represents your AI Reminder brand

### 🖼️ FEATURE GRAPHIC
**Your feature graphic goes here:**
- `play_store_assets/graphics/feature_graphic_1024x500.png`

**Requirements:**
- Size: 1024 x 500 pixels
- Format: PNG or JPG
- High quality
- Showcases your app's key features
- Used in Play Store promotions

## 📸 ADDITIONAL ASSETS NEEDED:

### SCREENSHOTS (Required)
**Put phone screenshots here:**
- `play_store_assets/screenshots/phone_01.png`
- `play_store_assets/screenshots/phone_02.png`
- `play_store_assets/screenshots/phone_03.png`
- `play_store_assets/screenshots/phone_04.png`

**Requirements:**
- Minimum: 2 screenshots
- Maximum: 8 screenshots
- Size: 1080 x 1920 pixels (16:9 aspect ratio)
- Format: PNG or JPG
- Show key app features

**Suggested Screenshots:**
1. Main task list view
2. Voice input / Add task screen
3. Calendar view
4. Settings/profile screen
5. Notification example
6. Google Sign-In flow

### TABLET SCREENSHOTS (Optional but recommended)
**Put tablet screenshots here:**
- `play_store_assets/screenshots/tablet_01.png`
- `play_store_assets/screenshots/tablet_02.png`

**Requirements:**
- Size: 2048 x 1536 pixels
- Same content as phone but optimized for tablet layout

## 🔧 UPDATING APP ICON IN YOUR APP:

### Current App Icon Location:
Your app currently uses the default Flutter icon. To update:

1. **Replace Android icon:**
   - `android/app/src/main/res/mipmap-*/ic_launcher.png`
   
2. **Use Flutter launcher_icons package (Recommended):**
   ```yaml
   # Add to pubspec.yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   
   flutter_icons:
     android: true
     image_path: "play_store_assets/icons/app_icon_1024x1024.png"
   ```
   
   Then run: `flutter pub run flutter_launcher_icons:main`

## 📋 GOOGLE PLAY CONSOLE UPLOAD LOCATIONS:

### Store Listing → Main Store Listing:
- **App icon**: Upload from `play_store_assets/icons/`
- **Feature graphic**: Upload from `play_store_assets/graphics/`
- **Phone screenshots**: Upload from `play_store_assets/screenshots/`

### Store Listing → Graphics:
- **Feature graphic**: 1024 x 500 px
- **Phone screenshots**: 1080 x 1920 px (minimum 2, maximum 8)
- **7-inch tablet screenshots**: 2048 x 1536 px (optional)

## ✅ CHECKLIST:

### Required Assets:
- [ ] App Icon (1024x1024 PNG) → `play_store_assets/icons/`
- [ ] Feature Graphic (1024x500 PNG/JPG) → `play_store_assets/graphics/`
- [ ] Phone Screenshots (2-8 images) → `play_store_assets/screenshots/`

### Optional Assets:
- [ ] Tablet Screenshots → `play_store_assets/screenshots/`
- [ ] TV Banner (1280x720) → `play_store_assets/graphics/`
- [ ] Wear OS Screenshots → `play_store_assets/screenshots/`

## 🎯 BEST PRACTICES:

### App Icon:
- Use your AI/brain theme
- Include "AI" or smart elements
- Clear, recognizable at small sizes
- Consistent with your brand

### Feature Graphic:
- Show app interface mockups
- Highlight AI and voice features  
- Include your app name/logo
- Use your brand colors
- No excessive text (mobile-friendly)

### Screenshots:
- Show real app content, not mockups
- Include captions explaining features
- Progressive flow (onboarding → main features)
- High-quality, crisp images
- Remove personal/test data

## 🚀 NEXT STEPS:

1. **Copy your assets** to the folders above
2. **Take screenshots** of your app running
3. **Update app icon** in your Flutter project
4. **Test on device** to ensure icon looks good
5. **Upload to Google Play Console** when ready

---
Asset folders created: October 12, 2025
Ready for Google Play Store submission!