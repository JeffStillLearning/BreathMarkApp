// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../database/database_helper.dart';
import '../models/session_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionModel> _all = [];
  bool _loading = true;
  String _tab = 'week'; // 'week' | 'month'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await DatabaseHelper.instance.getAllSessions();
    if (!mounted) return;
    setState(() {
      _all = sessions;
      _loading = false;
    });
  }

  // Filter sesi sesuai tab aktif
  List<SessionModel> get _filtered {
    final now = DateTime.now();
    return _all.where((s) {
      final d = DateTime.tryParse(s.date);
      if (d == null) return false;
      if (_tab == 'week') {
        return now.difference(d).inDays < 7;
      } else {
        return d.year == now.year && d.month == now.month;
      }
    }).toList();
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
      padding: const EdgeInsets.fromLTRB(kPadH, 16, kPadH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _appBar(),
          const SizedBox(height: 16),
          _tabSelector(),
          const SizedBox(height: 16),
          if (_all.isEmpty)
            Expanded(child: _emptyState())
          else
            Expanded(
              child: ListView(
                children: [
                  _buildTrendChart(),
                  const SizedBox(height: 20),
                  const BmSectionHeader('DISTRIBUSI STRES'),
                  _buildStressDistribution(),
                  const SizedBox(height: 20),
                  const BmSectionHeader('SESI TERBARU'),
                  ..._filtered.map(_sessionTile),
                  if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Belum ada sesi pada periode ini.',
                            style:
                                TextStyle(fontSize: 13, color: kInkLight)),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _appBar() {
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
        const SizedBox(width: 8),
        const Text(
          'Riwayat Sesi',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kInkDark,
          ),
        ),
      ],
    );
  }

  // Segmented tab: Minggu Ini / Bulan Ini
  Widget _tabSelector() {
    Widget tab(String key, String label) {
      final active = key == _tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? kBgCard : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: kInkDark.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? kInkDark : kInkLight,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kInkDark.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab('week', 'Minggu Ini'),
          tab('month', 'Bulan Ini'),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.bar_chart_outlined, color: kInkLight, size: 56),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat sesi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kInkDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Selesaikan sesi pertamamu untuk melihat tren di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: kInkMed),
          ),
        ],
      ),
    );
  }

  // Grafik tren mood dengan header rata-rata + delta
  Widget _buildTrendChart() {
    final ordered = _filtered.reversed.toList(); // kronologis
    final scores = ordered.map((s) => s.moodBefore).toList();
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    // Delta sederhana: bandingkan sesi pertama vs terakhir
    double delta = 0;
    if (scores.length >= 2 && scores.first != 0) {
      delta = (scores.last - scores.first) / scores.first * 100;
    }
    final rangeLabel = _tab == 'week' ? 'MINGGU INI' : _monthLabel();

    final spots = <FlSpot>[
      for (int i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i]),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 8),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MOOD · RATA-RATA',
                      style: TextStyle(
                          fontFamily: 'DMmono',
                          fontSize: 9,
                          color: kInkLight,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(avg.toStringAsFixed(0),
                          style: const TextStyle(
                              fontFamily: 'DMmono',
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: kGreenDark,
                              height: 1)),
                      const SizedBox(width: 6),
                      if (scores.length >= 2)
                        Text(
                          '${delta >= 0 ? '↑' : '↓'} ${delta.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 10,
                              color: delta >= 0 ? kGreenMed : kStressHigh),
                        ),
                    ],
                  ),
                ],
              ),
              Text(rangeLabel,
                  style: const TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 9,
                      color: kInkLight,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: scores.length < 2
                ? const Center(
                    child: Text('Butuh ≥ 2 sesi untuk grafik tren.',
                        style: TextStyle(fontSize: 12, color: kInkLight)),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: kHairline, strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(
                        topTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              interval: 25,
                              reservedSize: 28),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          color: kGreenMed,
                          barWidth: 2.5,
                          isCurved: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                kGreenLight.withOpacity(0.4),
                                kGreenLight.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _monthLabel() {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
      'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildStressDistribution() {
    int low = 0, mod = 0, high = 0;
    for (final s in _filtered) {
      switch (s.stressLevel) {
        case 'low':
          low++;
          break;
        case 'moderate':
          mod++;
          break;
        case 'high':
          high++;
          break;
      }
    }
    final maxVal = [low, mod, high, 1].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar('Low', low, maxVal, kStressLow),
          _bar('Mod', mod, maxVal, kStressMed),
          _bar('High', high, maxVal, kStressHigh),
        ],
      ),
    );
  }

  Widget _bar(String label, int count, int maxVal, Color color) {
    final ratio = maxVal == 0 ? 0.0 : count / maxVal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: TextStyle(
                fontFamily: 'DMmono',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color)),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 8 + (ratio * 80),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: kInkMed)),
      ],
    );
  }

  String _relativeDay(String dateStr) {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    if (dateStr == todayStr) return 'Hari ini';
    if (dateStr == yesterdayStr) return 'Kemarin';
    return dateStr;
  }

  Widget _sessionTile(SessionModel s) {
    final color = stressColor(s.stressLevel);
    final after = s.moodAfter;
    final relax = s.relaxScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: kGreenPale,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(moodEmoji(s.moodLabel),
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _relativeDay(s.date),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kInkDark),
                ),
                const SizedBox(height: 2),
                Text(
                  after != null
                      ? 'Mood ${s.moodBefore.toStringAsFixed(0)}→${after.toStringAsFixed(0)} · Stres ${s.stressLevel}'
                      : 'Mood ${s.moodBefore.toStringAsFixed(0)} · Stres ${s.stressLevel}',
                  style: const TextStyle(fontSize: 12, color: kInkMed),
                ),
              ],
            ),
          ),
          if (relax != null)
            Text(
              '+${relax.toStringAsFixed(0)}%',
              style: TextStyle(
                fontFamily: 'DMmono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
