// lib/screens/home_screen.dart
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

class _HomeScreenState extends State<HomeScreen> {
  SessionModel? _lastSession; // null = belum ada sesi (empty state)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLastSession();
  }

  // Ambil sesi terakhir dari database
  Future<void> _loadLastSession() async {
    final session = await DatabaseHelper.instance.getLastSession();
    if (!mounted) return;
    setState(() {
      _lastSession = session;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgMain,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kGreenMed))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, kPadV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppBar(),
          const SizedBox(height: 24),
          _buildGreeting(),
          const SizedBox(height: 24),
          const BmSectionHeader('KONDISI TERAKHIR'),
          _lastSession == null ? _buildEmptyCard() : _buildLastSessionCard(),
          const SizedBox(height: 24),
          const BmSectionHeader('MULAI SESI'),
          BmPrimaryButton(
            label: 'Mulai Check-in',
            onTap: () => Navigator.pushNamed(context, '/checkin')
                .then((_) => _loadLastSession()), // refresh setelah kembali
            icon:
                const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          // Empty state → "Pelajari Dulu"; sudah ada sesi → "Lihat Riwayat"
          BmOutlineButton(
            label: _lastSession == null ? 'Pelajari Dulu' : 'Lihat Riwayat',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          const Spacer(),
          if (_lastSession != null)
            _buildMiniStats()
          else
            _buildPrivacyNote(),
        ],
      ),
    );
  }

  // Catatan privasi di empty state (dari wireframe)
  Widget _buildPrivacyNote() {
    return const Center(
      child: Text(
        'foto tidak disimpan · proses on-device',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 11,
          color: kInkLight,
        ),
      ),
    );
  }

  // AppBar: nama app di tengah, ikon jam di kanan
  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 40),
        const Text(
          'BreathMark',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kInkDark,
            letterSpacing: -0.2,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/history'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kInkDark.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: kInkDark, size: 18),
          ),
        ),
      ],
    );
  }

  // Greeting berubah sesuai waktu hari (atau sambutan untuk pengguna baru)
  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final sapa = hour < 12
        ? 'Selamat pagi,'
        : hour < 17
            ? 'Selamat siang,'
            : 'Selamat malam,';
    final isEmpty = _lastSession == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEmpty ? 'Halo, selamat datang' : sapa,
          style: const TextStyle(fontSize: 13, color: kInkLight),
        ),
        const SizedBox(height: 4),
        Text(
          isEmpty ? 'Mulai check-in pertamamu' : 'Apa kabar hari ini?',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: kInkDark,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  // Label relatif tanggal: HARI INI / KEMARIN / tanggal (uppercase)
  String _relativeDay(String dateStr) {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr =
        today.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (dateStr == todayStr) return 'HARI INI';
    if (dateStr == yesterdayStr) return 'KEMARIN';
    return dateStr;
  }

  // Kartu sesi terakhir — tampil kalau ada data
  Widget _buildLastSessionCard() {
    final s = _lastSession!;
    final color = stressColor(s.stressLevel);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kGreenPale,
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _relativeDay(s.date),
                    style: const TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 11,
                      color: kGreenDark,
                      letterSpacing: 1.0,
                    ),
                  ),
                  BmChip(
                    label: s.moodLabel,
                    color: color,
                    bg: color.withOpacity(0.12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.moodBefore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                      color: kGreenDark,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/100',
                      style: TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 18,
                        color: kInkMed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.relaxScore != null
                    ? 'mood score · skor naik ${s.relaxScore!.toStringAsFixed(0)}%'
                    : 'mood score · sesi terakhir',
                style: const TextStyle(fontSize: 13, color: kInkMed),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  BmChip(
                    label: '${moodEmoji(s.moodLabel)}  ${s.moodLabel}',
                    color: kGreenDark,
                    bg: Colors.white.withOpacity(0.7),
                    showDot: false,
                  ),
                  if (s.relaxScore != null)
                    BmChip(
                      label: '4-7-8 · 3 siklus',
                      color: kGreenDark,
                      bg: Colors.white.withOpacity(0.7),
                      showDot: false,
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: kGreenLight.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // Empty state — belum ada sesi
  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kGreenLight),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration:
                const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child: const Icon(Icons.eco_outlined, color: kGreenMed, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada sesi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kInkDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mulai check-in pertamamu — hanya butuh 3 menit untuk merasa lebih baik.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: kInkMed, height: 1.6),
          ),
        ],
      ),
    );
  }

  // 3 statistik kecil di bagian bawah
  Widget _buildMiniStats() {
    return BmMiniStatRow(stats: const [
      {'value': '7', 'label': 'sesi'},
      {'value': '+12', 'label': 'mood'},
      {'value': '83%', 'label': 'efektif'},
    ]);
  }
}
