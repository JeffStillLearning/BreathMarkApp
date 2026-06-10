// lib/services/accelerometer_service.dart
// AccelerometerService merekam data accelerometer selama durasi tertentu

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerService {
  List<List<double>> _readings = []; // menyimpan semua bacaan

  // Rekam data accelerometer selama [durationSeconds] detik
  // Kembalikan semua bacaan sebagai List
  Future<List<List<double>>> record({int durationSeconds = 10}) async {
    _readings = []; // reset data lama

    // Buat completer untuk menunggu sampai perekaman selesai
    final completer = Completer<List<List<double>>>();

    // Subscribe ke stream accelerometer
    // Stream = aliran data yang terus menerus datang
    final subscription = accelerometerEventStream().listen((event) {
      // Simpan nilai x, y, z setiap kali ada data baru
      _readings.add([event.x, event.y, event.z]);
    });

    // Setelah [durationSeconds] detik, hentikan perekaman
    Timer(Duration(seconds: durationSeconds), () {
      subscription.cancel(); // hentikan stream
      completer.complete(_readings); // kembalikan semua data yang terkumpul
    });

    return completer.future;
  }
}
