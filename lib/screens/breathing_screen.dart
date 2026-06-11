// lib/screens/breathing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../services/haptic_service.dart';
import '../services/camera_service.dart';
import '../logic/mood_analyzer.dart';
import '../logic/score_combiner.dart';
import '../models/mood_result.dart';
import '../models/session_model.dart';
import '../logic/tremor_calculator.dart';
import '../database/database_helper.dart';

enum BreathingState { summary, session, donePrompt, postPhoto, result }

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  final _haptic = HapticService();
  final _cameraService = CameraService();
  final _analyzer = MoodAnalyzer();
  final _combiner = ScoreCombiner();

  late AnimationController _orbController;

  BreathingState _state = BreathingState.summary;
  String _phase = 'inhale';
  int _cycle = 1;
  int _phaseRemaining = 4;
  Timer? _phaseTimer;

  MoodResult? _moodBefore;
  TremorResult? _tremor;
  MoodResult? _moodAfter;
  double _relaxScore = 0;
  bool _saving = false;
  bool _argsLoaded = false;
  final DateTime _startTime = DateTime.now();

  static const _phaseSeconds = {'inhale': 4, 'hold': 7, 'exhale': 8};

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.7,
      upperBound: 1.05,
      value: 0.85,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _moodBefore = args['moodResult'] as MoodResult?;
      _tremor = args['tremorResult'] as TremorResult?;
    }
    _argsLoaded = true;
  }

  @override
  void dispose() {
    _haptic.stop();
    _phaseTimer?.cancel();
    _orbController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  // Mulai sesi haptic 4-7-8 × 3 siklus
  Future<void> _startSession() async {
    setState(() => _state = BreathingState.session);

    await _haptic.runFullSession(
      onUpdate: (cycle, phase) {
        if (!mounted) return;
        setState(() {
          _cycle = cycle;
          _phase = phase;
        });
        _startPhaseCountdown(phase);
        // Animasi orb mengikuti fase
        if (phase == 'inhale' || phase == 'hold') {
          _orbController.animateTo(1.05);
        } else {
          _orbController.animateTo(0.7);
        }
      },
      onSessionComplete: () {
        if (!mounted) return;
        _phaseTimer?.cancel();
        setState(() => _state = BreathingState.donePrompt);
      },
    );
  }

  // Countdown detik di dalam fase berjalan
  void _startPhaseCountdown(String phase) {
    _phaseTimer?.cancel();
    setState(() => _phaseRemaining = _phaseSeconds[phase]!);
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_phaseRemaining > 0) _phaseRemaining--;
      });
    });
  }

  // Buka kamera untuk foto akhir
  Future<void> _openCamera() async {
    setState(() => _state = BreathingState.postPhoto);
    try {
      await _cameraService.init();
      if (mounted) setState(() {});
    } catch (_) {
      _finishWithoutPhoto();
    }
  }

  Future<void> _capturePostPhoto() async {
    final photo = await _cameraService.takePicture();
    if (photo == null) {
      _finishWithoutPhoto();
      return;
    }
    final after = await _analyzer.analyze(photo);
    if (!mounted) return;
    _computeAndShow(after);
  }

  // Lewati foto akhir: pakai mood awal sebagai pembanding
  void _finishWithoutPhoto() {
    if (_moodBefore != null) _computeAndShow(_moodBefore!);
  }

  void _computeAndShow(MoodResult after) {
    final before = _moodBefore?.score ?? 50;
    final relax = _combiner.calcRelaxScore(before, after.score);
    setState(() {
      _moodAfter = after;
      _relaxScore = relax;
      _state = BreathingState.result;
    });
  }

  // Simpan sesi ke database lalu kembali ke Home
  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    final durationSec = DateTime.now().difference(_startTime).inSeconds;
    final session = SessionModel(
      date: DateTime.now().toIso8601String().substring(0, 10),
      moodBefore: _moodBefore?.score ?? 50,
      moodLabel: _moodBefore?.label ?? 'netral',
      stressLevel: _tremor?.level ?? 'moderate',
      moodAfter: _moodAfter?.score,
      relaxScore: _relaxScore,
      durationSec: durationSec,
    );
    await DatabaseHelper.instance.insertSession(session);
    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case BreathingState.summary:
        return _buildSummary();
      case BreathingState.session:
        return _buildSession();
      case BreathingState.donePrompt:
        return _buildDonePrompt();
      case BreathingState.postPhoto:
        return _buildPostPhoto();
      case BreathingState.result:
        return _buildResult();
    }
  }

  // ── State 1: Ringkasan kondisi ────────────────────────────────────
  Widget _buildSummary() {
    final moodScore = _moodBefore?.score ?? 50;
    final stressLevel = _tremor?.level ?? 'moderate';
    final combined = _combiner.combine(moodScore, stressLevel);
    final moodDesc = _moodDesc(moodScore);
    final stressDesc = stressLevel == 'low'
        ? 'tubuh rileks'
        : stressLevel == 'moderate'
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
              _appBar('Sesi Pernapasan', step: '3 / 3'),
              const SizedBox(height: 16),
              const BmSectionHeader('RINGKASAN KONDISI'),
              // Dua kotak statistik: MOOD + STRES
              Row(
                children: [
                  Expanded(
                    child: _statBox(
                      label: 'MOOD',
                      value: moodScore.toStringAsFixed(0),
                      valueColor: kGreenDark,
                      desc: moodDesc,
                      bg: kGreenPale,
                      labelColor: kInkMed,
                      big: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statBox(
                      label: 'STRES',
                      value: stressLevel.toUpperCase(),
                      valueColor: stressColor(stressLevel),
                      desc: stressDesc,
                      bg: kBgCard,
                      labelColor: stressColor(stressLevel),
                      big: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Kartu rekomendasi
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kHairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: kGreenPale, shape: BoxShape.circle),
                          child: const Icon(Icons.lightbulb_outline,
                              color: kGreenMed, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('REKOMENDASI',
                                style: TextStyle(
                                    fontFamily: 'DMmono',
                                    fontSize: 9,
                                    color: kInkLight,
                                    letterSpacing: 1.4)),
                            SizedBox(height: 2),
                            Text('Pola 4-7-8 · 3 siklus',
                                style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kInkDark)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(combined.rekomendasi,
                        style: const TextStyle(
                            fontSize: 13, color: kInkMed, height: 1.5)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _miniStat('~3 mnt', 'durasi'),
                        _miniStat('3×', 'siklus'),
                        _miniStat('Pelan', 'tempo'),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              BmPrimaryButton(
                label: 'Mulai Sesi Pernapasan',
                icon: const Icon(Icons.spa_outlined,
                    color: Colors.white, size: 20),
                onTap: _startSession,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _moodDesc(double score) {
    if (score >= 70) return 'sangat tenang';
    if (score >= 50) return 'cukup tenang';
    if (score >= 30) return 'agak tegang';
    return 'kelelahan';
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color valueColor,
    required String desc,
    required Color bg,
    required Color labelColor,
    required bool big,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadius),
        border: bg == kBgCard ? Border.all(color: kHairline) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 9,
                  color: labelColor,
                  letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontFamily: big ? 'DMmono' : 'PlusJakartaSans',
                  fontSize: big ? 28 : 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  height: 1.1)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 10, color: kInkMed)),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kInkDark)),
        Text(label, style: const TextStyle(fontSize: 9, color: kInkLight)),
      ],
    );
  }

  // ── State 2: Sesi pernapasan (rings + orb + countdown) ────────────
  Widget _buildSession() {
    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            children: [
              // Top: close + SIKLUS + spacer
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _haptic.stop();
                      _phaseTimer?.cancel();
                      setState(() => _state = BreathingState.donePrompt);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kInkDark.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.close, size: 18, color: kInkDark),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      const Text('SIKLUS',
                          style: TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 9,
                              color: kInkLight,
                              letterSpacing: 1.4)),
                      Text('$_cycle / 3',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kInkDark)),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 16),
              _phaseDots(),
              const Spacer(),
              // Guide rings + orb
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 270,
                      height: 270,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kGreenLight.withOpacity(0.3), width: 1),
                      ),
                    ),
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kGreenLight.withOpacity(0.5), width: 1),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _orbController,
                      builder: (context, _) => _BreathingOrb(
                        phase: _phase,
                        scale: _orbController.value,
                        label: _phaseLabel(_phase),
                        seconds: _phaseSeconds[_phase]!,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Countdown angka besar
              Text(
                _phaseRemaining.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: kGreenDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text('DETIK · IKUTI LINGKARAN',
                  style: TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 9,
                      color: kInkLight,
                      letterSpacing: 1.2)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phaseDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['inhale', 'hold', 'exhale'].map((p) {
        final active = p == _phase;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? kGreenMed : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active ? null : Border.all(color: kHairline),
          ),
          child: Text(
            p == 'inhale'
                ? 'TARIK'
                : p == 'hold'
                    ? 'TAHAN'
                    : 'BUANG',
            style: TextStyle(
              fontFamily: 'DMmono',
              fontSize: 11,
              letterSpacing: 1.0,
              color: active ? Colors.white : kInkLight,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'inhale':
        return 'Tarik Napas';
      case 'hold':
        return 'Tahan';
      default:
        return 'Buang Napas';
    }
  }

  // ── State 3: "Sesi selesai" prompt sebelum foto akhir ─────────────
  Widget _buildDonePrompt() {
    final durationSec = DateTime.now().difference(_startTime).inSeconds;
    final mm = (durationSec ~/ 60).toString().padLeft(1, '0');
    final ss = (durationSec % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('BreathMark',
                    style: TextStyle(fontSize: 12, color: kInkLight)),
              ),
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                    color: kGreenPale, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: kGreenMed, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Sesi selesai',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kInkDark)),
              const SizedBox(height: 8),
              const Text(
                'Bagus! Foto wajah sekali lagi untuk melihat\nperubahan mood sebelum & sesudah.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kInkMed, height: 1.6),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _doneStat('3', 'siklus'),
                  const SizedBox(width: 28),
                  _doneStat('$mm:$ss', 'durasi'),
                ],
              ),
              const Spacer(),
              BmPrimaryButton(
                label: 'Ambil Foto Akhir',
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                onTap: _openCamera,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _finishWithoutPhoto,
                child: const Text('atau lewati →',
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: kInkLight)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kGreenDark)),
        Text(label, style: const TextStyle(fontSize: 9, color: kInkLight)),
      ],
    );
  }

  // ── State 4: Foto akhir (kamera) ──────────────────────────────────
  Widget _buildPostPhoto() {
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
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Text(
                  'Foto wajah sekali lagi\nuntuk melihat perubahan mood.',
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
                  onTap: _capturePostPhoto,
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

  // ── State 5: Hasil (before/after + relax + sparkline) ─────────────
  Widget _buildResult() {
    final before = _moodBefore?.score ?? 50;
    final after = _moodAfter?.score ?? before;
    final label = _combiner.getRelaxLabel(_relaxScore);

    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('BreathMark',
                      style: TextStyle(fontSize: 12, color: kInkLight)),
                  Text('Selesai',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kGreenMed)),
                ],
              ),
              const SizedBox(height: 12),
              const BmSectionHeader('HASIL SESI'),
              // Before / After
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kGreenPale,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _beforeAfterCol(
                        'SEBELUM',
                        moodEmoji(_moodBefore?.label ?? 'netral'),
                        before,
                        _moodDesc(before),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: kInkMed),
                    Expanded(
                      child: _beforeAfterCol(
                        'SESUDAH',
                        moodEmoji(_moodAfter?.label ?? _moodBefore?.label ?? 'netral'),
                        after,
                        _moodDesc(after),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Relax score + sparkline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kHairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RELAXATION SCORE',
                            style: TextStyle(
                                fontFamily: 'DMmono',
                                fontSize: 9,
                                color: kRelax,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('+${_relaxScore.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontFamily: 'DMmono',
                                    fontSize: 38,
                                    fontWeight: FontWeight.w500,
                                    color: kRelax,
                                    height: 1)),
                            const SizedBox(width: 4),
                            const Text('%',
                                style: TextStyle(
                                    fontFamily: 'DMmono',
                                    fontSize: 14,
                                    color: kInkMed)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BmChip(
                          label: label,
                          color: kRelax,
                          bg: kRelax.withOpacity(0.12),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 70,
                      height: 40,
                      child: CustomPaint(painter: _SparklinePainter()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Status chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BmChip(
                      label: '📸 foto ok',
                      color: kGreenDark,
                      bg: kGreenPale,
                      showDot: false),
                  BmChip(
                      label: '📊 accel ok',
                      color: kGreenDark,
                      bg: kGreenPale,
                      showDot: false),
                  BmChip(
                      label: '💚 3 siklus',
                      color: kGreenDark,
                      bg: kGreenPale,
                      showDot: false),
                ],
              ),
              const Spacer(),
              BmPrimaryButton(
                label: _saving ? 'Menyimpan...' : 'Simpan & Selesai',
                icon: _saving
                    ? null
                    : const Icon(Icons.check, color: Colors.white, size: 18),
                onTap: _saving ? null : _saveAndFinish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _beforeAfterCol(
      String label, String emoji, double score, String desc) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 9,
                color: kInkLight,
                letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text(emoji, style: const TextStyle(fontSize: 22)),
        Text(score.toStringAsFixed(0),
            style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: kGreenDark,
                height: 1.1)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 9, color: kInkMed)),
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

// ── BreathingOrb: lingkaran yang mengembang/mengempis per fase ──────
class _BreathingOrb extends StatelessWidget {
  final String phase;
  final double scale;
  final String label;
  final int seconds;

  const _BreathingOrb({
    required this.phase,
    required this.scale,
    required this.label,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColors = {
      'inhale': [kGreenLight, const Color(0x80668B6A)],
      'hold': [kGreenMed, const Color(0x722E7D32)],
      'exhale': [kGreenPale, const Color(0xB2E8F5E9)],
    };
    final colors = phaseColors[phase] ?? phaseColors['inhale']!;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [Colors.white, colors[0], kGreenMed],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: colors[1], blurRadius: 70, spreadRadius: 16),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text('$seconds detik',
                style: const TextStyle(fontSize: 11, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// Sparkline tren naik di kartu relaxation score
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.85, 0.7, 0.74, 0.4, 0.5, 0.16];
    final paint = Paint()
      ..color = kRelax
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = size.width * (i / (pts.length - 1));
      final y = size.height * pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    // titik akhir
    canvas.drawCircle(
      Offset(size.width, size.height * pts.last),
      2.5,
      Paint()..color = kRelax,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => false;
}
