# BreathMark — Stres & Fokus Tracker

Aplikasi deteksi stres dan fokus menggunakan sensor smartphone untuk membantu mahasiswa dan pekerja muda memantau kondisi mental mereka. 

**Platform:** Android (Flutter 3.x)  
**Target:** Selesai dalam 5-6 hari (6 sprint)

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.x + Dart 3.11
- Android SDK / iOS (optional)

### Setup

```bash
# 1. Clone & install dependencies
flutter pub get

# 2. Download & setup fonts (see docs/SETUP.md)
# Place fonts into: fonts/

# 3. Run on emulator/device
flutter run
```

---

## 🏗️ Architecture

**Layer Structure:**

```
screens/         → UI Layer (5 screens, StatefulWidget)
  ↓
services/        → Hardware abstraction (camera, accelerometer, haptic)
  ↓
logic/           → Business logic (mood analyzer, tremor calculator, score combiner)
  ↓
models/          → Data structures (SessionModel, MoodResult)
  ↓
database/        → Local storage (SQLite via sqflite)
  ↓
constants.dart   → Design tokens (colors, sizes, fonts)
```

**For details:** See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 📱 Features

- **Mood Check-in** — Analyze facial expression via camera (kecerahan, mata, mulut)
- **Tremor Detector** — Measure stress level from accelerometer vibration (10 detik)
- **Guided Breathing** — Haptic-guided 4-7-8 breathing session (3 cycles)
- **History** — Track trends with graphs (7-day mood, stress distribution)

---

## 📊 Sprint Progress

| Sprint | Task | Status |
|--------|------|--------|
| 0 | Setup (pubspec, folders, routing, fonts) | ✅ Done |
| 1 | Database & Models | ✅ Done |
| 2 | Logic Layer | ✅ Done |
| 3 | Service Layer | ✅ Done |
| 4 | UI Screens | ✅ Done |
| 5 | Integration & Testing | ⏳ Todo |
| 6 | Polish & Presentasi | ⏳ Todo |

---

## 📚 Documentation

- **[docs/SETUP.md](docs/SETUP.md)** — Font download, troubleshooting, emulator setup
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — Layer design, WHY decisions, data flow
- **[PRD_BREATHMARK.md](PRD_BREATHMARK.md)** — Complete product spec & sprint details
- **[UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md)** — UI design tokens, components, screens

---

## 🛠️ Development

### Commands

```bash
# Run with verbose output for debugging
flutter run -v

# Build APK (debug)
flutter build apk --debug

# Clean build (if issues)
flutter clean && flutter pub get && flutter run
```

### Project Structure

```
lib/
├── main.dart                    # App entry point, routing
├── constants.dart               # Design tokens, helpers
├── screens/                     # 5 UI screens
├── services/                    # Hardware: camera, sensors, haptic
├── logic/                       # Calculators: mood, tremor, score
├── models/                      # Data: SessionModel, MoodResult
├── database/                    # DatabaseHelper, SQLite
└── widgets/                     # Reusable components
```

---

## 📝 Notes

- Fonts must be placed in `fonts/` folder (see SETUP.md)
- Android permissions configured in `AndroidManifest.xml`
- Database auto-creates on first run
- Provider package for state management

---

**Need help?** Check [docs/SETUP.md](docs/SETUP.md) for troubleshooting.
