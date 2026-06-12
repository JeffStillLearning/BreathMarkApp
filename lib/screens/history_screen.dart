// lib/screens/history_screen.dart
// Dirancang ulang dari nol dengan grafik yang proper:
// sumbu-X berlabel tanggal, tooltip interaktif, garis gradient + area, titik
// terakhir disorot. Logika load/filter data TIDAK diubah.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';
import '../widgets/bm_widgets.dart';
import '../database/database_helper.dart';
import '../models/session_model.dart';

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kBgMain, Color(0xFFEFF3EA), Color(0xFFE7F0E5)],
  stops: [0.0, 0.6, 1.0],
);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionModel> _all = [];
  bool _loading = true;
  String _tab = 'week';

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
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreenMed))
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadH, 8, kPadH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 18),
          if (_all.isEmpty)
            Expanded(child: _emptyState())
          else ...[
            _tabSelector(),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  BmFadeIn(
                      delay: const Duration(milliseconds: 60),
                      child: _trendCard()),
                  const SizedBox(height: 16),
                  BmFadeIn(
                      delay: const Duration(milliseconds: 120),
                      child: _stressCard()),
                  const SizedBox(height: 24),
                  const Text('SESI TERBARU',
                      style: TextStyle(
                          fontFamily: 'DMmono',
                          fontSize: 10,
                          color: kInkLight,
                          letterSpacing: 1.8)),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Belum ada sesi pada periode ini.',
                            style:
                                TextStyle(fontSize: 13, color: kInkLight)),
                      ),
                    )
                  else
                    for (int i = 0; i < _filtered.length; i++)
                      BmFadeIn(
                        delay: Duration(milliseconds: 160 + i * 40),
                        child: _sessionTile(_filtered[i]),
                      ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _header() {
    return Row(
      children: [
        BmPressable(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: kHairline),
            ),
            child:
                const Icon(Icons.arrow_back_rounded, color: kInkDark, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Riwayat',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kInkDark,
                  letterSpacing: -0.6,
                  height: 1,
                )),
            const SizedBox(height: 2),
            Text('${_all.length} sesi tercatat',
                style: const TextStyle(fontSize: 12, color: kInkLight)),
          ],
        ),
      ],
    );
  }

  // ── Tab selector ──────────────────────────────────────────────────
  Widget _tabSelector() {
    Widget tab(String key, String label) {
      final active = key == _tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: kInkDark.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? kInkDark : kInkLight,
                )),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kInkDark.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab('week', 'Minggu Ini'),
          tab('month', 'Bulan Ini'),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration:
                const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child:
                const Icon(Icons.insights_rounded, color: kGreenMed, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Belum ada riwayat',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kInkDark,
                letterSpacing: -0.4,
              )),
          const SizedBox(height: 8),
          const Text(
            'Selesaikan sesi pertamamu\ntren mood & stres akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: kInkMed, height: 1.5),
          ),
          const SizedBox(height: 24),
          BmPrimaryButton(
            label: 'Mulai Check-in',
            icon: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
            onTap: () =>
                Navigator.popUntil(context, ModalRoute.withName('/')),
          ),
        ],
      ),
    );
  }

  // ── Kartu tren mood (chart proper) ────────────────────────────────
  Widget _trendCard() {
    final ordered = _filtered.reversed.toList(); // kronologis lama→baru
    final scores = ordered.map((s) => s.moodBefore).toList();
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    double delta = 0;
    if (scores.length >= 2 && scores.first != 0) {
      delta = (scores.last - scores.first) / scores.first * 100;
    }
    final rangeLabel = _tab == 'week' ? 'MINGGU INI' : _monthLabel();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 18, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kHairline),
        boxShadow: [
          BoxShadow(
              color: kGreenDark.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
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
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(avg.toStringAsFixed(0),
                            style: const TextStyle(
                                fontFamily: 'DMmono',
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                                color: kGreenDark,
                                height: 1,
                                letterSpacing: -1)),
                        const SizedBox(width: 8),
                        if (scores.length >= 2) _deltaBadge(delta),
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
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: scores.length < 2
                ? _chartHint()
                : _moodChart(ordered, scores),
          ),
        ],
      ),
    );
  }

  Widget _deltaBadge(double delta) {
    final up = delta >= 0;
    final c = up ? kGreenMed : kStressHigh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 12, color: c),
          const SizedBox(width: 3),
          Text('${delta.abs().toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  Widget _chartHint() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Selesaikan minimal 2 sesi untuk\nmelihat grafik tren mood.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: kInkLight, height: 1.6),
        ),
      ),
    );
  }

  Widget _moodChart(List<SessionModel> ordered, List<double> scores) {
    final n = scores.length;
    final lastIndex = n - 1;
    // interval label sumbu-X agar tidak berdesakan
    final labelEvery = n <= 6 ? 1 : (n / 5).ceil();

    final spots = [
      for (int i = 0; i < n; i++) FlSpot(i.toDouble(), scores[i]),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: 100,
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: kHairline, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              reservedSize: 30,
              getTitlesWidget: (v, meta) {
                if (v != 0 && v != 50 && v != 100) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(v.toInt().toString(),
                      style: const TextStyle(
                          fontFamily: 'DMmono',
                          fontSize: 9,
                          color: kInkLight)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                if (i % labelEvery != 0 && i != lastIndex) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_shortDate(ordered[i].date),
                      style: const TextStyle(
                          fontFamily: 'DMmono',
                          fontSize: 9,
                          color: kInkLight)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => kInkDark,
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (touched) => touched.map((t) {
              final i = t.x.round().clamp(0, n - 1);
              return LineTooltipItem(
                'Mood ${t.y.toInt()}\n',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                children: [
                  TextSpan(
                    text: _shortDate(ordered[i].date),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                        fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (barData, indexes) => indexes
              .map((i) => TouchedSpotIndicatorData(
                    FlLine(color: kGreenMed.withOpacity(0.4), strokeWidth: 1),
                    FlDotData(
                      getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                        radius: 5,
                        color: kGreenDark,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ))
              .toList(),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.32,
            preventCurveOverShooting: true,
            barWidth: 3,
            gradient: const LinearGradient(
              colors: [kGreenLight, kGreenMed],
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
                radius: idx == lastIndex ? 5 : 3,
                color: idx == lastIndex ? kGreenDark : kGreenMed,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGreenLight.withOpacity(0.35),
                  kGreenLight.withOpacity(0.02),
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

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}';
  }

  // ── Distribusi stres ──────────────────────────────────────────────
  Widget _stressCard() {
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
    final total = low + mod + high;
    final maxVal = [low, mod, high, 1].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DISTRIBUSI STRES',
                  style: TextStyle(
                      fontFamily: 'DMmono',
                      fontSize: 9,
                      color: kInkLight,
                      letterSpacing: 1.4)),
              Text('$total sesi',
                  style: const TextStyle(fontSize: 11, color: kInkLight)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar('Low', low, maxVal, kStressLow),
                _bar('Moderate', mod, maxVal, kStressMed),
                _bar('High', high, maxVal, kStressHigh),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, int count, int maxVal, Color color) {
    final ratio = maxVal == 0 ? 0.0 : count / maxVal;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$count',
              style: TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              width: 44,
              height: 6 + v * 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withOpacity(0.65)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8), bottom: Radius.circular(2)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10.5, color: kInkMed)),
        ],
      ),
    );
  }

  // ── Daftar sesi ───────────────────────────────────────────────────
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
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(moodEmoji(s.moodLabel),
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_relativeDay(s.date),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kInkDark)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(s.stressLevel,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  after != null
                      ? 'Mood ${s.moodBefore.toStringAsFixed(0)} → ${after.toStringAsFixed(0)}'
                      : 'Mood ${s.moodBefore.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: kInkMed),
                ),
              ],
            ),
          ),
          if (relax != null)
            Text('+${relax.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kRelax,
                )),
        ],
      ),
    );
  }
}
