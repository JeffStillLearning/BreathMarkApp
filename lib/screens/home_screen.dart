// lib/screens/home_screen.dart
// Home dirancang ulang dari nol: hero "breathing orb" sebagai CTA utama,
// latar gradient berlapis, gauge arc untuk skor sesi terakhir.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../database/database_helper.dart';
import '../models/session_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  SessionModel? _lastSession;
  List<SessionModel> _sessions = [];
  bool _loading = true;

  // Denyut halus untuk hero orb (napas pelan, 4 detik per siklus)
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadLastSession();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadLastSession() async {
    final sessions = await DatabaseHelper.instance.getAllSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _lastSession = sessions.isNotEmpty ? sessions.first : null;
      _loading = false;
    });
  }

  // ── Statistik nyata dari riwayat sesi ─────────────────────────────
  int get _totalSessions => _sessions.length;

  // Rata-rata perubahan mood (mood_after - mood_before) dari sesi yang selesai
  double get _avgMoodDelta {
    final done = _sessions.where((s) => s.moodAfter != null).toList();
    if (done.isEmpty) return 0;
    final sum =
        done.map((s) => s.moodAfter! - s.moodBefore).reduce((a, b) => a + b);
    return sum / done.length;
  }

  // Rata-rata relax score dari sesi yang punya hasil pernapasan
  double get _avgRelaxScore {
    final done = _sessions.where((s) => s.relaxScore != null).toList();
    if (done.isEmpty) return 0;
    final sum = done.map((s) => s.relaxScore!).reduce((a, b) => a + b);
    return sum / done.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Latar gradient berlapis + blob organik (bukan warna flat)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgMain, Color(0xFFEFF3EA), Color(0xFFE7F0E5)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Blob dekoratif lembut di pojok atas
            Positioned(
              top: -120,
              right: -90,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kGreenLight.withOpacity(0.22),
                      kGreenLight.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kGreenMed))
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final hasSession = _lastSession != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 28),
          BmFadeIn(delay: const Duration(milliseconds: 40), child: _greeting()),
          const Spacer(flex: 2),
          // HERO — orb CTA di tengah (satu primary action)
          BmFadeIn(
            delay: const Duration(milliseconds: 120),
            child: Center(child: _heroOrb()),
          ),
          const Spacer(flex: 2),
          // Modul kondisi terakhir / empty
          BmFadeIn(
            delay: const Duration(milliseconds: 200),
            child: hasSession ? _lastSessionStrip() : _emptyHint(),
          ),
          const SizedBox(height: 16),
          if (hasSession)
            BmFadeIn(
              delay: const Duration(milliseconds: 260),
              child: _statPills(),
            ),
        ],
      ),
    );
  }

  // ── Header: tanggal + wordmark + tombol riwayat ───────────────────
  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _todayLabel(),
              style: const TextStyle(
                fontFamily: 'DMmono',
                fontSize: 10.5,
                color: kInkLight,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: kGreenMed, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'BreathMark',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInkDark,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        BmPressable(
          onTap: () => Navigator.pushNamed(context, '/history'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: kHairline),
            ),
            child: const Icon(Icons.history_rounded,
                color: kInkDark, size: 20),
          ),
        ),
      ],
    );
  }

  // ── Greeting editorial (campuran berat font) ──────────────────────
  Widget _greeting() {
    final hour = DateTime.now().hour;
    final sapa = hour < 12
        ? 'Selamat pagi'
        : hour < 17
            ? 'Selamat siang'
            : 'Selamat malam';
    final isEmpty = _lastSession == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEmpty ? 'Halo,' : '$sapa,',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: kInkMed,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        Text(
          isEmpty ? 'mari mulai.' : 'apa kabar hari ini?',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: kInkDark,
            letterSpacing: -1.0,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  // ── HERO: orb napas sebagai tombol mulai ──────────────────────────
  Widget _heroOrb() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return BmPressable(
      scale: 0.97,
      onTap: () => Navigator.pushNamed(context, '/checkin')
          .then((_) => _loadLastSession()),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = reduce ? 0.5 : _pulse.value; // 0..1
              final scale = 1.0 + 0.05 * math.sin(t * math.pi);
              return CustomPaint(
                painter: _OrbRingsPainter(progress: t),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 188,
              height: 188,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Color(0xFFFFFFFF), kGreenLight, kGreenMed],
                  stops: [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kGreenMed.withOpacity(0.35),
                    blurRadius: 60,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.air_rounded, color: Colors.white, size: 30),
                  SizedBox(height: 6),
                  Text(
                    'Mulai',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'check-in',
                    style: TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 10.5,
                      color: Color(0xFFE7F0E5),
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _lastSession == null
                ? 'Tap orb · hanya ~3 menit'
                : 'Tap orb untuk sesi baru',
            style: const TextStyle(fontSize: 12.5, color: kInkLight),
          ),
        ],
      ),
    );
  }

  // ── Strip kondisi terakhir: gauge arc + ringkasan ─────────────────
  Widget _lastSessionStrip() {
    final s = _lastSession!;
    final color = stressColor(s.stressLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kHairline),
        boxShadow: [
          BoxShadow(
            color: kGreenDark.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gauge arc melingkar dengan skor di tengah, animasi mengisi saat muncul
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: s.moodBefore / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _ScoreGaugePainter(value),
                  child: Center(
                    child: Text(
                      (value * 100).toStringAsFixed(0),
                      style: const TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kGreenDark,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _relativeDay(s.date),
                      style: const TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 10,
                        color: kInkLight,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BmChip(
                      label: '${moodEmoji(s.moodLabel)} ${s.moodLabel}',
                      color: color,
                      bg: color.withOpacity(0.12),
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.relaxScore != null
                      ? 'Mood terakhir · relax +${s.relaxScore!.toStringAsFixed(0)}%'
                      : 'Mood terakhir',
                  style: const TextStyle(fontSize: 13, color: kInkMed),
                ),
                if (s.relaxScore != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '4-7-8 · 3 siklus selesai',
                    style: TextStyle(fontSize: 11.5, color: kInkLight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty hint (belum ada sesi) ───────────────────────────────────
  Widget _emptyHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child: const Icon(Icons.spa_outlined, color: kGreenMed, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Belum ada sesi. Foto wajah, ukur stres, lalu bernapas.',
              style: TextStyle(fontSize: 12.5, color: kInkMed, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Strip 3 statistik tipis ───────────────────────────────────────
  Widget _statPills() {
    Widget pill(num targetValue, String suffix, String label,
        {bool showSign = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kHairline),
          ),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: targetValue.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final rounded = value.round();
                  final sign = showSign && rounded > 0 ? '+' : '';
                  return Text(
                    '$sign$rounded$suffix',
                    style: const TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: kGreenDark,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: kInkLight)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(_totalSessions, '', 'sesi'),
        pill(_avgMoodDelta, '', 'mood', showSign: true),
        pill(_avgRelaxScore, '%', 'efektif'),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _todayLabel() {
    const days = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
      'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';
  }

  String _relativeDay(String dateStr) {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    if (dateStr == todayStr) return 'HARI INI';
    if (dateStr == yesterdayStr) return 'KEMARIN';
    return dateStr;
  }
}

// Cincin konsentris di belakang hero orb (glow napas)
class _OrbRingsPainter extends CustomPainter {
  final double progress; // 0..1
  _OrbRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final spread = 18.0 + i * 22.0 + progress * 14.0;
      final opacity = (0.18 - i * 0.05) * (1 - progress * 0.4);
      final paint = Paint()
        ..color = kGreenLight.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, base + spread, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Gauge arc untuk skor mood (0..1)
class _ScoreGaugePainter extends CustomPainter {
  final double value;
  _ScoreGaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const start = math.pi * 0.75;
    const sweepMax = math.pi * 1.5;

    final track = Paint()
      ..color = kGreenPale
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, sweepMax, false, track);

    final arc = Paint()
      ..color = kGreenMed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, sweepMax * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_ScoreGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
