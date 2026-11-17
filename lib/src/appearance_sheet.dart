import 'package:flutter/material.dart';

import 'appearance.dart';
import 'design/components/components.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

Future<void> showAppearanceSheet(
  BuildContext context,
  AppearanceController controller,
) => showMileafSheet<void>(
  context: context,
  title: _title,
  // P12/R28：外观是短内容选择类弹层，用浮动样式。
  style: MileafSheetStyle.floating,
  builder: (_) => _AppearanceSheet(controller: controller),
);

const _title = '外观';

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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // P12 对照表：分组脚注，去掉「默认跟随系统」导语。
          Text('切换后立即生效，只保存在这台设备上。', style: type.footnote),
          const SizedBox(height: MileafSpace.s12),
          MileafGroupCard(
            child: MileafSelectionList<MileafAppearance>(
              options: [
                for (final mode in MileafAppearance.values)
                  MileafSelectionOption(value: mode, label: mode.label),
              ],
              value: widget.controller.mode,
              onChanged: (mode) => select(mode),
              semanticLabel: _title,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: type.footnote.copyWith(color: colors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
