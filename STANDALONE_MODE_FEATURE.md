# Standalone Mode Feature

## Overview
Added a new "Standalone Mode" setting that allows users to hide the login functionality and work completely offline.

## Changes Made

### 1. Settings Service (`lib/services/settings_service.dart`)
- Created a new service to centrally manage app settings
- Provides easy access to settings throughout the app
- Includes getter and setter methods for all settings including `standaloneMode`

### 2. Settings Screen (`lib/screens/settings.dart`)
- Added `_standaloneMode` boolean state variable
- Added `_setStandaloneMode()` method to update the setting
- Added UI toggle with descriptive text:
  - Title: "Standalone Mode"
  - Description: "Hide login button and work offline only"

### 3. Home Screen (`lib/screens/home.dart`)
- Added `_standaloneMode` state variable
- Added `_updateStandaloneMode()` method to refresh setting
- Modified app bar actions to conditionally show login-related UI:
  - User email display is hidden in standalone mode
  - Login/logout button is hidden in standalone mode
- Settings button now refreshes standalone mode when returning from settings

### 4. Main App (`lib/main.dart`)
- Added `SettingsService.init()` to initialize the settings service during app startup

## User Experience

### Default Behavior (Standalone Mode ON - Default)
- Hides user email display from app bar
- Hides login/logout button from app bar
- App works completely offline
- All other functionality remains intact

### Standalone Mode OFF (Optional)
- Shows "Not signed in" or user email in app bar
- Shows login/logout button in app bar
- Users can sign in for cloud sync functionality

## How to Use

1. **Default Experience (Standalone Mode ON):**
   - App starts in standalone mode by default
   - Login button is hidden from home screen
   - Clean, offline-focused interface

2. **Enable Online Features:**
   - Go to Settings  
   - Toggle "Standalone Mode" to OFF
   - Return to home screen - login button is now visible
   - Can sign in for cloud sync functionality

## Technical Details

- Setting is stored in Hive box: `'standaloneMode'`
- Default value: `true` (standalone mode enabled by default)
- Setting persists between app restarts
- No impact on existing functionality - purely UI visibility change
- All task management features work identically in both modes

## Benefits

1. **Simplified UI**: Users who prefer offline-only usage get a cleaner interface
2. **Privacy**: Users concerned about cloud sync can work completely locally
3. **Flexibility**: Easy to toggle between modes as needed
4. **No Data Loss**: All existing functionality preserved regardless of mode

## Files Modified

- `lib/services/settings_service.dart` (new file)
- `lib/screens/settings.dart`
- `lib/screens/home.dart`
- `lib/main.dart`

## Testing

- ✅ Settings toggle works correctly
- ✅ Home screen updates immediately when returning from settings
- ✅ Login button hidden/shown based on setting
- ✅ User email display hidden/shown based on setting
- ✅ Setting persists between app restarts
- ✅ No breaking changes to existing functionality