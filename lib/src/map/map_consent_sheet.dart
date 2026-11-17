import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/components/components.dart';
import '../design/icons.dart';
import '../design/semantic.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'map_consent.dart';

const amapPrivacyUrl = 'https://lbs.amap.com/pages/privacy/';

String mapPrivacyUrl(String providerName) =>
    providerName.contains('高德') ? amapPrivacyUrl : '';

const _declineLabel = '暂不';

Future<void> showMapConsentSheet(
  BuildContext context,
  MapConsentController consent, {
  required String providerName,
}) async {
  final granted = await showMileafSheet<bool>(
    context: context,
    // 标题行文案冻结（CP12 地图隐私与底图授权）。
    title: '地图由$providerName提供',
    // R28：地图同意属高内容弹层，用贴边样式（顶部 28、不透明）。
    style: MileafSheetStyle.edge,
    // R28：地图同意属高内容弹层，用贴边样式。
    builder: (sheetContext) => _MapConsentSheet(
      providerName: providerName,
      declineLabel: _declineLabel,
    ),
  );
  if (granted == true) await consent.grant(providerName);
}

class _MapConsentSheet extends StatelessWidget {
  const _MapConsentSheet({
    required this.providerName,
    required this.declineLabel,
  });
  final String providerName;
  final String declineLabel;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final colors = context.colors;
    final policyUrl = mapPrivacyUrl(providerName);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // CP12 冻结文案逐字保留；MileafSheetFrame 已提供 headline 标题行，
          // 这里是标题行之后的说明正文。
          '加载地图后，$providerName会处理 IP、设备/网络信息和当前地图范围，用于显示底图。'
          '行笺不会向地图发送站点凭据，也不会读取手机定位。',
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        if (policyUrl.isNotEmpty) ...[
          const SizedBox(height: MileafSpace.s12),
          Text(
            '高德隐私政策',
            style: type.subheadline.copyWith(color: colors.accentStrong),
          ),
          const SizedBox(height: MileafSpace.s4),
          SelectableText(
            policyUrl,
            style: type.footnote.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: MileafSpace.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: MileafButton(
              label: '复制链接',
              kind: MileafButtonKind.ghost,
              icon: MileafIconName.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: policyUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('隐私政策链接已复制')));
                }
              },
            ),
          ),
        ],
        const SizedBox(height: MileafSpace.s16),
        Row(
          children: [
            Expanded(
              child: MileafButton(
                label: declineLabel,
                kind: MileafButtonKind.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: MileafSpace.s12),
            Expanded(
              child: MileafButton(
                label: '允许加载',
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
