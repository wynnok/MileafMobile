import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_consent.dart';
import 'map_consent_sheet.dart';

class MapPrivacyPage extends StatelessWidget {
  const MapPrivacyPage({
    super.key,
    required this.consent,
    required this.providerName,
  });
  final MapConsentController consent;
  final String providerName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('地图与隐私')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '底图供应商：$providerName',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          '地图仅在详情页加载。加载后会向供应商处理 IP、设备/网络信息和当前地图范围。'
          '行笺不向地图发送站点凭据，也不申请手机定位权限。',
        ),
        const SizedBox(height: 12),
        Text(providerName.contains('高德') ? '高德隐私政策' : 'Apple 地图隐私'),
        SelectableText(
          mapPrivacyUrl(providerName),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: mapPrivacyUrl(providerName)),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('隐私政策链接已复制')));
            }
          },
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('复制链接'),
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: consent,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                consent.isGrantedFor(providerName) ? '当前已允许加载底图' : '当前未允许加载底图',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (consent.isGrantedFor(providerName))
                OutlinedButton(
                  onPressed: () async {
                    await consent.revoke(providerName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已关闭底图；下次启动完全停止地图 SDK')),
                      );
                    }
                  },
                  child: const Text('关闭底图'),
                )
              else
                FilledButton(
                  onPressed: () => showMapConsentSheet(
                    context,
                    consent,
                    providerName: providerName,
                  ),
                  child: const Text('重新启用地图'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '关闭后，新打开的地图不再创建原生视图；已加载的供应商 SDK 内存状态可能持续到进程结束。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
