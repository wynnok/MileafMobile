import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icon_button.dart';

/// Hairline key/value row with a 44×44 copy action.
///
/// Used for technical values that must stay selectable: package name, signing
/// SHA-1, Bundle ID and the console / privacy-policy links. Transparent
/// background, a single 1px `line` at the bottom, no shadow (ADR 0010 D2).
///
/// The caller owns the clipboard write and its feedback: [onCopy] receives
/// [copyText] (or [value]), so the page keeps one `_copy` helper for the
/// successful and failing SnackBar wording, and a row can show a short domain
/// while copying the full URL.
class MileafCopyRow extends StatelessWidget {
  const MileafCopyRow({
    super.key,
    required this.label,
    required this.value,
    this.copyText,
    this.onCopy,
    this.enabled = true,
  });

  final String label;
  final String value;

  /// Clipboard payload; defaults to [value].
  final String? copyText;

  /// Receives [copyText] (or [value]) when the copy button is pressed.
  final ValueChanged<String>? onCopy;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final copy = onCopy;
    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: type.subheadline.copyWith(color: colors.textMuted)),
        const SizedBox(height: MileafSpace.s4),
        SelectableText(value, style: type.body.copyWith(color: colors.text)),
      ],
    );
    final action = MileafIconButton(
      icon: MileafIconName.copy,
      tooltip: '复制$label',
      onPressed: enabled && copy != null ? () => copy(copyText ?? value) : null,
    );
    // Large text stacks the button under the value, matching MileafDataRow.
    final body = MileafLayout.largeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              labelBlock,
              const SizedBox(height: MileafSpace.s8),
              action,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: labelBlock),
              const SizedBox(width: MileafSpace.s12),
              action,
            ],
          );
    return Container(
      constraints: const BoxConstraints(minHeight: MileafSpace.rowMin),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      // 卡内用法：容器左缘即文字起始线（由调用方对齐到卡片内边距），
      // 底部细线横贯整个容器，于是从文字起始处画到卡片右缘（R24）；
      // 这里的右内边距只作用于文字，不影响细线终点。
      padding: const EdgeInsets.only(
        right: MileafSpace.cardPad,
        top: MileafSpace.s12,
        bottom: MileafSpace.s12,
      ),
      alignment: Alignment.centerLeft,
      child: body,
    );
  }
}
