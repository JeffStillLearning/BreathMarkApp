// lib/widgets/bm_widgets.dart
// Komponen reusable yang dipakai di lebih dari 1 screen
import 'package:flutter/material.dart';
import '../constants.dart';

// ── 0a. BmPressable ─────────────────────────────────────────────────
// Membungkus child agar mengecil halus (scale 0.96) saat ditekan, lalu
// kembali saat dilepas — press feedback ala native. Hormati reduced-motion.
class BmPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const BmPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<BmPressable> createState() => _BmPressableState();
}

class _BmPressableState extends State<BmPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = (_down && !reduce) ? widget.scale : 1.0;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── 0b. BmFadeIn ────────────────────────────────────────────────────
// Entrance: fade + slide-up 16px, dengan [delay] untuk efek stagger.
// Otomatis nonaktif saat reduced-motion (langsung tampil).
class BmFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;

  const BmFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 16,
  });

  @override
  State<BmFadeIn> createState() => _BmFadeInState();
}

class _BmFadeInState extends State<BmFadeIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return widget.child;
    return AnimatedSlide(
      offset: _shown ? Offset.zero : Offset(0, widget.offsetY / 100),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── 1. BmChip ───────────────────────────────────────────────────────
// Pill label kecil dengan dot warna — dipakai di semua screen hasil
class BmChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final bool showDot;

  const BmChip({
    super.key,
    required this.label,
    this.color = kGreenMed,
    this.bg = kGreenPale,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. BmPrimaryButton ──────────────────────────────────────────────
// Tombol hijau penuh lebar — tombol aksi utama
class BmPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;

  const BmPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreenMed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          shadowColor: kGreenMed.withOpacity(0.28),
        ).copyWith(
          elevation: WidgetStateProperty.all(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
            if (icon != null) ...[const SizedBox(width: 8), icon!],
          ],
        ),
      ),
    );
  }
}

// ── 3. BmOutlineButton ──────────────────────────────────────────────
// Tombol outline hijau — tombol aksi sekunder
class BmOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const BmOutlineButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreenMed,
          side: const BorderSide(color: kGreenMed, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

// ── 4. BmSectionHeader ──────────────────────────────────────────────
// Label section kecil uppercase dengan garis bawah hijau pucat
class BmSectionHeader extends StatelessWidget {
  final String text;

  const BmSectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kGreenPale, width: 1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'DMmono',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: kInkLight,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ── 5. BmScoreCard ──────────────────────────────────────────────────
// Kartu angka skor besar — dipakai di Check-in dan Breathing result
class BmScoreCard extends StatelessWidget {
  final String label;
  final double score;
  final String unit;
  final String statusLabel;
  final Color statusColor;

  const BmScoreCard({
    super.key,
    required this.label,
    required this.score,
    required this.unit,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kGreenPale,
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'DMmono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kInkLight,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: const TextStyle(
                  fontFamily: 'DMmono',
                  fontSize: 56,
                  fontWeight: FontWeight.w500,
                  color: kGreenDark,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'DMmono',
                    fontSize: 18,
                    color: kInkMed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BmChip(
            label: statusLabel,
            color: statusColor,
            bg: statusColor.withOpacity(0.12),
            showDot: true,
          ),
        ],
      ),
    );
  }
}

// ── 6. BmMiniStatRow ────────────────────────────────────────────────
// Baris 3 statistik kecil — dipakai di Home Screen bawah
class BmMiniStatRow extends StatelessWidget {
  final List<Map<String, String>> stats; // [{value, label}, ...]

  const BmMiniStatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: s == stats.first ? 0 : 5,
                  right: s == stats.last ? 0 : 5,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kHairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['value']!,
                      style: const TextStyle(
                        fontFamily: 'DMmono',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: kGreenDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s['label']!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: kInkLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
