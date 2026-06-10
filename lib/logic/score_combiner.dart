// lib/logic/score_combiner.dart
// ScoreCombiner menggabungkan Mood Score dan Stress Level
// menjadi satu kondisi keseluruhan dengan rekomendasi

class CombinedResult {
  final double wellnessScore; // skor gabungan 0-100
  final String kondisi;       // deskripsi kondisi
  final String rekomendasi;   // saran untuk pengguna
  final bool perluSesi;       // apakah disarankan sesi pernapasan?

  CombinedResult({
    required this.wellnessScore,
    required this.kondisi,
    required this.rekomendasi,
    required this.perluSesi,
  });
}

class ScoreCombiner {
  CombinedResult combine(double moodScore, String stressLevel) {
    // Konversi stress level ke angka
    // LOW = 20 (rendah), MODERATE = 60 (sedang), HIGH = 100 (tinggi)
    double stressNumeric;
    switch (stressLevel) {
      case 'low':
        stressNumeric = 20;
        break;
      case 'moderate':
        stressNumeric = 60;
        break;
      case 'high':
        stressNumeric = 100;
        break;
      default:
        stressNumeric = 50;
    }

    // Gabungkan: mood 50% + kebalikan stres 50%
    // "kebalikan stres" artinya: stres tinggi → nilai wellness rendah
    final wellness = (moodScore * 0.5) + ((100 - stressNumeric) * 0.5);

    // Tentukan kondisi dan rekomendasi berdasarkan wellness score
    String kondisi;
    String rekomendasi;
    bool perluSesi;

    if (wellness >= 65) {
      kondisi = 'Kondisi Baik';
      rekomendasi =
          'Kondisi kamu sedang baik. Tetap jaga pola istirahat dan aktivitas.';
      perluSesi = false;
    } else if (wellness >= 40) {
      kondisi = 'Ada Tanda Stres Ringan';
      rekomendasi =
          'Terdeteksi tanda stres ringan. Sesi pernapasan dapat membantu.';
      perluSesi = true;
    } else {
      kondisi = 'Stres Tinggi Terdeteksi';
      rekomendasi =
          'Stres cukup tinggi terdeteksi. Sangat disarankan untuk melakukan sesi relaksasi sekarang.';
      perluSesi = true;
    }

    return CombinedResult(
      wellnessScore: wellness,
      kondisi: kondisi,
      rekomendasi: rekomendasi,
      perluSesi: perluSesi,
    );
  }

  // Hitung Relaxation Score: seberapa besar mood membaik setelah sesi
  double calcRelaxScore(double moodBefore, double moodAfter) {
    if (moodBefore >= 100) return 0; // hindari pembagian dengan nol
    return ((moodAfter - moodBefore) / (100 - moodBefore) * 100)
        .clamp(0.0, 100.0);
  }

  // Label untuk Relaxation Score
  String getRelaxLabel(double relaxScore) {
    if (relaxScore >= 60) return 'Sangat Baik';
    if (relaxScore >= 35) return 'Baik';
    if (relaxScore >= 15) return 'Cukup';
    return 'Kurang Efektif';
  }
}
