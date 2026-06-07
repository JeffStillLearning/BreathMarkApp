// lib/models/session_model.dart
// Model = struktur data, seperti "formulir" yang menentukan
// informasi apa saja yang disimpan untuk setiap sesi

class SessionModel {
  final int? id;            // nomor urut (diisi otomatis oleh database)
  final String date;        // tanggal sesi
  final double moodBefore;  // mood score sebelum sesi
  final String moodLabel;   // label mood (rileks/netral/tegang/kelelahan)
  final String stressLevel; // level stres (low/moderate/high)
  final double? moodAfter;  // mood score sesudah sesi (bisa kosong)
  final double? relaxScore; // relaxation score (bisa kosong)
  final int? durationSec;   // durasi sesi haptic

  SessionModel({
    this.id,
    required this.date,
    required this.moodBefore,
    required this.moodLabel,
    required this.stressLevel,
    this.moodAfter,
    this.relaxScore,
    this.durationSec,
  });

  // Mengubah SessionModel menjadi Map (format yang bisa disimpan ke database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'mood_before': moodBefore,
      'mood_label': moodLabel,
      'stress_level': stressLevel,
      'mood_after': moodAfter,
      'relax_score': relaxScore,
      'duration_sec': durationSec,
    };
  }

  // Mengubah Map dari database kembali menjadi SessionModel
  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'],
      date: map['date'],
      moodBefore: map['mood_before'],
      moodLabel: map['mood_label'],
      stressLevel: map['stress_level'],
      moodAfter: map['mood_after'],
      relaxScore: map['relax_score'],
      durationSec: map['duration_sec'],
    );
  }
}
