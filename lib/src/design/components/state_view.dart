import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

enum StateViewKind { empty, error, loading }

/// Formal empty / error / loading presentation; never a fake all-zero chart.
///
/// R31：整页（默认）用 48 图形、`title2`、`subheadline` 说明与一个操作；
/// 模块内（[compact] true）用 24 图形与 `headline`/`footnote`，自然高度，
/// 适合放进模块卡。
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.kind,
    this.title = '',
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
    this.icon,
    this.onHero = false,
    this.compact = false,
    this.statusLine,
    this.textActionLabel,
    this.onTextAction,
    this.textActionSemanticLabel,
  });

  final StateViewKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// D-AP08-03：读屏对象名。传「重试读取概览」这类完整对象名，可见文字
  /// 仍用 [actionLabel]；不传时维持原语义（只朗读可见文字）。
  final String? actionSemanticLabel;
  final MileafIconName? icon;
  final bool onHero;

  /// 模块内状态（R31）：更小的图形与文字，自然高度。
  final bool compact;

  /// MG09 三要素之二：时间或原因行（footnote，如「数据截至 14:02」），
  /// 位于说明与动作之间；不传就不出现。
  final String? statusLine;

  /// MG09 三要素之三：文字动作槽（compact 态的下一步动作）。
  /// accentStrong 前景，命中区域不小于 44（[MileafSpace.touch]）。
  final String? textActionLabel;
  final VoidCallback? onTextAction;

  /// D-AP08-03：文字动作槽的读屏对象名。
  final String? textActionSemanticLabel;

  /// R31 整页空态的图形（图标 48）。
  static const double _pageIconSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    if (kind == StateViewKind.loading) {
      return Semantics(
        label: title.isEmpty ? '正在加载' : title,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? MileafSpace.s16 : MileafSpace.s32,
            horizontal: compact ? 0 : MileafSpace.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SkeletonBlock(width: 160, height: 14),
              SizedBox(height: MileafSpace.s12),
              SkeletonBlock(width: 220, height: 10),
              SizedBox(height: MileafSpace.s8),
              SkeletonBlock(width: 120, height: 10),
            ],
          ),
        ),
      );
    }
    // R23.3：错误状态的标题用 text，只有图形与表单校验文字用 error。
    final tone = kind == StateViewKind.error
        ? colors.error
        : onHero
        ? colors.heroMuted
        : colors.textSecondary;
    final titleColor = onHero ? colors.heroText : colors.text;
    final messageColor = onHero ? colors.heroMuted : colors.textSecondary;
    final glyph =
        icon ??
        (kind == StateViewKind.error
            ? MileafIconName.info
            : MileafIconName.route);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? MileafSpace.s16 : MileafSpace.s32,
        horizontal: compact ? 0 : MileafSpace.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MileafIcon(
            glyph,
            size: compact ? MileafIconMetrics.header : _pageIconSize,
            color: tone,
          ),
          SizedBox(height: compact ? MileafSpace.s12 : MileafSpace.s16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: (compact ? type.headline : type.title2).copyWith(
              color: titleColor,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: (compact ? type.footnote : type.subheadline).copyWith(
                color: messageColor,
              ),
            ),
          ],
          if (statusLine != null) ...[
            const SizedBox(height: MileafSpace.s4),
            Text(
              statusLine!,
              textAlign: TextAlign.center,
              style: type.footnote.copyWith(color: messageColor),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: MileafSpace.s12),
            Semantics(
              label: actionSemanticLabel,
              button: true,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
          if (onTextAction != null && textActionLabel != null) ...[
            const SizedBox(height: MileafSpace.s4),
            Semantics(
              label: textActionSemanticLabel,
              button: true,
              child: TextButton(
                onPressed: onTextAction,
                style: TextButton.styleFrom(
                  foregroundColor: colors.accentStrong,
                  minimumSize: const Size(MileafSpace.touch, MileafSpace.touch),
                ),
                child: Text(textActionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// MG09 受限色彩集合：neutral / warning / error / accent 四档，缺省 neutral。
///
/// 页面不得传任意颜色：四档与 DM01 的 [MileafStatusTone] 一一对应，取色统一
/// 转发到 `MileafStatusToneColorResolver.resolveColor`（MG02 全站唯一映射表），
/// 本枚举不再持有自己的映射。
///
/// Deprecated（仅文档标注，避免全库调用点产生诊断）：DM05–DM07 页面包接线时
/// 把参数与调用点直接改用 [MileafStatusTone]，随后删除本枚举。
enum BannerTone { neutral, warning, error, accent }

/// [BannerTone] 到 DM01 状态枚举的转发（对齐状态见实施记录 §7）。
extension BannerToneStatusForward on BannerTone {
  MileafStatusTone get statusTone => switch (this) {
        BannerTone.neutral => MileafStatusTone.neutral,
        BannerTone.warning => MileafStatusTone.warning,
        BannerTone.error => MileafStatusTone.error,
        BannerTone.accent => MileafStatusTone.accent,
      };
}

/// Inline status strip used for stale data and failed resources.
///
/// R31/M11：出现与消失用高度 200ms 与透明度 160ms；状态条在正文流里展开，
/// 不推动阅读锚点之上的内容。
///
/// MG09 三要素：现状句（[InlineBanner.message]）+ 可选时间或原因行
/// （[InlineBanner.statusLine]）+ 可选动作槽（[InlineBanner.actionLabel]）；
/// 色彩收为 [BannerTone] 受限四档。
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.neutral,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
    this.liveRegion = true,
    this.visible = true,
    this.statusLine,
  });

  final String message;
  final BannerTone tone;

  /// MG09 三要素之二：时间或原因行（footnote），正文之下；不传就不出现。
  final String? statusLine;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// D-AP08-03：动作按钮的读屏对象名（如「重试读取充电数据」）。
  final String? actionSemanticLabel;
  final bool liveRegion;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final color = tone.statusTone.resolveColor(colors);
    final content = Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line),
          bottom: BorderSide(color: colors.line),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MileafIcon(
            MileafIconName.info,
            size: MileafIconMetrics.inline,
            color: color,
          ),
          const SizedBox(width: MileafSpace.s8),
          Expanded(
            child: Semantics(
              liveRegion: liveRegion,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                  if (statusLine != null) ...[
                    const SizedBox(height: MileafSpace.s4),
                    Text(
                      statusLine!,
                      style: type.footnote.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onAction != null && actionLabel != null)
            Semantics(
              label: actionSemanticLabel,
              button: true,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
        ],
      ),
    );
    return AnimatedSize(
      duration: MileafLayout.motion(context, MileafDurations.statusHeight),
      curve: MileafCurves.fold,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: MileafLayout.motion(context, MileafDurations.statusOpacity),
        curve: MileafCurves.fade,
        opacity: visible ? 1 : 0,
        child: visible
            ? content
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

/// Static skeleton (R07/R08): a fixed shape in the skeleton tone, so first
/// load shows the module's real structure without an infinite pulse or a
/// shimmer sweep; reduce motion needed no special case because nothing moves.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = MileafRadius.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
