// lib/models/mood_result.dart
// Model khusus untuk menyimpan hasil analisis foto wajah

class MoodResult {
  final double score;        // angka 0-100
  final String label;        // "rileks" / "netral" / "tegang" / "kelelahan"
  final double brightness;   // nilai kecerahan wajah (zona dahi)
  final double eyeOpenness;  // nilai keterbukaan mata (zona mata)
  final double mouthCurve;   // nilai ekspresi mulut (zona mulut)

  MoodResult({
    required this.score,
    required this.label,
    required this.brightness,
    required this.eyeOpenness,
    required this.mouthCurve,
  });
}
