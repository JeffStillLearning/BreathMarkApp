// lib/screens/tremor_screen.dart
// UI dirancang ulang dari nol — selaras dengan Home/Check-in: gradient berlapis,
// tipografi editorial, gauge arc countdown, stress meter berkrafting.
// Logika accelerometer / countdown / kalkulasi / navigasi TIDAK diubah.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../services/accelerometer_service.dart';
import '../logic/tremor_calculator.dart';
import '../models/mood_result.dart';

enum TremorState { instruction, measuring, result }

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kBgMain, Color(0xFFEFF3EA), Color(0xFFE7F0E5)],
  stops: [0.0, 0.6, 1.0],
);

class TremorScreen extends StatefulWidget {
  const TremorScreen({super.key});

  @override
  State<TremorScreen> createState() => _TremorScreenState();
}

class _TremorScreenState extends State<TremorScreen>
    with SingleTickerProviderStateMixin {
  final _accelService = AccelerometerService();
  final _calculator = TremorCalculator();

  static const int _durationSec = 10;

  TremorState _state = TremorState.instruction;
  int _remaining = _durationSec;
  Timer? _countdownTimer;
  TremorResult? _result;
  MoodResult? _moodResult;
  int _sampleCount = 0;

  final List<double> _liveMagnitudes = [];

  // Denyut untuk cincin instruksi
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moodResult ??=
        ModalRoute.of(context)?.settings.arguments as MoodResult?;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // Mulai pengukuran: rekam accelerometer + countdown + grafik live
  Future<void> _startMeasuring() async {
    setState(() {
      _state = TremorState.measuring;
      _remaining = _durationSec;
      _liveMagnitudes.clear();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });

    final rawData = await _accelService.record(
      durationSeconds: _durationSec,
      onSample: (magnitude) {
        if (!mounted) return;
        setState(() {
          _liveMagnitudes.add(magnitude);
          if (_liveMagnitudes.length > 60) _liveMagnitudes.removeAt(0);
        });
      },
    );
    final result = _calculator.calculate(rawData);

    if (!mounted) return;
    setState(() {
      _result = result;
      _sampleCount = rawData.length;
      _state = TremorState.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey(_state), child: _buildCurrent()),
    );
  }

  Widget _buildCurrent() {
    switch (_state) {
      case TremorState.instruction:
        return _buildInstruction();
      case TremorState.measuring:
        return _buildMeasuring();
      case TremorState.result:
        return _buildResult();
    }
  }

  // ── Shell gradient + top bar ──────────────────────────────────────
  Widget _shell({required List<Widget> children, VoidCallback? onBack}) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(onBack: onBack),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar({VoidCallback? onBack}) {
    return Row(
      children: [
        BmPressable(
          onTap: onBack ?? () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: kHairline),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: kInkDark, size: 20),
          ),
        ),
        const Spacer(),
        const Text('UKUR STRES',
            style: TextStyle(
                fontFamily: 'DMmono',
                fontSize: 11,
                letterSpacing: 2.0,
                color: kInkLight)),
        const Spacer(),
        const SizedBox(
          width: 44,
          child: Text('2 / 3',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: 'DMmono', fontSize: 11, color: kInkLight)),
        ),
      ],
    );
  }

  // ── State 1: Instruksi ────────────────────────────────────────────
  Widget _buildInstruction() {
    return _shell(
      children: [
        const SizedBox(height: 8),
        BmFadeIn(
          delay: const Duration(milliseconds: 40),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ukur ketenangan\ntanganmu',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: kInkDark,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ),
        ),
        const Spacer(),
        // Hero: cincin berdenyut + ikon
        BmFadeIn(
          delay: const Duration(milliseconds: 120),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => CustomPaint(
                painter: _PulseRings(_pulse.value),
                child: child,
              ),
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [Colors.white, kGreenLight, kGreenMed],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: const Icon(Icons.front_hand_rounded,
                    color: Colors.white, size: 56),
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),
        BmFadeIn(
          delay: const Duration(milliseconds: 200),
          child: Column(
            children: const [
              Text(
                'Pegang HP dengan 2 tangan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: kInkDark,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Tetap diam selama 10 detik. Kami membaca getaran\nhalus tanganmu untuk menilai tingkat stres.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kInkMed, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Spacer(),
        BmPrimaryButton(
          label: 'Mulai Pengukuran',
          icon: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 22),
          onTap: _startMeasuring,
        ),
      ],
    );
  }

  // ── State 2: Mengukur (orb reaktif terhadap gerakan) ──────────────
  Widget _buildMeasuring() {
    final progress = (_durationSec - _remaining) / _durationSec;
    final mv = _movementLevel; // 0 = diam, 1 = banyak gerak
    final stable = mv < 0.35;
    // Warna orb: hijau tenang → kuning → merah seiring gerakan
    final orbColor = mv < 0.5
        ? Color.lerp(kGreenMed, kStressMed, mv / 0.5)!
        : Color.lerp(kStressMed, kStressHigh, (mv - 0.5) / 0.5)!;
    final statusColor = stable ? kStressLow : kStressMed;

    return _shell(
      onBack: () {}, // nonaktifkan back saat mengukur
      children: [
        const Spacer(),
        // Hero: gauge waktu + orb reaktif
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(260, 260),
                  painter: _GaugePainter(progress, kGreenMed),
                ),
                // Orb yang scale + warnanya bereaksi ke gerakan nyata
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final breathe = 1 + 0.03 * math.sin(_pulse.value * 2 * math.pi);
                    final jitter = mv * 0.05 *
                        math.sin(_pulse.value * 14 * math.pi);
                    return Transform.scale(scale: breathe + jitter, child: child);
                  },
                  child: Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        colors: [Colors.white, orbColor.withOpacity(0.9), orbColor],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: orbColor.withOpacity(0.4),
                          blurRadius: 50,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_remaining',
                            style: const TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 64,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1,
                              letterSpacing: -2,
                            )),
                        const Text('DETIK',
                            style: TextStyle(
                                fontFamily: 'DMmono',
                                fontSize: 10,
                                color: Colors.white,
                                letterSpacing: 3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        // Status stabilitas (feedback real-time)
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stable ? Icons.check_circle_rounded : Icons.vibration_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  stable ? 'Tahan posisi stabil' : 'Tahan lebih tenang…',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Meter gerakan langsung
        _movementMeter(mv),
        const Spacer(),
        const Center(
          child: Text('Pegang dengan dua tangan, tarik napas pelan',
              style: TextStyle(fontSize: 12.5, color: kInkLight)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Meter horizontal: posisi marker = tingkat gerakan saat ini
  Widget _movementMeter(double mv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return SizedBox(
                height: 20,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kStressLow.withOpacity(0.7),
                          kStressMed.withOpacity(0.7),
                          kStressHigh.withOpacity(0.7),
                        ]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      left: (w * mv.clamp(0.0, 1.0)) - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kInkDark, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('DIAM', style: TextStyle(fontSize: 9, color: kInkLight)),
              Text('BANYAK GERAK',
                  style: TextStyle(fontSize: 9, color: kInkLight)),
            ],
          ),
        ],
      ),
    );
  }

  // Tingkat gerakan 0..1 dari simpangan magnitude terbaru
  double get _movementLevel {
    if (_liveMagnitudes.length < 4) return 0;
    final start = math.max(0, _liveMagnitudes.length - 12);
    final recent = _liveMagnitudes.sublist(start);
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    final variance = recent
            .map((m) => (m - mean) * (m - mean))
            .reduce((a, b) => a + b) /
        recent.length;
    final std = math.sqrt(variance);
    // std ~0 saat diam; beberapa unit saat bergerak. Normalisasi ke 0..1.
    return (std / 3.0).clamp(0.0, 1.0);
  }

  // ── State 3: Hasil ────────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final color = stressColor(r.level);
    final desc = r.level == 'low'
        ? 'Tubuh kamu rileks'
        : r.level == 'moderate'
            ? 'Sedikit tegang'
            : 'Stres tinggi terdeteksi';

    return _shell(
      children: [
        const SizedBox(height: 8),
        BmFadeIn(
          delay: const Duration(milliseconds: 40),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('Tingkat stres',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: kInkDark,
                    letterSpacing: -0.8)),
          ),
        ),
        const Spacer(),
        // Level besar + meter
        BmFadeIn(
          delay: const Duration(milliseconds: 100),
          child: Column(
            children: [
              Text(
                r.level.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(desc,
                  style: const TextStyle(fontSize: 14, color: kInkMed)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        BmFadeIn(
          delay: const Duration(milliseconds: 160),
          child: _stressMeter(r.level),
        ),
        const Spacer(),
        BmFadeIn(
          delay: const Duration(milliseconds: 220),
          child: _metricsCard(r),
        ),
        const SizedBox(height: 18),
        BmPrimaryButton(
          label: 'Mulai Sesi Napas',
          icon: const Icon(Icons.air_rounded, color: Colors.white, size: 20),
          onTap: () => Navigator.pushNamed(
            context,
            '/breathing',
            arguments: {'moodResult': _moodResult, 'tremorResult': r},
          ),
        ),
      ],
    );
  }

  // Meter 3 zona dengan marker pada level aktif
  Widget _stressMeter(String level) {
    final pos = level == 'low'
        ? 0.17
        : level == 'moderate'
            ? 0.5
            : 0.83;
    final markerColor = stressColor(level);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // track 3 zona
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: kStressLow.withOpacity(0.85),
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                            height: 10,
                            color: kStressMed.withOpacity(0.85)),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: kStressHigh.withOpacity(0.85),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // marker
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    left: (w * pos) - 11,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: markerColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: markerColor.withOpacity(0.3),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('LOW', style: TextStyle(fontSize: 9, color: kInkLight)),
            Text('MODERATE',
                style: TextStyle(fontSize: 9, color: kInkLight)),
            Text('HIGH', style: TextStyle(fontSize: 9, color: kInkLight)),
          ],
        ),
      ],
    );
  }

  Widget _metricsCard(TremorResult r) {
    final rows = [
      ['Variansi getaran', r.variance.toStringAsFixed(3)],
      ['Jumlah sampel', '$_sampleCount'],
      ['Durasi', '${_durationSec.toStringAsFixed(1)} s'],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row[0],
                          style: const TextStyle(
                              fontSize: 12.5, color: kInkMed)),
                      Text(row[1],
                          style: const TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kInkDark)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────

// Gauge arc 270° (dipakai untuk countdown)
class _GaugePainter extends CustomPainter {
  final double value;
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
      start, sweep, false,
      Paint()
        ..color = kGreenPale
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep * value.clamp(0.0, 1.0), false,
      Paint()
        ..shader = const SweepGradient(
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
      oldDelegate.value != value;
}

// Cincin menyebar (instruksi)
class _PulseRings extends CustomPainter {
  final double t;
  _PulseRings(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = base + phase * 40;
      final opacity = (1 - phase) * 0.3;
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
