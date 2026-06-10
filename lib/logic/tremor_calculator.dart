// lib/logic/tremor_calculator.dart
// TremorCalculator bertugas mengolah data accelerometer
// dan menentukan level stres berdasarkan getaran tangan

class TremorResult {
  final String level;            // "low" / "moderate" / "high"
  final double variance;         // angka variansi getaran (untuk ditampilkan)
  final List<double> magnitudes; // data mentah untuk grafik

  TremorResult({
    required this.level,
    required this.variance,
    required this.magnitudes,
  });
}

class TremorCalculator {
  // Fungsi utama: terima list data accelerometer, kembalikan TremorResult
  TremorResult calculate(List<List<double>> rawData) {
    // rawData adalah list dari [x, y, z] untuk setiap sampel
    // Contoh: [[0.1, 9.8, 0.2], [0.15, 9.75, 0.18], ...]

    // 1. Hitung magnitude (besar total getaran) untuk setiap sampel
    // Rumus: magnitude = √(x² + y² + z²)
    // Ini mengubah 3 nilai (x,y,z) menjadi 1 nilai tunggal
    List<double> magnitudes = rawData.map((sample) {
      final x = sample[0];
      final y = sample[1];
      final z = sample[2];
      return (x * x + y * y + z * z);
    }).toList();
    // Catatan: tidak pakai sqrt untuk efisiensi, karena kita hanya butuh variansi relatif

    // 2. Terapkan moving average untuk mengurangi noise
    final smoothed = _movingAverage(magnitudes, windowSize: 5);

    // 3. Hitung variansi dari data yang sudah dihaluskan
    // Variansi tinggi = getaran tidak stabil = kemungkinan stres tinggi
    final variance = _calculateVariance(smoothed);

    // 4. Kategorikan berdasarkan threshold
    final level = _getLevel(variance);

    return TremorResult(
      level: level,
      variance: variance,
      magnitudes: magnitudes,
    );
  }

  // Moving average: haluskan data dengan mengambil rata-rata per jendela
  List<double> _movingAverage(List<double> data, {required int windowSize}) {
    List<double> result = [];
    for (int i = 0; i < data.length; i++) {
      final start = (i - windowSize ~/ 2).clamp(0, data.length - 1);
      final end = (i + windowSize ~/ 2).clamp(0, data.length - 1);
      final window = data.sublist(start, end + 1);
      result.add(window.reduce((a, b) => a + b) / window.length);
    }
    return result;
  }

  // Hitung variansi: rata-rata dari kuadrat selisih tiap nilai dengan mean
  double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0;
    final mean = data.reduce((a, b) => a + b) / data.length;
    final squaredDiffs = data.map((x) => (x - mean) * (x - mean));
    return squaredDiffs.reduce((a, b) => a + b) / data.length;
  }

  // Kategorikan level stres berdasarkan nilai variansi
  String _getLevel(double variance) {
    if (variance < 0.5) return 'low';       // tangan stabil
    if (variance < 1.5) return 'moderate';  // ada getaran ringan
    return 'high';                          // getaran tinggi
    // Catatan: threshold ini mungkin perlu disesuaikan saat testing nyata
  }
}
