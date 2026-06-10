// lib/logic/mood_analyzer.dart
// MoodAnalyzer bertugas menganalisis foto wajah dan menghasilkan Mood Score
// Caranya: membagi foto jadi 3 zona, mengukur karakteristik piksel tiap zona

import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/mood_result.dart';

class MoodAnalyzer {
  // Fungsi utama: terima file foto, kembalikan MoodResult
  Future<MoodResult> analyze(File photoFile) async {
    // 1. Baca file foto dan decode menjadi objek gambar yang bisa diproses
    final bytes = await photoFile.readAsBytes();
    final image = img.decodeImage(bytes);

    // Kalau foto gagal dibaca, kembalikan nilai default
    if (image == null) {
      return MoodResult(
        score: 50,
        label: 'netral',
        brightness: 0.5,
        eyeOpenness: 0.5,
        mouthCurve: 0.5,
      );
    }

    final h = image.height; // tinggi foto dalam piksel
    final w = image.width;  // lebar foto dalam piksel

    // 2. Tentukan batas zona berdasarkan proporsi tinggi foto
    // Zona 1 (dahi):  baris piksel 0% sampai 30% dari atas
    // Zona 2 (mata):  baris piksel 30% sampai 55% dari atas
    // Zona 3 (mulut): baris piksel 65% sampai 80% dari atas
    final z1Start = 0;
    final z2Start = (h * 0.30).toInt();
    final z2End = (h * 0.55).toInt();
    final z3Start = (h * 0.65).toInt();
    final z3End = (h * 0.80).toInt();
    final z1End = (h * 0.30).toInt();

    // 3. Hitung metrik untuk setiap zona
    final brightness = _calcBrightness(image, 0, z1Start, w, z1End);
    final eyeOpenness = _calcEyeOpenness(image, 0, z2Start, w, z2End);
    final mouthCurve = _calcMouthCurve(image, 0, z3Start, w, z3End);

    // 4. Gabungkan ketiga metrik dengan pembobotan
    // Mata diberi bobot 40% karena paling sensitif terhadap kelelahan
    final rawScore =
        (brightness * 0.30) + (eyeOpenness * 0.40) + (mouthCurve * 0.30);
    final score = (rawScore * 100).clamp(0.0, 100.0); // pastikan antara 0-100

    // 5. Tentukan label berdasarkan skor
    final label = _getLabel(score);

    return MoodResult(
      score: score,
      label: label,
      brightness: brightness,
      eyeOpenness: eyeOpenness,
      mouthCurve: mouthCurve,
    );
  }

  // Hitung kecerahan rata-rata zona (nilai 0.0 - 1.0)
  // Rumus brightness: (R × 0.299) + (G × 0.587) + (B × 0.114)
  // Ini rumus standar untuk mengubah warna RGB menjadi nilai kecerahan
  double _calcBrightness(img.Image image, int x1, int y1, int x2, int y2) {
    double total = 0;
    int count = 0;

    for (int y = y1; y < y2 && y < image.height; y++) {
      for (int x = x1; x < x2 && x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        total += (r * 0.299 + g * 0.587 + b * 0.114) / 255.0;
        count++;
      }
    }
    return count == 0 ? 0.5 : total / count;
  }

  // Hitung rasio piksel gelap di zona mata
  // Piksel gelap = piksel dengan brightness < 0.3 (angka ini bisa disesuaikan)
  // Semakin banyak piksel gelap = mata terbuka lebar = lebih rileks
  double _calcEyeOpenness(img.Image image, int x1, int y1, int x2, int y2) {
    int darkCount = 0;
    int totalCount = 0;
    const threshold = 0.3; // batas "gelap"

    for (int y = y1; y < y2 && y < image.height; y++) {
      for (int x = x1; x < x2 && x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness =
            (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) / 255.0;
        if (brightness < threshold) darkCount++;
        totalCount++;
      }
    }
    return totalCount == 0 ? 0.5 : darkCount / totalCount;
  }

  // Hitung ekspresi mulut berdasarkan perbedaan kecerahan
  // Sudut mulut vs tengah mulut — kalau sudut lebih terang = senyum
  double _calcMouthCurve(img.Image image, int x1, int y1, int x2, int y2) {
    final w = x2 - x1;
    // Bagi zona mulut menjadi 3 bagian: kiri (sudut), tengah, kanan (sudut)
    final leftBright = _calcBrightness(image, x1, y1, x1 + w ~/ 4, y2);
    final centerBright =
        _calcBrightness(image, x1 + w ~/ 4, y1, x2 - w ~/ 4, y2);
    final rightBright = _calcBrightness(image, x2 - w ~/ 4, y1, x2, y2);

    final cornerAvg = (leftBright + rightBright) / 2;
    // Hasil positif = sudut lebih terang dari tengah = senyum/rileks
    // Normalisasi ke 0.0 - 1.0
    return ((cornerAvg - centerBright) + 1.0) / 2.0;
  }

  // Tentukan label dari angka skor
  String _getLabel(double score) {
    if (score >= 70) return 'rileks';
    if (score >= 50) return 'netral';
    if (score >= 30) return 'tegang';
    return 'kelelahan';
  }
}
