#!/usr/bin/env python3
"""Adjusts the Android project that `flutter create` generates.

Run from the repository root after the android/ folder exists. It:
  * turns on core library desugaring (needed by flutter_local_notifications)
  * adds microphone, notification and alarm permissions
  * registers the receivers that deliver scheduled reminders, also after a reboot
  * lets the app find the phone's speech recognition service
  * sets the app name and copies the launcher icons
"""
import pathlib
import re
import shutil
import sys

APP_NAME = "Dincharya"
app = pathlib.Path("android/app")
if not app.exists():
    sys.exit("android/app not found - run flutter create first")

# ---- Gradle ----
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"
if kts.exists():
    s = kts.read_text()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", s, count=1)
        if n == 0:
            sys.exit("compileOptions block not found in build.gradle.kts")
    if "multiDexEnabled" not in s:
        s = re.sub(r"defaultConfig\s*\{", "defaultConfig {\n        multiDexEnabled = true", s, count=1)
    if "desugar_jdk_libs" not in s:
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(s)
    print("patched", kts)
elif groovy.exists():
    s = groovy.read_text()
    if "coreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", s, count=1)
        if n == 0:
            sys.exit("compileOptions block not found in build.gradle")
    if "multiDexEnabled" not in s:
        s = re.sub(r"defaultConfig\s*\{", "defaultConfig {\n        multiDexEnabled true", s, count=1)
    if "desugar_jdk_libs" not in s:
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(s)
    print("patched", groovy)
else:
    sys.exit("no app build.gradle found")

# ---- Manifest ----
manifest = app / "src/main/AndroidManifest.xml"
m = manifest.read_text()

PERMS = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
"""
RECEIVERS = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
SPEECH_QUERY = """
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
"""

if "RECORD_AUDIO" not in m:
    if "<application" not in m:
        sys.exit("<application> not found in manifest")
    m = m.replace("<application", PERMS + "    <application", 1)
if "ScheduledNotificationReceiver" not in m:
    m = m.replace("</application>", RECEIVERS + "    </application>", 1)
if "android.speech.RecognitionService" not in m:
    if "<queries>" in m:
        m = m.replace("<queries>", "<queries>" + SPEECH_QUERY, 1)
    else:
        m = m.replace("</manifest>", "    <queries>" + SPEECH_QUERY + "    </queries>\n</manifest>", 1)
m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m, count=1)
manifest.write_text(m)
print("patched", manifest)

# ---- Launcher icons ----
icons = pathlib.Path("tool/icons")
res = app / "src/main/res"
if icons.exists():
    for d in icons.iterdir():
        target = res / d.name
        if d.is_dir() and target.exists():
            for f in d.iterdir():
                shutil.copy(f, target / f.name)
    print("copied launcher icons")
