# Architecture — BreathMark

Penjelasan struktur layer, data flow, dan design decisions.

---

## 🏗️ Layer Structure

```
┌─────────────────────────────────┐
│      Screens (UI Layer)         │
│  home_screen.dart               │
│  checkin_screen.dart            │
│  tremor_screen.dart             │
│  breathing_screen.dart          │
│  history_screen.dart            │
└──────────────┬──────────────────┘
               │ setState() / Provider
               ↓
┌──────────────────────────────────────┐
│  Services (Hardware Abstraction)     │
│  camera_service.dart                 │
│  accelerometer_service.dart          │
│  haptic_service.dart                 │
│  (Raw sensor data)                   │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────┐
│  Logic Layer (Calculations)      │
│  mood_analyzer.dart              │
│  tremor_calculator.dart          │
│  score_combiner.dart             │
│  (Processed data → scores)       │
└──────────────┬──────────────────┘
               │
               ↓
┌──────────────────────────────────┐
│  Models (Data Structures)        │
│  SessionModel                    │
│  MoodResult                      │
│  TremorResult                    │
│  CombinedResult                  │
└──────────────┬──────────────────┘
               │
               ↓
┌──────────────────────────────────┐
│  Database (Persistence)          │
│  database_helper.dart            │
│  SQLite (sqflite)                │
└──────────────────────────────────┘
```

---

## 📊 Data Flow — Check-in Session

```
1. USER OPENS CHECKIN SCREEN
   ↓
2. CameraService.init() 
   → Kamera siap, preview tampil
   ↓
3. USER TAKES PHOTO
   → File.readAsBytes()
   ↓
4. MoodAnalyzer.analyze(file)
   → Pixel processing (3 zones)
   → Return MoodResult {score, label, brightness, eyeOpenness, mouthCurve}
   ↓
5. STORE MoodResult in memory (temporary)
   ↓
6. NAVIGATE TO TREMOR SCREEN
   → Pass MoodResult as argument
```

---

## 🎯 Why This Architecture?

### **Services Layer (Hardware)**
- ✅ Isolated dari UI → bisa reuse di tests
- ✅ Single responsibility (camera = camera only)
- ✅ Easy to mock untuk testing

### **Logic Layer (Pure functions)**
- ✅ Stateless calculations → deterministic
- ✅ Testable without UI
- ✅ Reusable di different contexts

### **Models**
- ✅ Type-safe data structures
- ✅ toMap() / fromMap() untuk database
- ✅ Clear contracts between layers

### **Database (SQLite)**
- ✅ No network needed → offline-first
- ✅ Fast local queries
- ✅ Simple schema (sessions table only)

### **Screens (Stateful)**
- ✅ Observe changes from services/logic
- ✅ Provider untuk state management (optional, bisa pakai setState dulu)
- ✅ Reusable widgets di widgets/ folder

---

## 🔄 State Management (Simple Version)

For this project, kita pakai **setState()** first:

```dart
class CheckinScreen extends StatefulWidget {
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _cameraService = CameraService();
  MoodResult? _result;
  
  Future<void> _capture() async {
    setState(() => _isAnalyzing = true);
    
    final photo = await _cameraService.takePicture();
    final result = await MoodAnalyzer().analyze(photo);
    
    setState(() {
      _result = result;
      _isAnalyzing = false;
    });
  }
}
```

**Advantage:** Simple, no Provider overhead for small app
**Next level:** Kalau state kompleks, upgrade ke Provider/Riverpod

---

## 📦 Dependencies Rationale

| Package | Why | Alternative |
|---------|-----|-------------|
| camera | First-party support untuk photo | image_picker (lebih mudah tapi limited) |
| sensors_plus | Access accelerometer | sensors (deprecated) |
| haptic_feedback | Flutter built-in haptic | vibration (third-party) |
| sqflite | Local database (no backend) | drift, hive, moor |
| fl_chart | Beautiful charts library | charts_flutter, syncfusion |
| provider | State management | Riverpod, GetX, Bloc |
| image | Pixel processing | opencv_dart (heavy) |

---

## 🚀 Future Improvements (Out of Scope)

- [ ] Cloud sync (Firebase Firestore)
- [ ] Push notifications
- [ ] Dark mode
- [ ] Multi-language
- [ ] Machine learning (TensorFlow) untuk mood
- [ ] Backend API (Node.js / Django)

---

## 📝 File Naming Convention

- `*_screen.dart` — UI screens
- `*_service.dart` — Hardware/external services
- `*_analyzer.dart` / `*_calculator.dart` — Logic
- `*_model.dart` — Data structures
- `*_helper.dart` — Utility/database helpers
- `bm_*.dart` — Reusable widgets (bm = BreathMark)

---

## ✅ Testing Strategy (Sprint 5)

```dart
// Test logic independent dari UI
void main() {
  test('MoodAnalyzer: rileks score >= 70', () {
    final analyzer = MoodAnalyzer();
    final result = analyzer.analyze(testImageFile);
    expect(result.label, 'rileks');
  });
}
```

---

## 🔐 Security & Privacy

- ✅ Photos NOT stored (processed in memory only)
- ✅ Database stored locally (not synced)
- ✅ No internet requests
- ✅ No user tracking

---
