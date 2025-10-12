@echo off
echo ====================================
echo   AI Reminder Keystore Setup
echo ====================================
echo.
echo IMPORTANT: You need to update key.properties with your actual passwords
echo.
echo 1. Open: android\key.properties
echo 2. Replace REPLACE_WITH_YOUR_KEYSTORE_PASSWORD with your actual keystore password
echo 3. Replace REPLACE_WITH_YOUR_KEY_PASSWORD with your actual key password
echo.
echo The keystore file location: android\aireminder-release-key.jks
echo The key alias is: aireminder
echo.
echo After updating key.properties, you can build the production release:
echo   flutter build appbundle --release
echo.
echo SECURITY REMINDER:
echo - NEVER commit key.properties to version control
echo - NEVER share your keystore file publicly
echo - Keep backups of your keystore in a secure location
echo.
pause