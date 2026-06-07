import 'package:flutter/material.dart';

// ── Warna Utama ─────────────────────────────────────────────────────
const kGreenDark = Color(0xFF1B5E20);    // judul, angka besar, aksen kuat
const kGreenMed = Color(0xFF2E7D32);    // tombol utama, garis aktif
const kGreenLight = Color(0xFF66BB6A);  // highlight, progress, chip dot
const kGreenPale = Color(0xFFE8F5E9);   // background kartu hijau muda

// ── Background & Teks ───────────────────────────────────────────────
const kBgMain = Color(0xFFF5F2EC);      // latar halaman (krem hangat)
const kBgCard = Color(0xFFFFFFFF);      // latar kartu putih
const kInkDark = Color(0xFF1A1814);     // teks utama
const kInkMed = Color(0xFF4A4740);      // teks sekunder
const kInkLight = Color(0xFF8A8780);    // teks tersier / placeholder

// ── Stres & Relaksasi ───────────────────────────────────────────────
const kStressLow = Color(0xFF43A047);   // LOW  → hijau
const kStressMed = Color(0xFFFB8C00);   // MODERATE → oranye
const kStressHigh = Color(0xFFE53935);  // HIGH → merah
const kRelax = Color(0xFF00897B);       // relax score → teal

// ── Border & Hairline ───────────────────────────────────────────────
const kHairline = Color(0x0F1A1814);    // border tipis (6% opacity hitam)

// ── Ukuran & Radius ─────────────────────────────────────────────────
const kPadH = 24.0;        // padding horizontal halaman
const kPadV = 20.0;        // padding vertikal
const kRadius = 18.0;      // border radius kartu standar
const kRadiusLg = 22.0;    // border radius kartu besar

// ── Helper: warna Stress Level ──────────────────────────────────────
Color stressColor(String level) {
  switch (level.toLowerCase()) {
    case 'low':
      return kStressLow;
    case 'moderate':
      return kStressMed;
    case 'high':
      return kStressHigh;
    default:
      return kInkLight;
  }
}

// ── Helper: emoji Mood Label ────────────────────────────────────────
String moodEmoji(String label) {
  switch (label.toLowerCase()) {
    case 'rileks':
      return '😊';
    case 'netral':
      return '😐';
    case 'tegang':
      return '😟';
    case 'kelelahan':
      return '😔';
    default:
      return '😐';
  }
}
