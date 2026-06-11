// lib/screens/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../services/camera_service.dart';
import '../logic/mood_analyzer.dart';
import '../models/mood_result.dart';

enum CheckinState { preview, analyzing, result }

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _cameraService = CameraService();
  final _analyzer = MoodAnalyzer();

  CheckinState _state = CheckinState.preview;
  MoodResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose(); // PENTING: matikan kamera saat screen ditutup
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.init();
    } catch (e) {
      if (mounted) setState(() => _error = 'Kamera tidak dapat diakses. Periksa izin kamera.');
      return;
    }
    if (mounted) setState(() {}); // refresh UI setelah kamera siap
  }

  // Ambil foto → analisis → tampilkan hasil
  Future<void> _capture() async {
    setState(() => _state = CheckinState.analyzing);

    final photo = await _cameraService.takePicture();
    if (photo == null) {
      setState(() => _state = CheckinState.preview);
      return;
    }

    final result = await _analyzer.analyze(photo);
    if (!mounted) return;
    setState(() {
      _result = result;
      _state = CheckinState.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildError();
    switch (_state) {
      case CheckinState.preview:
        return _buildPreview();
      case CheckinState.analyzing:
        return _buildAnalyzing();
      case CheckinState.result:
        return _buildResult();
    }
  }

  // ── Error state ───────────────────────────────────────────────────
  Widget _buildError() {
    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: kInkLight, size: 56),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: kInkMed)),
              const SizedBox(height: 24),
              BmOutlineButton(
                label: 'Kembali',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State 1: Tampilan kamera ──────────────────────────────────────
  Widget _buildPreview() {
    if (_cameraService.controller == null || !_cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: kGreenLight)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraService.controller!),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassButton(
                  child:
                      const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                  onTap: () => Navigator.pop(context),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: kGreenLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Sensor siap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 220,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(110),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Text(
                  'Posisikan wajah di tengah frame.\nPastikan cahaya cukup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: kGreenLight, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: kGreenMed, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── State 2: Sedang menganalisis ──────────────────────────────────
  Widget _buildAnalyzing() {
    return const Scaffold(
      backgroundColor: kBgMain,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kGreenMed, strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Menganalisis ekspresi wajah...',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                color: kInkMed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 3: Hasil mood ───────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final color = stressColor(
      r.score >= 50
          ? 'low'
          : r.score >= 30
              ? 'moderate'
              : 'high',
    );

    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultAppBar(),
              const SizedBox(height: 16),
              const BmSectionHeader('HASIL MOOD CHECK-IN'),
              // Kartu skor + radial badge (overlap kanan atas, dari wireframe)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BmScoreCard(
                    label: 'Mood Score',
                    score: r.score,
                    unit: '/100',
                    statusLabel: r.label.toUpperCase(),
                    statusColor: color,
                  ),
                  Positioned(
                    right: 20,
                    top: 20,
                    child: _radialBadge(r.score, color),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBreakdownCard(r),
              const Spacer(),
              BmPrimaryButton(
                label: 'Lanjut → Ukur Stres',
                icon: const Icon(Icons.arrow_forward,
                    color: Colors.white, size: 18),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/tremor',
                  arguments: r, // kirim MoodResult ke screen berikutnya
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kartu breakdown 3 metrik zona wajah
  Widget _buildBreakdownCard(MoodResult r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analisis per zona',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kInkDark,
            ),
          ),
          const SizedBox(height: 14),
          _breakdownRow('Kecerahan Wajah', r.brightness),
          const SizedBox(height: 10),
          _breakdownRow('Keterbukaan Mata', r.eyeOpenness),
          const SizedBox(height: 10),
          _breakdownRow('Ekspresi Mulut', r.mouthCurve),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: kInkMed)),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 13,
                color: kInkDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: kGreenPale,
            color: kGreenLight,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildResultAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _state = CheckinState.preview),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kInkDark.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: kInkDark),
          ),
        ),
        const Spacer(),
        const Text(
          'Check-in Mood',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kInkDark,
          ),
        ),
        const Spacer(),
        // Step indicator 1 / 3 (dari wireframe)
        const SizedBox(
          width: 40,
          child: Text(
            '1 / 3',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'DMmono',
              fontSize: 11,
              color: kInkLight,
            ),
          ),
        ),
      ],
    );
  }

  // Radial badge persentase skor — lingkaran progress kecil
  Widget _radialBadge(double score, Color color) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: Colors.white.withOpacity(0.6),
              color: color,
            ),
          ),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontFamily: 'DMmono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kGreenDark,
            ),
          ),
        ],
      ),
    );
  }

  // Tombol kaca untuk layar kamera gelap
  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}
