import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../design/components/components.dart';
import '../design/icons.dart';
import '../design/layout.dart';
import '../design/motion.dart';
import '../design/semantic.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'map_consent.dart';
import 'map_consent_sheet.dart';
import 'map_key.dart';

class MapPrivacyPage extends StatefulWidget {
  const MapPrivacyPage({
    super.key,
    required this.consent,
    required this.providerName,
    this.keys,
    this.binding = const MapBinding(),
  });
  final MapConsentController consent;
  final String providerName;
  final MapKeyController? keys;
  final MapBinding binding;

  @override
  State<MapPrivacyPage> createState() => _MapPrivacyPageState();
}

class _MapPrivacyPageState extends State<MapPrivacyPage> {
  /// Folded chevron points down (0.25), expanded points up (0.75); 180° apart
  /// (Spec §6.5).
  static const _chevronFolded = .25;
  static const _chevronExpanded = .75;

  final _input = TextEditingController();
  bool _editing = false;
  bool _visible = false;
  bool _helpExpanded = false;
  bool _privacyDetailsExpanded = false;
  String? _error;
  String? _notice;
  Map<String, String>? _identity;
  bool _bindingBusy = false;
  bool _bindingFailed = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(MapKeyController keys) async {
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await keys.save(_input.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _editing = false;
        _visible = false;
        _input.clear();
        _notice = keys.restartRequired
            ? '已保存。请结束 App 进程后重新打开，本次运行仍使用原 Key。'
            : 'Key 已保存在本机。打开详情地图后可查看加载结果。';
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Key 保存失败，请重试；原配置仍保留');
    }
  }

  Future<void> _clear(MapKeyController keys) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除地图 Key？'),
        content: const Text('清除后立即使用路线速写。你可以随时重新填写 Key。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除 Key'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await keys.clear();
      if (!mounted) return;
      setState(() {
        _input.clear();
        _editing = false;
        _visible = false;
        _error = null;
        _notice = keys.restartRequired
            ? '已清除，地图已切换为路线速写。请重新启动 App，以结束已加载的地图 SDK。'
            : 'Key 已清除，地图使用路线速写。';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '清除失败，请重试；原配置仍保留');
    }
  }

  Future<void> _readBinding() async {
    if (_bindingBusy) return;
    setState(() {
      _bindingBusy = true;
      _bindingFailed = false;
    });
    try {
      final identity = await widget.binding.read();
      if (mounted) setState(() => _identity = identity);
    } catch (_) {
      if (mounted) setState(() => _bindingFailed = true);
    } finally {
      if (mounted) setState(() => _bindingBusy = false);
    }
  }

