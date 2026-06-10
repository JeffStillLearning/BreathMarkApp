// lib/services/haptic_service.dart
// HapticService menjalankan pola getaran untuk panduan pernapasan 4-7-8

import 'dart:async';
import 'package:flutter/services.dart'; // HapticFeedback ada di sini

class HapticService {
  bool _isRunning = false;

  // Jalankan satu siklus pernapasan 4-7-8
  // onPhaseChange: callback untuk memberi tahu UI sedang di fase apa
  // onComplete: callback ketika siklus selesai
  Future<void> runCycle({
    required Function(String phase) onPhaseChange,
    required Function() onComplete,
  }) async {
    _isRunning = true;

    // --- FASE 1: TARIK NAPAS (4 detik) ---
    // Getaran panjang terus-menerus = tanda untuk menarik napas
    onPhaseChange('inhale'); // beritahu UI bahwa kita di fase tarik napas
    for (int i = 0; i < 4 && _isRunning; i++) {
      HapticFeedback.heavyImpact(); // getaran sekali
      await Future.delayed(const Duration(seconds: 1)); // tunggu 1 detik
    }

    // --- FASE 2: TAHAN NAPAS (7 detik) ---
    // Tidak ada getaran = tanda untuk menahan napas
    onPhaseChange('hold');
    await Future.delayed(const Duration(seconds: 7));

    // --- FASE 3: BUANG NAPAS (8 detik) ---
    // Getaran berpola setiap 500ms = tanda untuk membuang napas perlahan
    onPhaseChange('exhale');
    for (int i = 0; i < 8 && _isRunning; i++) {
      HapticFeedback.lightImpact(); // getaran ringan
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_isRunning) onComplete(); // beritahu bahwa siklus selesai
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
        onComplete: () {}, // tidak perlu aksi khusus per siklus
      );
    }

    if (_isRunning) onSessionComplete();
  }

  // Hentikan sesi lebih awal (kalau user tekan tombol batal)
  void stop() {
    _isRunning = false;
  }
}
