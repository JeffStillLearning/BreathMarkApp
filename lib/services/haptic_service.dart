// lib/services/haptic_service.dart
// HapticService menjalankan pola getaran untuk panduan pernapasan 4-7-8.
//
// PENTING: durasi tiap fase dijaga TEPAT (4 / 7 / 8 detik) memakai satu
// `await Future.delayed` per fase. Pulsa getaran dijadwalkan lewat Timer
// terpisah supaya latensi channel haptic TIDAK menambah panjang fase
// (mencegah durasi melenceng & menumpuk antar siklus).

import 'dart:async';
import 'package:flutter/services.dart';

class HapticService {
  bool _isRunning = false;
  Timer? _pulseTimer;

  // Jadwalkan [count] pulsa getaran, satu per detik, tanpa memblokir.
  void _startPulses({required int count, required bool heavy}) {
    _pulseTimer?.cancel();
    void pulse() {
      if (!_isRunning) return;
      heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    }

    int i = 1;
    pulse(); // pulsa pertama langsung di awal fase
    _pulseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRunning || i >= count) {
        t.cancel();
        return;
      }
      pulse();
      i++;
    });
  }

  Future<void> _wait(int seconds) =>
      Future.delayed(Duration(seconds: seconds));

  // Jalankan satu siklus pernapasan 4-7-8 dengan durasi fase presisi.
  Future<void> runCycle({
    required Function(String phase) onPhaseChange,
    required Function() onComplete,
  }) async {
    _isRunning = true;

    // FASE 1 — TARIK NAPAS (tepat 4 detik), getaran kuat tiap detik
    onPhaseChange('inhale');
    _startPulses(count: 4, heavy: true);
    await _wait(4);
    if (!_isRunning) return;

    // FASE 2 — TAHAN NAPAS (tepat 7 detik), tanpa getaran
    _pulseTimer?.cancel();
    onPhaseChange('hold');
    await _wait(7);
    if (!_isRunning) return;

    // FASE 3 — BUANG NAPAS (tepat 8 detik), getaran ringan tiap detik
    onPhaseChange('exhale');
    _startPulses(count: 8, heavy: false);
    await _wait(8);
    _pulseTimer?.cancel();

    if (_isRunning) onComplete();
  }

  // Jalankan 3 siklus penuh
  Future<void> runFullSession({
    required Function(int cycle, String phase) onUpdate,
    required Function() onSessionComplete,
  }) async {
    _isRunning = true;

    for (int siklus = 1; siklus <= 3 && _isRunning; siklus++) {
      await runCycle(
        onPhaseChange: (phase) => onUpdate(siklus, phase),
        onComplete: () {},
      );
    }

    if (_isRunning) onSessionComplete();
  }

  // Hentikan sesi lebih awal (kalau user tekan tombol batal)
  void stop() {
    _isRunning = false;
    _pulseTimer?.cancel();
  }
}