  Future<void> _copy(String text, String label) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label已复制')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('复制失败，请重试或手动选择文字')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys ?? MapKeyScope.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([keys, widget.consent]),
      builder: (context, _) => PopScope(
        canPop: !(keys?.busy ?? false),
        child: Scaffold(
          appBar: mileafPageBar(context, title: const Text('地图')),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: MileafContent(
                padding: MileafLayout.pagePadding(
                  context,
                  top: MileafSpace.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (keys != null) ...[
                      _eyebrow(context, '本机配置'),
                      const SizedBox(height: MileafSpace.s8),
                      ..._configuration(context, keys),
                      const SizedBox(height: MileafSpace.section),
                    ],
                    _eyebrow(context, '申请帮助'),
                    const SizedBox(height: MileafSpace.s8),
                    _help(context),
                    const SizedBox(height: MileafSpace.section),
                    _eyebrow(context, '地图隐私'),
                    const SizedBox(height: MileafSpace.s8),
                    ..._privacy(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Group label above each of the three blocks; the AppBar keeps the only
  /// 18px title on this page (ADR 0010 D1).
  Widget _eyebrow(BuildContext context, String text) =>
      Semantics(header: true, child: Text(text, style: context.type.label));

  /// 16px chevron driven by this page: `ExpansionTile` only rotates its own
  /// built-in caret, never a supplied `trailing` (Spec §0).
  Widget _chevron(BuildContext context, bool expanded) => AnimatedRotation(
    turns: expanded ? _chevronExpanded : _chevronFolded,
    duration: MileafLayout.motion(context, MileafDurations.chevron),
    curve: MileafCurves.enter,
    child: MileafIcon(
      MileafIconName.chevron,
      size: MileafIconMetrics.inline,
      color: context.colors.textFaint,
    ),
  );

  /// Both disclosure blocks share one borderless, hairline-only tile; the
  /// page owns the expand state so the chevron can rotate.
  Widget _fold(
    BuildContext context, {
    required String title,
    required bool expanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    final type = context.type;
    final colors = context.colors;
    return ExpansionTile(
      expansionAnimationStyle: const AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      ),
      title: Text(
        title,
        style: type.body.copyWith(
          color: colors.text,
          fontWeight: MileafType.weightSemiBold,
        ),
      ),
      trailing: _chevron(context, expanded),
      onExpansionChanged: onExpansionChanged,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  List<Widget> _configuration(BuildContext context, MapKeyController keys) {
    final saved = keys.savedKey;
    return [
      _statusLine(context, keys),
      const SizedBox(height: MileafSpace.s16),
      ..._keyBlock(context, keys),
      if (saved != null) ...[
        const SizedBox(height: MileafSpace.s12),
        MileafDataRow(
          title: '清除已保存的 Key',
          destructive: true,
          bottomLine: true,
          enabled: !keys.busy,
          onTap: () => _clear(keys),
        ),
      ],
      ..._messages(context, saved),
    ];
  }

  /// Conclusion first: state icon, frozen status wording, one scope line.
  Widget _statusLine(BuildContext context, MapKeyController keys) {
    final type = context.type;
    final colors = context.colors;
    final statusColor = keys.readFailed
        ? colors.error
        : keys.restartRequired
        ? colors.warning
        : colors.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MileafIcon(MileafIconName.mapPin, color: colors.accent),
        const SizedBox(width: MileafSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  keys.status,
                  style: type.body.copyWith(
                    color: statusColor,
                    fontWeight: MileafType.weightSemiBold,
                  ),
                ),
              ),
              if (!keys.readFailed) ...[
                const SizedBox(height: MileafSpace.s4),
                Text(
                  keys.restartRequired ? '本次运行仍用原 Key' : '保存在本机 · 所有车辆与站点共用',
                  style: type.micro.copyWith(
                    color: keys.restartRequired
                        ? colors.warning
                        : colors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _keyBlock(BuildContext context, MapKeyController keys) {
    final type = context.type;
    final colors = context.colors;
    final saved = keys.savedKey;
    if (keys.readFailed) {
      return [
        MileafDataRow(
          title: '重试读取配置',
          showChevron: true,
          bottomLine: true,
          enabled: !keys.busy,
          onTap: keys.restore,
        ),
      ];
    }
    if (!keys.loaded) return const [MileafProgressLine()];
    return [
      if (keys.busy) const MileafProgressLine(),
      if (saved != null && !_editing)
        MileafDataRow(
          title: '${widget.binding.platformLabel} 地图 Key',
          // 脱敏末四位；比整段掩码更短，200% 字号下不撑破行尾。
          badge: Text(
            '•••• ${saved.substring(saved.length > 4 ? saved.length - 4 : 0)}',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          showChevron: true,
          bottomLine: true,
          enabled: !keys.busy,
          onTap: () => setState(() {
            _editing = true;
            _error = null;
            _notice = null;
          }),
        )
      else
        _keyForm(context, keys),
    ];
  }

  Widget _keyForm(BuildContext context, MapKeyController keys) {
    final type = context.type;
    final saved = keys.savedKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _input,
          enabled: !keys.busy,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          style: type.body,
          decoration: InputDecoration(
            labelText: '${widget.binding.platformLabel} 地图 Key',
            hintText: '粘贴高德平台 SDK Key',
            errorText: _error,
            errorMaxLines: 4,
            suffixIcon: TextButton(
              onPressed: keys.busy
                  ? null
                  : () => setState(() => _visible = !_visible),
              child: Text(_visible ? '隐藏' : '显示'),
            ),
          ),
        ),
        const SizedBox(height: MileafSpace.s12),
        FilledButton(
          onPressed: keys.busy ? null : () => _save(keys),
          child: Text(keys.busy ? '正在保存…' : '保存 Key'),
        ),
        if (saved != null) ...[
          const SizedBox(height: MileafSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: keys.busy
                  ? null
                  : () => setState(() {
                      _editing = false;
                      _input.clear();
                      _error = null;
                      _visible = false;
                    }),
              child: const Text('取消更换'),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _messages(BuildContext context, String? saved) {
    final type = context.type;
    final colors = context.colors;
    return [
      if (_error != null && saved != null && !_editing) ...[
        const SizedBox(height: MileafSpace.s8),
        Semantics(
          liveRegion: true,
          child: Text(_error!, style: type.body.copyWith(color: colors.error)),
        ),
      ],
      if (_notice != null) ...[
        const SizedBox(height: MileafSpace.s8),
        Semantics(liveRegion: true, child: Text(_notice!, style: type.body)),
      ],
    ];
  }

  Widget _help(BuildContext context) {
    final type = context.type;
    final colors = context.colors;
    return _fold(
      context,
      title: '如何申请 Key',
      expanded: _helpExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _helpExpanded = expanded);
        if (expanded && _identity == null) _readBinding();
      },
      children: [
        const _StepRow(number: '1', text: '登录高德开放平台，创建应用并添加 Key。'),
        const SizedBox(height: MileafSpace.s8),
        _StepRow(
          number: '2',
          text:
              '选择「${widget.binding.platformLabel} 平台 SDK」，'
              '按下列信息绑定当前安装包。',
        ),
        const SizedBox(height: MileafSpace.s8),
        const _StepRow(number: '3', text: '将申请的 Key 粘贴到上方并保存。'),
        const SizedBox(height: MileafSpace.s12),
        if (_bindingBusy) const MileafProgressLine(),
        if (_bindingFailed)
          InlineBanner(
            tone: BannerTone.error,
            message: '安装包绑定信息读取失败',
            actionLabel: '重试读取绑定信息',
            onAction: _readBinding,
          ),
        for (final entry
            in _identity?.entries ?? const <MapEntry<String, String>>[])
          MileafCopyRow(
            label: entry.key,
            value: entry.value,
            onCopy: (text) => _copy(text, entry.key),
          ),
        const SizedBox(height: MileafSpace.s12),
        Text(
          '按当前安装包信息申请；重签名或更换渠道后需重新核对',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
        MileafCopyRow(
          label: '高德控制台链接',
          value: 'console.amap.com/dev/key/app',
          copyText: 'https://console.amap.com/dev/key/app',
          onCopy: (text) => _copy(text, '高德控制台链接'),
        ),
      ],
    );
  }

  List<Widget> _privacy(BuildContext context) {
    final type = context.type;
    final colors = context.colors;
    final granted = widget.consent.isGrantedFor(widget.providerName);
    final policy = mapPrivacyUrl(widget.providerName);
    return [
      MileafDataRow(
        title: '底图授权',
        meta: granted ? '当前已允许加载底图' : '当前未允许加载底图',
        bottomLine: true,
      ),
      MileafDataRow(
        title: granted ? '关闭底图' : '重新启用地图',
        showChevron: true,
        bottomLine: true,
        onTap: () async {
          if (granted) {
            await widget.consent.revoke(widget.providerName);
          } else if (mounted) {
            await showMapConsentSheet(
              context,
              widget.consent,
              providerName: widget.providerName,
            );
          }
        },
      ),
      _fold(
        context,
        title: '数据使用说明',
        expanded: _privacyDetailsExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _privacyDetailsExpanded = expanded),
        children: [
          Text(
            '底图由${widget.providerName}提供：加载时会向其处理 IP、设备/网络信息和当前地图范围。'
            '行笺不向地图发送站点凭据，也不申请手机定位权限。',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s12),
          Text(
            '关闭后，新打开的地图使用路线速写。'
            '已加载的地图 SDK 内存状态可能持续到进程结束。',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          if (policy.isNotEmpty)
            MileafCopyRow(
              label: '隐私政策链接',
              value: policy,
              onCopy: (text) => _copy(text, '隐私政策链接'),
            ),
        ],
      ),
    ];
  }
}

/// Numbered help step: 20px number column, 8px gap, wrapping copy.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: MileafSpace.s20,
        child: Text(
          number,
          style: context.type.label.copyWith(color: context.colors.textFaint),
        ),
      ),
      const SizedBox(width: MileafSpace.s8),
      Expanded(child: Text(text, style: context.type.body)),
    ],
  );
}
