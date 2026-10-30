import 'package:flutter/material.dart';

/// C surfaces share lake colours. Data and chart semantics stay with callers.
enum CollageSurface { paper, hero, mint, sand }

class CollageTile extends StatelessWidget {
  const CollageTile({
    super.key,
    required this.child,
    this.surface = CollageSurface.paper,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final CollageSurface surface;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (surface) {
      CollageSurface.hero =>
        dark ? const Color(0xFF06140F) : const Color(0xFF0B2A20),
      CollageSurface.mint =>
        dark ? const Color(0xFF1E3B2C) : const Color(0xFFD4F0DC),
      CollageSurface.sand =>
        dark ? const Color(0xFF3B3120) : const Color(0xFFF2E2C6),
      CollageSurface.paper =>
        dark ? const Color(0xFF12231A) : const Color(0xFFFBFDF9),
    };
    final theme = Theme.of(context);
    final heroScheme = theme.colorScheme.copyWith(
      onSurface: const Color(0xFFEEF7EF),
      onSurfaceVariant: const Color(0xFFB8D6C3),
      primary: const Color(0xFF8AD6AF),
    );
    return Theme(
      data: surface == CollageSurface.hero
          ? theme.copyWith(
              colorScheme: heroScheme,
              textTheme: theme.textTheme.apply(
                bodyColor: heroScheme.onSurface,
                displayColor: heroScheme.onSurface,
              ),
              iconTheme: IconThemeData(color: heroScheme.primary),
            )
          : theme,
      child: Card(
        color: color,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A dominant result beside quieter evidence; large text always stacks.
class CollageBento extends StatelessWidget {
  const CollageBento({super.key, required this.lead, required this.evidence});
  final Widget lead;
  final List<Widget> evidence;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) >= 21
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [lead, ...evidence],
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: lead),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: evidence,
              ),
            ),
          ],
        );
}
