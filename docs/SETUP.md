# Setup Guide — BreathMark

Panduan lengkap setup local development, download fonts, dan troubleshooting.

---

## 1️⃣ Download & Install Fonts

### Plus Jakarta Sans

1. Buka https://fonts.google.com/specimen/Plus+Jakarta+Sans
2. Klik tombol **"Download all"** (download 12 file)
3. Extract ZIP → pindahkan file berikut ke folder `fonts/` di root project:
   - `PlusJakartaSans-Regular.ttf`
   - `PlusJakartaSans-Medium.ttf`
   - `PlusJakartaSans-SemiBold.ttf`
   - `PlusJakartaSans-Bold.ttf`

### DM Mono

1. Buka https://fonts.google.com/specimen/DM+Mono
2. Klik **"Download all"** (download 4 file)
3. Extract ZIP → pindahkan ke `fonts/`:
   - `DMMono-Regular.ttf`
   - `DMMono-Medium.ttf`

**Hasil akhir struktur `fonts/` folder:**
```
fonts/
├── DMMono-Medium.ttf
├── DMMono-Regular.ttf
├── PlusJakartaSans-Bold.ttf
├── PlusJakartaSans-Medium.ttf
├── PlusJakartaSans-Regular.ttf
└── PlusJakartaSans-SemiBold.ttf
```

---

## 2️⃣ Install Dependencies

```bash
flutter pub get
```

Ini akan install semua packages dari pubspec.yaml termasuk camera, sensors, sqlite, dll.

---

## 3️⃣ Setup Android Emulator

```bash
# List available emulators
flutter emulators

# Launch specific emulator
flutter emulators --launch <emulator_name>

# Or: Launch default emulator via Android Studio
```

---

## 4️⃣ Run Project

```bash
# Run dengan output verbose (debug)
flutter run -v

# Run di device tertentu
flutter run -d <device_id>

# List available devices
flutter devices
```

---

## 🆘 Troubleshooting

### Issue: "Flutter SDK not found"
**Solution:**
```bash
# Update PATH atau install Flutter SDK
# https://docs.flutter.dev/get-started/install
flutter doctor
```

### Issue: Fonts not showing (text displays as empty/symbol)
**Solution:**
1. Pastikan fonts sudah di folder `fonts/`
2. Run `flutter clean`
3. Run `flutter pub get`
4. Run `flutter run`

### Issue: Camera permission denied / permission error
**Solution:**
- Check `android/app/src/main/AndroidManifest.xml` → pastikan ada:
  ```xml
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  ```
- Jika tetap error, reinstall app di emulator:
  ```bash
  flutter clean
  flutter run
  ```

### Issue: "pubspec.lock" conflict
**Solution:**
```bash
flutter pub get --no-offline
```

### Issue: Accelerometer/Sensor tidak baca data
**Solution:**
- Emulator mungkin tidak support sensor fisik
- Setup sensor di Android Studio: Extended Controls (emulator window) → Sensors
- Atau test di real device

### Issue: Database locked / "database is locked" error
**Solution:**
- App mungkin buka database 2x
- Pastikan DatabaseHelper pakai singleton pattern
- Restart emulator: `flutter run`

---

## 📱 Testing di Real Device

```bash
# Pastikan USB Debug ON di Android phone
# Connect via USB

flutter devices  # verify device terbaca

flutter run -d <device_id>
```

---

## 🔨 Build APK (Untuk Demo/Presentasi)

```bash
# Debug APK (testing)
flutter build apk --debug

# Hasil: build/app/outputs/flutter-apk/app-debug.apk
```

Transfer APK ke phone via USB atau email, install langsung.

---

## 📝 Common Commands

```bash
flutter doctor              # Check setup
flutter pub get             # Install packages
flutter clean               # Clean build cache
flutter run -v              # Run with verbose
flutter build apk --debug   # Build APK
```

---

**Still stuck?** Check logs dengan `flutter run -v` dan paste error message.
