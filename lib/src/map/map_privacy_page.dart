import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../design/components/components.dart';
import '../design/icons.dart';
import '../design/layout.dart';
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
                      // 分组标题保持读屏 header 语义（原 _eyebrow 行为）。
                      Semantics(
                        header: true,
                        child: const MileafGroupHeader(title: '本机配置'),
                      ),
                      const SizedBox(height: MileafSpace.s8),
                      MileafGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _configuration(context, keys),
                        ),
                      ),
                      const SizedBox(height: MileafSpace.section),
                    ],
                    Semantics(
                      header: true,
                      child: const MileafGroupHeader(title: '申请帮助'),
                    ),
                    const SizedBox(height: MileafSpace.s8),
                    MileafGroupCard(child: _help(context)),
                    const SizedBox(height: MileafSpace.section),
                    Semantics(
                      header: true,
                      child: const MileafGroupHeader(title: '地图隐私'),
                    ),
                    const SizedBox(height: MileafSpace.s8),
                    MileafGroupCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _privacy(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
        MileafGroupRow(
          title: '清除已保存的 Key',
          destructive: true,
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
                  style: type.footnote.copyWith(
                    color: keys.restartRequired
                        ? colors.warning
                        : colors.textSecondary,
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
    final saved = keys.savedKey;
    if (keys.readFailed) {
      return [
        MileafGroupRow(
          title: '重试读取配置',
          trailing: _chevron(context),
          enabled: !keys.busy,
          onTap: keys.restore,
        ),
      ];
    }
    if (!keys.loaded) return const [MileafProgressLine()];
    return [
      if (keys.busy) const MileafProgressLine(),
      if (saved != null && !_editing)
        _savedKeyRow(context, keys, saved)
      else
        _keyForm(context, keys),
    ];
  }

  /// 已保存折叠态的 Key 摘要行；大字时掩码移到标题下第二行
  /// （同设置页 D-AP07-05 的大字重排处理）。
  Widget _savedKeyRow(
    BuildContext context,
    MapKeyController keys,
    String saved,
  ) {
    final stacked = MileafLayout.largeText(context);
    final masked =
        '•••• ${saved.substring(saved.length > 4 ? saved.length - 4 : 0)}';
    return MileafGroupRow(
      title: '${widget.binding.platformLabel} 地图 Key',
      value: stacked ? null : masked,
      meta: stacked ? masked : null,
      trailing: _chevron(context),
      enabled: !keys.busy,
      onTap: () => setState(() {
        _editing = true;
        _error = null;
        _notice = null;
      }),
    );
  }

  Widget _chevron(BuildContext context) => MileafIcon(
    MileafIconName.chevron,
    size: MileafIconMetrics.nav,
    color: context.colors.textFaint,
  );

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
        // R27：处理中保留文字，尾部活动指示器由 loading 承载。
        MileafButton(
          label: '保存 Key',
          expand: true,
          loading: keys.busy,
          onPressed: keys.busy ? null : () => _save(keys),
        ),
        if (saved != null) ...[
          const SizedBox(height: MileafSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: MileafButton(
              label: '取消更换',
              kind: MileafButtonKind.ghost,
              onPressed: keys.busy
                  ? null
                  : () => setState(() {
                      _editing = false;
                      _input.clear();
                      _error = null;
                      _visible = false;
                    }),
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
    return MileafDisclosure(
      label: '如何申请 Key',
      expanded: _helpExpanded,
      onExpandedChanged: (expanded) {
        setState(() => _helpExpanded = expanded);
        if (expanded && _identity == null) _readBinding();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            style: type.footnote.copyWith(color: colors.textSecondary),
          ),
          MileafCopyRow(
            label: '高德控制台链接',
            value: 'console.amap.com/dev/key/app',
            copyText: 'https://console.amap.com/dev/key/app',
            onCopy: (text) => _copy(text, '高德控制台链接'),
          ),
        ],
      ),
    );
  }

  List<Widget> _privacy(BuildContext context) {
    final type = context.type;
    final colors = context.colors;
    final granted = widget.consent.isGrantedFor(widget.providerName);
    final policy = mapPrivacyUrl(widget.providerName);
    return [
      MileafGroupRow(
        title: '底图授权',
        meta: granted ? '当前已允许加载底图' : '当前未允许加载底图',
        bottomLine: true,
      ),
      MileafGroupRow(
        title: granted ? '关闭底图' : '重新启用地图',
        trailing: _chevron(context),
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
      MileafDisclosure(
        label: '数据使用说明',
        expanded: _privacyDetailsExpanded,
        onExpandedChanged: (expanded) =>
            setState(() => _privacyDetailsExpanded = expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '底图由${widget.providerName}提供：加载时会向其处理 IP、设备/网络信息和当前地图范围。'
              '行笺不向地图发送站点凭据，也不申请手机定位权限。',
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: MileafSpace.s12),
            Text(
              '关闭后，新打开的地图使用路线速写。'
              '已加载的地图 SDK 内存状态可能持续到进程结束。',
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            if (policy.isNotEmpty)
              MileafCopyRow(
                label: '隐私政策链接',
                value: policy,
                onCopy: (text) => _copy(text, '隐私政策链接'),
              ),
          ],
        ),
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
          style: context.type.subheadline.copyWith(
            color: context.colors.textFaint,
          ),
        ),
      ),
      const SizedBox(width: MileafSpace.s8),
      Expanded(child: Text(text, style: context.type.body)),
    ],
  );
}
