// lib/screens/checkin_screen.dart
// UI dirancang ulang dari nol — selaras dengan Home: gradient berlapis,
// tipografi editorial, viewfinder berkrafting, gauge arc untuk skor.
// Logika kamera / fill light / kecerahan / analisis TIDAK diubah.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../services/camera_service.dart';
import '../logic/mood_analyzer.dart';
import '../models/mood_result.dart';

enum CheckinState { preview, analyzing, result }

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kBgMain, Color(0xFFEFF3EA), Color(0xFFE7F0E5)],
  stops: [0.0, 0.6, 1.0],
);

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with SingleTickerProviderStateMixin {
  final _cameraService = CameraService();
  final _analyzer = MoodAnalyzer();

  CheckinState _state = CheckinState.preview;
  MoodResult? _result;
  String? _error;

  // Denyut untuk cincin "menganalisis"
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boostBrightness());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _restoreBrightness();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _boostBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.init();
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Kamera tidak dapat diakses. Periksa izin kamera.');
      }
      return;
    }
    await _boostBrightness();
    if (mounted) setState(() {});
  }

  // Ambil foto → analisis → hasil. Senter layar dimatikan tepat setelah jepret.
  Future<void> _capture() async {
    setState(() => _state = CheckinState.analyzing);

    final photo = await _cameraService.takePicture();
    await _restoreBrightness();

    if (photo == null) {
      await _boostBrightness();
      setState(() => _state = CheckinState.preview);
      return;
    }

    final result = await _analyzer.analyze(photo);
    // Tahan di layar "menganalisis" minimal 5 detik agar prosesnya terlihat
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    setState(() {
      _result = result;
      _state = CheckinState.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(_error != null ? 'error' : _state),
        child: _buildCurrent(),
      ),
    );
  }

  Widget _buildCurrent() {
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

  // ── Header dipakai ulang: back + judul + step ─────────────────────
  Widget _topBar({
    required String step,
    required VoidCallback onBack,
    bool onWhite = true,
  }) {
    return Row(
      children: [
        _circleBtn(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
          onWhite: onWhite,
        ),
        const Spacer(),
        Text(
          'CHECK-IN',
          style: TextStyle(
            fontFamily: 'DMmono',
            fontSize: 11,
            letterSpacing: 2.0,
            color: onWhite ? kInkLight : kInkLight,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 44,
          child: Text(
            step,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'DMmono',
              fontSize: 11,
              color: kInkLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool onWhite = true,
  }) {
    return BmPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onWhite ? Colors.white.withOpacity(0.7) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: kHairline),
        ),
        child: Icon(icon, color: kInkDark, size: 20),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────
  Widget _buildError() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kPadH),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                      color: kGreenPale, shape: BoxShape.circle),
                  child: const Icon(Icons.no_photography_outlined,
                      color: kGreenMed, size: 40),
                ),
                const SizedBox(height: 20),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: kInkMed, height: 1.5)),
                const SizedBox(height: 24),
                BmOutlineButton(
                  label: 'Kembali',
                  onTap: () async {
                    await _restoreBrightness();
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── State 1: Preview (putih = senter layar) ───────────────────────
  Widget _buildPreview() {
    final ready = _cameraService.controller != null &&
        _cameraService.isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
          child: Column(
            children: [
              _topBar(
                step: '1 / 3',
                onBack: () async {
                  await _restoreBrightness();
                  if (mounted) Navigator.pop(context);
                },
              ),
              const Spacer(),
              const Text(
                'Posisikan wajah\ndi dalam bingkai',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kInkDark,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 24),
              // Viewfinder: jendela kamera + corner ticks
              _viewfinder(ready),
              const SizedBox(height: 20),
              
              const Spacer(),
              // Shutter orb
              _shutter(onTap: ready ? _capture : null),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewfinder(bool ready) {
    const w = 248.0, h = 320.0;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              width: w,
              height: h,
              child: ready
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraService
                                .controller!.value.previewSize?.height ??
                            w,
                        height: _cameraService
                                .controller!.value.previewSize?.width ??
                            h,
                        child: CameraPreview(_cameraService.controller!),
                      ),
                    )
                  : Container(
                      color: kGreenPale,
                      child: const Center(
                        child: CircularProgressIndicator(color: kGreenMed),
                      ),
                    ),
            ),
          ),
          // Oval panduan wajah
          IgnorePointer(
            child: Container(
              width: 170,
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                border: Border.all(
                    color: Colors.white.withOpacity(0.85), width: 2),
              ),
            ),
          ),
          // Corner ticks (viewfinder)
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _CornerTicks())),
          ),
        ],
      ),
    );
  }

  Widget _shutter({VoidCallback? onTap}) {
    return BmPressable(
      scale: 0.92,
      onTap: onTap,
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // cincin luar
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kGreenLight.withOpacity(0.5), width: 2),
              ),
            ),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: kGreenMed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kGreenMed.withOpacity(0.4),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 2: Analyzing (cincin napas berdenyut) ───────────────────
  Widget _buildAnalyzing() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => CustomPaint(
                  painter: _PulseRings(_pulse.value),
                  child: child,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [Colors.white, kGreenLight, kGreenMed],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: const Icon(Icons.face_retouching_natural,
                      color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Menganalisis ekspresi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kInkDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Membaca 3 zona wajah…',
                  style: TextStyle(fontSize: 13, color: kInkMed)),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  BmChip(label: 'Kecerahan'),
                  SizedBox(width: 8),
                  BmChip(label: 'Mata'),
                  SizedBox(width: 8),
                  BmChip(label: 'Mulut'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State 3: Result (gauge arc) ───────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final level = r.score >= 50
        ? 'low'
        : r.score >= 30
            ? 'moderate'
            : 'high';
    final color = stressColor(level);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(
                  step: '1 / 3',
                  onBack: () {
                    _boostBrightness();
                    setState(() => _state = CheckinState.preview);
                  },
                ),
                const SizedBox(height: 8),
                BmFadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: const Text(
                    'Hasil mood',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: kInkDark,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const Spacer(),
                // Gauge arc hero
                BmFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: Center(child: _scoreGauge(r, color)),
                ),
                const SizedBox(height: 18),
                BmFadeIn(
                  delay: const Duration(milliseconds: 160),
                  child: Center(
                    child: BmChip(
                      label: '${moodEmoji(r.label)}  ${r.label.toUpperCase()}',
                      color: color,
                      bg: color.withOpacity(0.14),
                      showDot: false,
                    ),
                  ),
                ),
                const Spacer(),
                // Breakdown 3 zona
                BmFadeIn(
                  delay: const Duration(milliseconds: 220),
                  child: _breakdownCard(r),
                ),
                const SizedBox(height: 18),
                BmPrimaryButton(
                  label: 'Mulai Ukur Stres',
                  icon: const Icon(Icons.sensors_rounded,
                      color: Colors.white, size: 20),
                  onTap: () =>
                      Navigator.pushNamed(context, '/tremor', arguments: r),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreGauge(MoodResult r, Color color) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (r.score / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CustomPaint(
              size: const Size(220, 220),
              painter: _GaugePainter(v, color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.score.toStringAsFixed(0),
                style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 64,
                  fontWeight: FontWeight.w500,
                  color: kGreenDark,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 2),
              const Text('MOOD SCORE / 100',
                  style: TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 10,
                      color: kInkLight,
                      letterSpacing: 1.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(MoodResult r) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ANALISIS PER ZONA',
              style: TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 9,
                  color: kInkLight,
                  letterSpacing: 1.4)),
          const SizedBox(height: 14),
          _zoneRow('Kecerahan wajah', r.brightness),
          const SizedBox(height: 12),
          _zoneRow('Keterbukaan mata', r.eyeOpenness),
          const SizedBox(height: 12),
          _zoneRow('Ekspresi mulut', r.mouthCurve),
        ],
      ),
    );
  }

  Widget _zoneRow(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: kInkMed)),
            Text('${(value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontFamily: 'DMmono', fontSize: 13, color: kInkDark)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              backgroundColor: kGreenPale,
              color: kGreenMed,
              minHeight: 7,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Painters ────────────────────────────────────────────────────────

// Sudut viewfinder (4 siku-siku)
class _CornerTicks extends CustomPainter {
  const _CornerTicks();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 22.0, m = 14.0;
    final w = size.width, h = size.height;
    // kiri atas
    canvas.drawLine(Offset(m, m + len), Offset(m, m), p);
    canvas.drawLine(Offset(m, m), Offset(m + len, m), p);
    // kanan atas
    canvas.drawLine(Offset(w - m - len, m), Offset(w - m, m), p);
    canvas.drawLine(Offset(w - m, m), Offset(w - m, m + len), p);
    // kiri bawah
    canvas.drawLine(Offset(m, h - m - len), Offset(m, h - m), p);
    canvas.drawLine(Offset(m, h - m), Offset(m + len, h - m), p);
    // kanan bawah
    canvas.drawLine(Offset(w - m - len, h - m), Offset(w - m, h - m), p);
    canvas.drawLine(Offset(w - m, h - m), Offset(w - m, h - m - len), p);
  }

  @override
  bool shouldRepaint(_CornerTicks oldDelegate) => false;
}

// Cincin menyebar saat menganalisis
class _PulseRings extends CustomPainter {
  final double t; // 0..1
  _PulseRings(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = base + phase * 46;
      final opacity = (1 - phase) * 0.35;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = kGreenMed.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRings oldDelegate) => oldDelegate.t != t;
}

// Gauge arc 270° untuk skor mood
class _GaugePainter extends CustomPainter {
  final double value; // 0..1
  final Color color;
  _GaugePainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..color = kGreenPale
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * value,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [kGreenLight, kGreenMed, kGreenDark],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
