// lib/services/camera_service.dart
// CameraService mengelola semua operasi kamera

import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;
  bool isInitialized = false;

  // Inisialisasi kamera depan
  Future<void> init() async {
    // Dapatkan daftar kamera yang tersedia di HP
    final cameras = await availableCameras();

    // Cari kamera depan (front camera)
    // lensDirection == CameraLensDirection.front artinya kamera yang menghadap user
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first, // kalau tidak ada kamera depan, pakai kamera pertama
    );

    // Buat controller dengan resolusi medium (cukup untuk analisis, tidak terlalu berat)
    controller = CameraController(frontCamera, ResolutionPreset.medium);

    // Inisialisasi controller (ini yang benar-benar "menghidupkan" kamera)
    await controller!.initialize();
    isInitialized = true;
  }

  // Ambil foto dan kembalikan sebagai File
  Future<File?> takePicture() async {
    if (controller == null || !isInitialized) return null;

    try {
      final XFile photo = await controller!.takePicture();
      return File(photo.path); // ubah XFile menjadi File biasa
    } catch (e) {
      print('Error mengambil foto: $e');
      return null;
    }
  }

  // Matikan kamera saat tidak digunakan (PENTING! untuk hemat baterai)
  Future<void> dispose() async {
    await controller?.dispose();
    isInitialized = false;
  }
}
