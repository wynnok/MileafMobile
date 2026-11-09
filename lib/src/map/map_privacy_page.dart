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
          appBar: AppBar(title: const Text('地图')),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: MileafContent(
                padding: MileafLayout.pagePadding(
                  context,
                  top: MileafSpace.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (keys != null) ..._configuration(context, keys),
                    _help(context),
                    const SizedBox(height: MileafSpace.section),
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

  List<Widget> _configuration(BuildContext context, MapKeyController keys) {
    final type = context.type;
    final colors = context.colors;
    final saved = keys.savedKey;
    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: MileafSpace.s12,
        runSpacing: MileafSpace.s8,
        children: [
          MileafIcon(MileafIconName.mapPin, color: colors.accent),
          Semantics(
            liveRegion: true,
            child: Text(
              keys.status,
              style: type.body.copyWith(
                color: keys.restartRequired ? colors.warning : colors.text,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: MileafSpace.s12),
      Text(
        '使用你自己的高德地图 Key 加载底图。配置保存在当前设备，所有车辆与站点共用。',
        style: type.body.copyWith(color: colors.textMuted),
      ),
      if (keys.restartRequired && _notice == null) ...[
        const SizedBox(height: MileafSpace.s8),
        Text(
          saved == null
              ? '已停止创建地图视图。请结束 App 进程后重新打开，以结束已加载的地图 SDK。'
              : '请结束 App 进程后重新打开。本次运行仍使用原 Key。',
          style: type.body,
        ),
      ],
      const SizedBox(height: MileafSpace.s20),
      if (keys.readFailed)
        OutlinedButton(
          onPressed: keys.busy ? null : keys.restore,
          child: const Text('重试读取配置'),
        )
      else if (!keys.loaded || keys.busy)
        const LinearProgressIndicator(),
      if (keys.loaded && !keys.readFailed) ...[
        Text(
          '${widget.binding.platformLabel} 地图 Key',
          style: type.body.copyWith(fontWeight: MileafType.weightSemiBold),
        ),
        const SizedBox(height: MileafSpace.s8),
        if (saved == null || _editing) ...[
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
          if (saved != null)
            TextButton(
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
        ] else ...[
          Text(
            '•••• •••• •••• ${saved.substring(saved.length > 4 ? saved.length - 4 : 0)}',
            style: type.body,
          ),
          const SizedBox(height: MileafSpace.s8),
          OutlinedButton(
            onPressed: keys.busy
                ? null
                : () => setState(() {
                    _editing = true;
                    _error = null;
                    _notice = null;
                  }),
            child: const Text('更换 Key'),
          ),
        ],
        if (saved != null)
          TextButton(
            onPressed: keys.busy ? null : () => _clear(keys),
            child: const Text('清除已保存的 Key'),
          ),
      ],
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
      const SizedBox(height: MileafSpace.section),
    ];
  }

  Widget _help(BuildContext context) => ExpansionTile(
    title: Text('如何申请 Key', style: context.type.body),
    onExpansionChanged: (expanded) {
      if (expanded && _identity == null) _readBinding();
    },
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. 登录高德开放平台，创建应用并添加 Key。\n2. 选择「${widget.binding.platformLabel} 平台 SDK」，按下列信息绑定当前安装包。\n3. 将申请的 Key 粘贴到上方并保存。',
              style: context.type.body,
            ),
            const SizedBox(height: MileafSpace.s12),
            if (_bindingBusy) const LinearProgressIndicator(),
            if (_bindingFailed) ...[
              Text(
                '安装包绑定信息读取失败',
                style: context.type.body.copyWith(color: context.colors.error),
              ),
              TextButton(
                onPressed: _readBinding,
                child: const Text('重试读取绑定信息'),
              ),
            ],
            for (final entry
                in _identity?.entries ?? <MapEntry<String, String>>[]) ...[
              const SizedBox(height: MileafSpace.s8),
              Text(
                entry.key,
                style: context.type.body.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              SelectableText(entry.value, style: context.type.body),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _copy(entry.value, entry.key),
                  child: Text('复制${entry.key}'),
                ),
              ),
            ],
            const SizedBox(height: MileafSpace.s8),
            Text(
              '使用当前安装包的信息申请。重新签名或更换发行渠道后，请重新核对绑定信息。',
              style: context.type.body.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            TextButton(
              onPressed: () =>
                  _copy('https://console.amap.com/dev/key/app', '高德控制台链接'),
              child: const Text('复制高德控制台链接'),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _privacy(BuildContext context) {
    final granted = widget.consent.isGrantedFor(widget.providerName);
    final policy = mapPrivacyUrl(widget.providerName);
    return [
      MileafDataRow(
        title: '地图隐私',
        meta: widget.providerName,
        icon: MileafIconName.info,
        topLine: true,
      ),
      Text(
        '加载底图会向供应商处理 IP、设备/网络信息和当前地图范围。行笺不向地图发送站点凭据，也不申请手机定位权限。',
        style: context.type.body.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: MileafSpace.s12),
      Text(granted ? '当前已允许加载底图' : '当前未允许加载底图', style: context.type.body),
      const SizedBox(height: MileafSpace.s8),
      OutlinedButton(
        onPressed: () async {
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
        child: Text(granted ? '关闭底图' : '重新启用地图'),
      ),
      const SizedBox(height: MileafSpace.s8),
      Text(
        '关闭后，新打开的地图使用路线速写。已加载的地图 SDK 内存状态可能持续到进程结束。',
        style: context.type.body.copyWith(color: context.colors.textMuted),
      ),
      if (policy.isNotEmpty) ...[
        const SizedBox(height: MileafSpace.s12),
        Text('高德隐私政策', style: context.type.body),
        SelectableText(
          policy,
          style: context.type.body.copyWith(color: context.colors.textMuted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _copy(policy, '隐私政策链接'),
            child: const Text('复制链接'),
          ),
        ),
      ],
    ];
  }
}
