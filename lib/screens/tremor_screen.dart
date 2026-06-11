// lib/screens/tremor_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../services/accelerometer_service.dart';
import '../logic/tremor_calculator.dart';
import '../models/mood_result.dart';

enum TremorState { instruction, measuring, result }

class TremorScreen extends StatefulWidget {
  const TremorScreen({super.key});

  @override
  State<TremorScreen> createState() => _TremorScreenState();
}

class _TremorScreenState extends State<TremorScreen> {
  final _accelService = AccelerometerService();
  final _calculator = TremorCalculator();

  static const int _durationSec = 10;

  TremorState _state = TremorState.instruction;
  int _remaining = _durationSec;
  Timer? _countdownTimer;
  TremorResult? _result;
  MoodResult? _moodResult;
  int _sampleCount = 0;

  // Buffer magnitude terbaru untuk grafik live (maks ~60 titik)
  final List<double> _liveMagnitudes = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moodResult ??=
        ModalRoute.of(context)?.settings.arguments as MoodResult?;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Mulai pengukuran: rekam accelerometer + countdown UI + grafik live
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
    switch (_state) {
      case TremorState.instruction:
        return _buildInstruction();
      case TremorState.measuring:
        return _buildMeasuring();
      case TremorState.result:
        return _buildResult();
    }
  }

  // ── State 1: Instruksi ────────────────────────────────────────────
  Widget _buildInstruction() {
    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _appBar('Ukur Stres', step: '2 / 3'),
              const SizedBox(height: 16),
              const BmSectionHeader('DETEKSI STRES'),
              const Spacer(),
              // Lingkaran dashed + hint "HP + 2 tangan"
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    shape: BoxShape.circle,
                    border: Border.all(color: kGreenLight, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.front_hand_outlined,
                          color: kGreenMed, size: 48),
                      SizedBox(height: 4),
                      Text('HP + 2 tangan',
                          style: TextStyle(fontSize: 11, color: kInkMed)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Pegang HP dengan 2 tangan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kInkDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tetap diam selama 10 detik. Kami mengukur getaran tangan '
                'untuk menilai tingkat stres.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kInkMed, height: 1.6),
              ),
              const SizedBox(height: 16),
              const Center(child: BmChip(label: 'Accelerometer aktif')),
              const Spacer(),
              BmPrimaryButton(
                label: 'Mulai Pengukuran',
                icon: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 20),
                onTap: _startMeasuring,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State 2: Mengukur (countdown ring + grafik live) ──────────────
  Widget _buildMeasuring() {
    final progress = (_durationSec - _remaining) / _durationSec;
    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('2 / 3',
                    style: TextStyle(
                        fontFamily: 'DMmono', fontSize: 11, color: kInkLight)),
              ),
              const BmSectionHeader('SEDANG MENGUKUR…'),
              const SizedBox(height: 8),
              // Countdown ring
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: kGreenPale,
                          color: kGreenMed,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_remaining',
                              style: const TextStyle(
                                fontFamily: 'DMmono',
                                fontSize: 48,
                                fontWeight: FontWeight.w500,
                                color: kGreenDark,
                                height: 1,
                              )),
                          const Text('dtk tersisa',
                              style:
                                  TextStyle(fontSize: 10, color: kInkLight)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Grafik live magnitude
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kHairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('MAGNITUDE m/s²',
                            style: TextStyle(
                                fontFamily: 'DMmono',
                                fontSize: 9,
                                color: kInkLight,
                                letterSpacing: 0.5)),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 7, color: kGreenMed),
                            SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(
                                    fontFamily: 'DMmono',
                                    fontSize: 9,
                                    color: kGreenMed)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WavePainter(_liveMagnitudes),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('−10s',
                            style:
                                TextStyle(fontSize: 9, color: kInkLight)),
                        Text('0',
                            style:
                                TextStyle(fontSize: 9, color: kInkLight)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'jangan gerakkan HP — tarik napas pelan',
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: kInkMed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State 3: Hasil stress level ───────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final color = stressColor(r.level);
    final levelText = r.level.toUpperCase();
    final desc = r.level == 'low'
        ? 'tubuh rileks'
        : r.level == 'moderate'
            ? 'sedikit tegang'
            : 'stres tinggi';

    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _appBar('Hasil Stres', step: '2 / 3'),
              const SizedBox(height: 16),
              const BmSectionHeader('HASIL DETEKSI STRES'),
              // Card dengan border kiri 4px sesuai warna level
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border(left: BorderSide(color: color, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TINGKAT STRES',
                        style: TextStyle(
                            fontFamily: 'DMmono',
                            fontSize: 9,
                            color: color,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(levelText,
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        const SizedBox(width: 8),
                        Text('· $desc',
                            style: const TextStyle(
                                fontSize: 12, color: kInkMed)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tabel metrik (semua nilai nyata)
              _metricsCard(r),
              const SizedBox(height: 16),
              // Skala 3 segmen LOW / MOD / HIGH
              _stressScale(r.level),
              const Spacer(),
              BmPrimaryButton(
                label: 'Lanjut → Sesi Pernapasan',
                icon: const Icon(Icons.arrow_forward,
                    color: Colors.white, size: 18),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/breathing',
                  arguments: {
                    'moodResult': _moodResult,
                    'tremorResult': r,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricsCard(TremorResult r) {
    final rows = [
      ['Variansi getaran', r.variance.toStringAsFixed(3)],
      ['Jumlah sampel', '$_sampleCount'],
      ['Durasi', '${_durationSec.toStringAsFixed(1)} s'],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row[0],
                          style: const TextStyle(
                              fontSize: 12, color: kInkMed)),
                      Text(row[1],
                          style: const TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kInkDark)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // Skala 3 segmen: segmen aktif diisi warna level
  Widget _stressScale(String level) {
    Widget seg(String key, Color color) {
      final active = key == level;
      return Expanded(
        child: Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: active ? color : kHairline, width: 1.2),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            seg('low', kStressLow),
            seg('moderate', kStressMed),
            seg('high', kStressHigh),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('LOW', style: TextStyle(fontSize: 9, color: kInkLight)),
            Text('MOD', style: TextStyle(fontSize: 9, color: kInkLight)),
            Text('HIGH', style: TextStyle(fontSize: 9, color: kInkLight)),
          ],
        ),
      ],
    );
  }

  Widget _appBar(String title, {String? step}) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kInkDark,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 40,
          child: Text(
            step ?? '',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontFamily: 'DMmono', fontSize: 11, color: kInkLight),
          ),
        ),
      ],
    );
  }
}

// Painter grafik magnitude realtime
class _WavePainter extends CustomPainter {
  final List<double> data;
  _WavePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final minV = data.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final paint = Paint()
      ..color = kGreenMed
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1));
      final norm = (data[i] - minV) / range;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
