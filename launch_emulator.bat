@echo off
set "ANDROID_HOME=C:\Users\EL\AppData\Local\Android\Sdk"
set "ANDROID_SDK_ROOT=C:\Users\EL\AppData\Local\Android\Sdk"
set "ANDROID_AVD_HOME=E:\.android\avd"
cd /d "C:\Users\EL\AppData\Local\Android\Sdk\emulator"
start emulator.exe -avd Pixel_10_Pro_XL
