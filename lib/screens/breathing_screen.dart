// lib/screens/breathing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:screen_brightness/screen_brightness.dart';
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

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kBgMain, Color(0xFFEFF3EA), Color(0xFFE7F0E5)],
  stops: [0.0, 0.6, 1.0],
);

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
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
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
        // Animasi orb mengikuti fase — kurva lembut menyerupai napas.
        // Inhale: mengembang 4s · Hold: tahan · Exhale: mengempis 8s.
        final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (phase == 'inhale') {
          _orbController.animateTo(1.05,
              duration: Duration(milliseconds: reduce ? 0 : 4000),
              curve: Curves.easeInOut);
        } else if (phase == 'hold') {
          // tetap mengembang selama fase tahan
        } else {
          _orbController.animateTo(0.7,
              duration: Duration(milliseconds: reduce ? 0 : 8000),
              curve: Curves.easeInOut);
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

  // Buka kamera untuk foto akhir (+ fill light & boost kecerahan)
  Future<void> _openCamera() async {
    setState(() => _state = BreathingState.postPhoto);
    try {
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}
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
    _restoreBrightness(); // foto akhir selesai → kembalikan kecerahan normal
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

  // ── State 1: Ringkasan kondisi (dirancang ulang) ──────────────────
  Widget _buildSummary() {
    final moodScore = _moodBefore?.score ?? 50;
    final stressLevel = _tremor?.level ?? 'moderate';
    final combined = _combiner.combine(moodScore, stressLevel);
    final sColor = stressColor(stressLevel);
    final stressDesc = stressLevel == 'low'
        ? 'tubuh rileks'
        : stressLevel == 'moderate'
            ? 'sedikit tegang'
            : 'stres tinggi';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _appBar('Sesi Napas', step: '3 / 3'),
                const SizedBox(height: 8),
                BmFadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: const Text(
                    'Kondisimu\nsaat ini',
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
                const SizedBox(height: 20),
                // Dua pill kondisi
                BmFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: Row(
                    children: [
                      Expanded(
                        child: _condPill(
                          'MOOD',
                          moodScore.toStringAsFixed(0),
                          _moodDesc(moodScore),
                          kGreenDark,
                          kGreenPale,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _condPill(
                          'STRES',
                          stressLevel.toUpperCase(),
                          stressDesc,
                          sColor,
                          sColor.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Kartu rekomendasi + preview pola 4-7-8
                BmFadeIn(
                  delay: const Duration(milliseconds: 160),
                  child: _recommendationCard(combined.kondisi, combined.rekomendasi),
                ),
                const Spacer(),
                BmPrimaryButton(
                  label: 'Mulai Latihan 4-7-8',
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                  onTap: _startSession,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _moodDesc(double score) {
    if (score >= 70) return 'sangat tenang';
    if (score >= 50) return 'cukup tenang';
    if (score >= 30) return 'sedikit tegang';
    return 'kelelahan';
  }

  // Pill kondisi: angka/level besar + deskripsi
  Widget _condPill(
      String label, String value, String desc, Color color, Color bg) {
    final big = label == 'MOOD'; // MOOD pakai angka mono besar
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 9,
                  color: color,
                  letterSpacing: 1.6)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontFamily: big ? 'DMmono' : 'PlusJakartaSans',
                fontSize: big ? 34 : 20,
                fontWeight: big ? FontWeight.w500 : FontWeight.w800,
                color: color,
                height: 1,
                letterSpacing: big ? -1 : -0.4,
              )),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 11, color: kInkMed)),
        ],
      ),
    );
  }

  // Kartu rekomendasi dengan visual pola 4-7-8 (3 lingkaran)
  Widget _recommendationCard(String kondisi, String rekomendasi) {
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
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: kGreenPale, shape: BoxShape.circle),
                child: const Icon(Icons.spa_rounded, color: kGreenMed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DISARANKAN',
                        style: TextStyle(
                            fontFamily: 'DMmono',
                            fontSize: 9,
                            color: kInkLight,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 2),
                    Text(kondisi,
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInkDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(rekomendasi,
              style: const TextStyle(
                  fontSize: 13, color: kInkMed, height: 1.5)),
          const SizedBox(height: 16),
          // Preview pola 4-7-8
          Row(
            children: [
              _patternDot('4', 'Tarik'),
              _patternConnector(),
              _patternDot('7', 'Tahan'),
              _patternConnector(),
              _patternDot('8', 'Buang'),
              const Spacer(),
              const Text('~1 mnt · 3×',
                  style: TextStyle(
                      fontFamily: 'DMmono', fontSize: 11, color: kInkLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patternDot(String n, String label) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kGreenMed,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(n,
              style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: kInkLight)),
      ],
    );
  }

  Widget _patternConnector() {
    return Container(
      width: 16,
      height: 1.5,
      margin: const EdgeInsets.only(bottom: 13),
      color: kGreenLight,
    );
  }

  // ── State 2: Sesi pernapasan (imersif, latar mengikuti fase) ──────
  Widget _buildSession() {
    // Latar gradient yang berubah lembut mengikuti fase napas
    final List<Color> bg = _phase == 'inhale'
        ? const [Color(0xFFEAF4E7), Color(0xFFD8EBD4)]
        : _phase == 'hold'
            ? const [Color(0xFFDDEBD7), Color(0xFFC3DDBC)]
            : const [Color(0xFFF3F7F0), Color(0xFFE4EFE0)];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 24),
            child: Column(
              children: [
                // Top: close + indikator siklus (3 dot)
                Row(
                  children: [
                    BmPressable(
                      onTap: () {
                        _haptic.stop();
                        _phaseTimer?.cancel();
                        setState(() => _state = BreathingState.donePrompt);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: kHairline),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 20, color: kInkDark),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(3, (i) {
                        final done = i < _cycle - 1;
                        final active = i == _cycle - 1;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: done || active
                                ? kGreenMed
                                : kGreenMed.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 6),
                Text('SIKLUS $_cycle DARI 3',
                    style: const TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 10,
                        color: kInkLight,
                        letterSpacing: 1.8)),
                const Spacer(),
                // Orb + glow rings + label/countdown di tengah
                SizedBox(
                  width: 320,
                  height: 320,
                  child: AnimatedBuilder(
                    animation: _orbController,
                    builder: (context, _) {
                      final v = _orbController.value; // 0.7..1.05
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(320, 320),
                            painter: _OrbGlowPainter(v, _phase),
                          ),
                          Transform.scale(
                            scale: v,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  center: Alignment(-0.3, -0.35),
                                  colors: [
                                    Colors.white,
                                    kGreenLight,
                                    kGreenMed
                                  ],
                                  stops: [0.0, 0.55, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kGreenMed.withOpacity(0.4),
                                    blurRadius: 60,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Label fase + countdown (tidak ikut diskalakan)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _phaseLabel(_phase),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (c, a) => FadeTransition(
                                  opacity: a,
                                  child: ScaleTransition(
                                      scale: Tween(begin: 0.8, end: 1.0)
                                          .animate(a),
                                      child: c),
                                ),
                                child: Text(
                                  '$_phaseRemaining',
                                  key: ValueKey(_phaseRemaining),
                                  style: const TextStyle(
                                    fontFamily: 'DMmono',
                                    fontSize: 44,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Spacer(),
                // Instruksi yang berganti per fase
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _phaseInstruction(_phase),
                    key: ValueKey(_phase),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      color: kInkMed,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _phaseProgress(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tiga segmen fase dengan progress pada fase aktif
  Widget _phaseProgress() {
    final total = _phaseSeconds[_phase]!;
    final within = (total - _phaseRemaining) / total;
    return Row(
      children: ['inhale', 'hold', 'exhale'].map((p) {
        final active = p == _phase;
        final label = p == 'inhale'
            ? 'TARIK · 4'
            : p == 'hold'
                ? 'TAHAN · 7'
                : 'BUANG · 8';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: active ? within.clamp(0.0, 1.0) : 0,
                    minHeight: 5,
                    backgroundColor: kGreenMed.withOpacity(0.18),
                    color: kGreenMed,
                  ),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: active ? kGreenDark : kInkLight,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'inhale':
        return 'Tarik';
      case 'hold':
        return 'Tahan';
      default:
        return 'Buang';
    }
  }

  String _phaseInstruction(String phase) {
    switch (phase) {
      case 'inhale':
        return 'Tarik napas perlahan lewat hidung';
      case 'hold':
        return 'Tahan dengan tenang';
      default:
        return 'Hembuskan pelan lewat mulut';
    }
  }

  // ── State 3: "Sesi selesai" — dirancang ulang ─────────────────────
  Widget _buildDonePrompt() {
    final durationSec = DateTime.now().difference(_startTime).inSeconds;
    final mm = (durationSec ~/ 60).toString();
    final ss = (durationSec % 60).toString().padLeft(2, '0');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 24),
            child: Column(
              children: [
                const Spacer(),
                // Orb sukses dengan cincin perayaan + check (scale-in)
                BmFadeIn(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final d in const [220.0, 178.0])
                          Container(
                            width: d,
                            height: d,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: kGreenLight.withOpacity(0.35),
                                  width: 1.5),
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                center: Alignment(-0.3, -0.35),
                                colors: [Colors.white, kGreenLight, kGreenMed],
                                stops: [0.0, 0.55, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kGreenMed.withOpacity(0.4),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                BmFadeIn(
                  delay: const Duration(milliseconds: 120),
                  child: const Text(
                    'Sesi selesai',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: kInkDark,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                BmFadeIn(
                  delay: const Duration(milliseconds: 160),
                  child: const Text(
                    'Kamu menuntaskan 3 siklus napas 4-7-8.\nSatu foto lagi untuk melihat perubahan mood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: kInkMed, height: 1.6),
                  ),
                ),
                const SizedBox(height: 28),
                // Strip statistik
                BmFadeIn(
                  delay: const Duration(milliseconds: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kHairline),
                    ),
                    child: Row(
                      children: [
                        _doneStat('3', 'siklus'),
                        _statDivider(),
                        _doneStat('$mm:$ss', 'durasi'),
                        _statDivider(),
                        _doneStat('4-7-8', 'pola'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                BmPrimaryButton(
                  label: 'Ambil Foto Akhir',
                  icon: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 20),
                  onTap: _openCamera,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: kGreenDark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: kInkLight)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 32, color: kHairline);
  }

  // ── State 4: Foto akhir (kamera) ──────────────────────────────────
  Widget _buildPostPhoto() {
    if (_cameraService.controller == null || !_cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: kGreenLight)),
      );
    }
    // Fill light selalu aktif: layar putih penuh + viewfinder berbingkai
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(
            children: [
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
              _postPhotoViewfinder(),
              const SizedBox(height: 20),
              const Spacer(),
              _postPhotoShutter(onTap: _capturePostPhoto),
              const SizedBox(height: 8),
            ],
            ),
          ),
        ),
      ),
    );
  }

  // Viewfinder dengan corner ticks + oval panduan wajah, selaras dengan
  // pengambilan foto pertama di Check-in.
  Widget _postPhotoViewfinder() {
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
              child: FittedBox(
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
            child: IgnorePointer(
                child: CustomPaint(painter: _PostPhotoCornerTicks())),
          ),
        ],
      ),
    );
  }

  Widget _postPhotoShutter({VoidCallback? onTap}) {
    return BmPressable(
      scale: 0.92,
      onTap: onTap,
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: kGreenLight.withOpacity(0.5), width: 2),
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

  // ── State 5: Hasil sesi (dirancang ulang) ─────────────────────────
  Widget _buildResult() {
    final before = _moodBefore?.score ?? 50;
    final after = _moodAfter?.score ?? before;
    final delta = (after - before).round();
    final label = _combiner.getRelaxLabel(_relaxScore);
    final improved = _relaxScore > 0 || delta > 0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const Text('HASIL SESI',
                    style: TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 11,
                        letterSpacing: 2.0,
                        color: kInkLight)),
                const SizedBox(height: 10),
                BmFadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: Text(
                    improved ? 'Kamu lebih\ntenang sekarang' : 'Sesi tercatat',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: kInkDark,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                // Hero: relaxation score
                BmFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _relaxHero(label),
                ),
                const SizedBox(height: 16),
                // Before / After
                BmFadeIn(
                  delay: const Duration(milliseconds: 170),
                  child: _beforeAfterCard(before, after, delta),
                ),
                const Spacer(),
                BmPrimaryButton(
                  label: _saving ? 'Menyimpan…' : 'Simpan & Selesai',
                  icon: _saving
                      ? null
                      : const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20),
                  onTap: _saving ? null : _saveAndFinish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Kartu hero relaxation score: angka besar + sparkline + label
  Widget _relaxHero(String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kHairline),
        boxShadow: [
          BoxShadow(
            color: kRelax.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RELAXATION SCORE',
                    style: TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 9,
                        color: kRelax,
                        letterSpacing: 1.6)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('+${_relaxScore.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontFamily: 'DMmono',
                            fontSize: 54,
                            fontWeight: FontWeight.w500,
                            color: kRelax,
                            height: 1,
                            letterSpacing: -2)),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('%',
                          style: TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 18,
                              color: kInkMed)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BmChip(
                  label: label,
                  color: kRelax,
                  bg: kRelax.withOpacity(0.12),
                  showDot: false,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 56,
            child: CustomPaint(painter: _SparklinePainter()),
          ),
        ],
      ),
    );
  }

  // Kartu before/after dengan badge delta
  Widget _beforeAfterCard(double before, double after, int delta) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kGreenPale,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _beforeAfterCol('SEBELUM',
                moodEmoji(_moodBefore?.label ?? 'netral'), before, _moodDesc(before)),
          ),
          // Badge delta di tengah
          Column(
            children: [
              const Icon(Icons.arrow_forward_rounded, color: kGreenMed, size: 20),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreenMed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${delta >= 0 ? '+' : ''}$delta',
                    style: const TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
          Expanded(
            child: _beforeAfterCol(
                'SESUDAH',
                moodEmoji(_moodAfter?.label ?? _moodBefore?.label ?? 'netral'),
                after,
                _moodDesc(after)),
          ),
        ],
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
        const SizedBox(height: 6),
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 2),
        Text(score.toStringAsFixed(0),
            style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: kGreenDark,
                height: 1.1)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 10, color: kInkMed)),
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

// Sudut viewfinder (4 siku-siku) untuk foto akhir — selaras dgn Check-in
class _PostPhotoCornerTicks extends CustomPainter {
  const _PostPhotoCornerTicks();
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
  bool shouldRepaint(_PostPhotoCornerTicks oldDelegate) => false;
}

// Cincin glow konsentris di belakang orb — mengembang mengikuti napas
class _OrbGlowPainter extends CustomPainter {
  final double v; // 0.7..1.05 dari orbController
  final String phase;
  _OrbGlowPainter(this.v, this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // normalisasi 0..1 dari rentang controller
    final t = ((v - 0.7) / 0.35).clamp(0.0, 1.0);
    const baseR = 95.0;
    for (int i = 0; i < 4; i++) {
      final radius = baseR + i * 18 + t * 24;
      final opacity = (0.16 - i * 0.035) * (0.5 + t * 0.5);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = kGreenLight.withOpacity(opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbGlowPainter oldDelegate) =>
      oldDelegate.v != v || oldDelegate.phase != phase;
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
