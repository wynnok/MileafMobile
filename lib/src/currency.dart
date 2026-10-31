import 'package:flutter/material.dart';

import 'number_format.dart';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CurrencyPreferenceStore {
  Future<String?> read(String site);
  Future<void> write(String site, String? code);
}

class PreferenceCurrencyStore implements CurrencyPreferenceStore {
  late final _store = SharedPreferencesAsync();
  @override
  Future<String?> read(String site) => _store.getString('currency:$site');
  @override
  Future<void> write(String site, String? code) async {
    if (code == null) {
      await _store.remove('currency:$site');
    } else {
      await _store.setString('currency:$site', code);
    }
  }
}

/// Site-scoped display preference only. Never converts the server's numbers.
class CurrencySettings extends ChangeNotifier {
  CurrencySettings(this.site, this.store);
  final String site;
  final CurrencyPreferenceStore store;
  String? code;
  bool _disposed = false;
  int _revision = 0;
  Future<void> restore() async {
    final revision = _revision;
    final saved = await store.read(site);
    if (_disposed || revision != _revision) return;
    code = saved;
    notifyListeners();
  }

  Future<void> select(String? value) async {
    _revision++;
    await store.write(site, value);
    if (_disposed) return;
    code = value;
    notifyListeners();
  }

  /// Symbol used by the C prototypes for the common currencies; other codes
  /// stay as ISO suffixes so nothing is invented for unknown currencies.
  static const _symbols = {'CNY': '¥'};

  /// Display unit for labels that put the currency after a value.
  String get symbol => _symbols[code] ?? code ?? '币种未知';

  String amount(num? value) => value == null
      ? '—（缺失）'
      : switch (code) {
          final c? when _symbols[c] != null =>
            '${_symbols[c]}${decimal(value)}',
          final c? => '${decimal(value)} $c',
          null => '${decimal(value)}（币种未知）',
        };
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String decimal(num value) =>
    groupedText(value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''));

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key, required this.settings});
  final CurrencySettings settings;
  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  bool saving = false;
  String? error;
  Future<void> select(String? code) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.settings.select(code);
    } catch (_) {
      if (mounted) setState(() => error = '币种偏好保存失败，请重试');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('站点币种')),
    body: ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('后端没有币种信息。此设置仅添加币种代码标签，不换汇、不改变费用数字。请确保站点所有记录使用同一币种。'),
          const Text('仅保存当前连接的普通偏好，不修改数据库。'),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          if (saving) const LinearProgressIndicator(),
          for (final code in <String?>[
            null,
            'CNY',
            'USD',
            'EUR',
            'GBP',
            'JPY',
            'HKD',
            'TWD',
            'AUD',
            'CAD',
            'CHF',
            'SGD',
            'KRW',
          ])
            ListTile(
              title: Text(code ?? '未配置（币种未知）'),
              selected: widget.settings.code == code,
              trailing: widget.settings.code == code
                  ? const Icon(Icons.check)
                  : null,
              onTap: saving ? null : () => select(code),
            ),
        ],
      ),
    ),
  );
}
