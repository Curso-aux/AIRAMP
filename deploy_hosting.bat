@echo off
echo ============================================================
echo  AIRA Platform - Building Web and Mobile Release for Firebase
echo ============================================================

cd /d "%~dp0airamp_flutter"

echo [1/4] Building Flutter Web Release...
call flutter build web --release

echo [2/4] Ensuring Downloads Directory Exists...
if not exist "build\web\downloads" mkdir "build\web\downloads"
if exist "web\downloads\version.json" copy /y "web\downloads\version.json" "build\web\downloads\version.json"
if exist "build\web\downloads\*.apk" del /q /f "build\web\downloads\*.apk"

echo [3/4] Building Android Release APK...
call flutter build apk --release

echo [4/4] Hosting Android Release APK in Web Downloads...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "build\web\downloads\aira-latest.apk"
    echo Hosted Android APK copied to build\web\downloads\aira-latest.apk
)

cd /d "%~dp0"
echo ============================================================
echo  Deploying to Firebase Hosting and Cloud Firestore Rules...
echo ============================================================
call npx firebase deploy --only hosting,firestore:rules
