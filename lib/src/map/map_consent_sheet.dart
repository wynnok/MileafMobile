import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_consent.dart';

const amapPrivacyUrl = 'https://lbs.amap.com/pages/privacy/';
const applePrivacyUrl = 'https://www.apple.com/legal/privacy/';

String mapPrivacyUrl(String providerName) =>
    providerName.contains('高德') ? amapPrivacyUrl : applePrivacyUrl;

Future<void> showMapConsentSheet(
  BuildContext context,
  MapConsentController consent, {
  required String providerName,
}) async {
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _MapConsentSheet(providerName: providerName),
  );
  if (granted == true) await consent.grant(providerName);
}

class _MapConsentSheet extends StatelessWidget {
  const _MapConsentSheet({required this.providerName});
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('地图由$providerName提供', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            '加载地图后，$providerName会处理 IP、设备/网络信息和当前地图范围，用于显示底图。'
            '行笺不会向地图发送站点凭据，也不会读取手机定位。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            providerName.contains('高德') ? '高德隐私政策' : 'Apple 地图隐私',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          SelectableText(
            mapPrivacyUrl(providerName),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('暂不'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('允许加载'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
