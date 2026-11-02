import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// Section title with an optional range/unit label and a text action.
///
/// No underline decoration; the gap to the content is owned by the caller.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.range,
    this.action,
    this.onHero = false,
    this.semanticLabel,
  });

  final String title;
  final String? range;
  final Widget? action;
  final bool onHero;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final titleColor = onHero ? colors.heroText : colors.text;
    final rangeColor = onHero ? colors.heroFaint : colors.textFaint;
    final titleWidget = Semantics(
      header: true,
      label: semanticLabel ?? title,
      child: Text(title, style: type.title.copyWith(color: titleColor)),
    );
    final rangeWidget = range == null
        ? null
        : Text(range!, style: type.label.copyWith(color: rangeColor));
    if (MileafLayout.largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          if (rangeWidget != null || action != null) ...[
            const SizedBox(height: MileafSpace.s4),
            Wrap(
              spacing: MileafSpace.s12,
              runSpacing: MileafSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [?rangeWidget, ?action],
            ),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleWidget),
        ?rangeWidget,
        if (action != null) ...[const SizedBox(width: MileafSpace.s8), action!],
      ],
    );
  }
}
