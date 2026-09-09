# Kioku Releases

This directory contains standalone release builds for Kioku.

## Current Release: v1.0.0

| File | Platform | Architecture | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **[`kioku-release.apk`](kioku-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 54.6 MB | `F39A39B1781660CD0DE6F111A10BD2ED2BA66FAB396E377BEC0042FF4B37FE03` |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-release.apk` directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-release.apk
```

---

## 📋 Release Highlights
- Complete Japanese stationery aesthetic (Coffee Light & Forest Dark palettes, Washi tape accents, Hanko stamp postmarks, clay cards).
- Full offline / local device storage support without requiring Google login.
- Optional private Google Drive folder synchronization.
- Day-grouped photo and video timeline feed.
- Time-travel Flashbacks engine ("1 Year Ago Today", "Last Month's Album", "A Passing Memory").
- High-resolution pinch-to-zoom photo viewer and embedded video player with custom controls.
