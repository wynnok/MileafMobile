import 'package:flutter/material.dart';

import 'appearance.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

Future<void> showAppearanceSheet(
  BuildContext context,
  AppearanceController controller,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: false,
  builder: (_) => _AppearanceSheet(controller: controller),
);

class _AppearanceSheet extends StatefulWidget {
  const _AppearanceSheet({required this.controller});
  final AppearanceController controller;
  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  String? error;

  Future<void> select(MileafAppearance mode) async {
    try {
      await widget.controller.select(mode);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = '外观偏好保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => Padding(
          padding: EdgeInsets.fromLTRB(
            MileafLayout.pageInset(context),
            MileafSpace.s12,
            MileafLayout.pageInset(context),
            MileafSpace.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: MileafRadius.fullAll,
                  ),
                ),
              ),
              const SizedBox(height: MileafSpace.s20),
              Text('外观', style: type.title),
              const SizedBox(height: MileafSpace.s4),
              Text(
                '默认跟随系统。切换后立即生效，并保存在本机。',
                style: type.micro,
              ),
              const SizedBox(height: MileafSpace.s12),
              for (final mode in MileafAppearance.values)
                _AppearanceRow(
                  mode: mode,
                  selected: widget.controller.mode == mode,
                  onTap: () => select(mode),
                ),
              if (error != null) ...[
                const SizedBox(height: MileafSpace.s8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: type.body.copyWith(color: colors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final MileafAppearance mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      label: mode.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: MileafRadius.smAll,
        highlightColor: colors.accent.withValues(alpha: .12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MileafSpace.rowMin),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  mode.label,
                  style: type.body.copyWith(
                    color: selected ? colors.accentStrong : colors.text,
                    fontWeight: selected
                        ? MileafType.weightSemiBold
                        : MileafType.weightRegular,
                  ),
                ),
              ),
              if (selected)
                MileafIcon(
                  MileafIconName.check,
                  size: MileafIconMetrics.nav,
                  color: colors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
