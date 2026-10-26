import 'package:flutter/material.dart';

import 'app_theme.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppTheme.muted))],
          ])),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 78, height: 78, decoration: const BoxDecoration(color: AppTheme.greenLight, shape: BoxShape.circle), child: Icon(icon, size: 34, color: AppTheme.green)),
            const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.5, color: AppTheme.muted)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.onTap});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6ECE7))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 13), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppTheme.ink)),
            const SizedBox(height: 3), Text(title, style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'جارٍ تحميل البيانات...'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(label, style: const TextStyle(color: AppTheme.muted))]));
}

String formatQuantity(num value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
