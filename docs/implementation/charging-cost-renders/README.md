# 充电费用补录 · 正式 Flutter 图册

2026-11-04；依据 [ADR 0007](../../adr/0007-missing-charging-cost-entry.md)、[Spec](../../specs/missing-charging-cost-entry.md)与[CET05](../../specs/missing-charging-cost-entry-tickets.md)。这是本功能小图册，沿用外观v2，不替代整套页面图册，不删除历史证据。

正式页面通过可控HTTP和合成记录渲染：60个主机位，52个滚动到动作区的补图，共112张PNG；以2×像素比输出。表中尺寸为逻辑像素。图片状态在测试内先断言再保存，不把缺失状态替换为已有费用样本。

## 复现

```sh
./tool/flutterw test --no-pub test/charging_cost_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/charging-cost-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

使用项目Inter Regular/Medium/SemiBold资源和系统Arial Unicode作为测试CJK fallback；未安装字体或依赖。真机平台字体回退和键盘仍须外部复验。键盘图以280逻辑像素viewInsets模拟遮挡，空白区域不代表真实系统键盘外观。

未设置MILEAF_RENDER_OUTPUT时，图册测试跳过；同文件的320宽200%输入/公开语义/键盘遮挡/减少动效检查始终运行。

## 索引

| 尺寸 | 状态 | 浅100% | 深100% | 浅200% | 深200% |
| --- | --- | --- | --- | --- | --- |
| 360×800 | 列表入口 | [主机位](360-list-light-100.png) | [主机位](360-list-dark-100.png) | [主机位](360-list-light-200.png) | [主机位](360-list-dark-200.png) |
| 360×800 | 详情入口 | [主机位](360-detail-light-100.png) | [主机位](360-detail-dark-100.png) | [主机位](360-detail-light-200.png) | [主机位](360-detail-dark-200.png) |
| 360×800 | 空输入 | [主机位](360-empty-light-100.png) · [操作区](360-empty-light-100-action.png) | [主机位](360-empty-dark-100.png) · [操作区](360-empty-dark-100-action.png) | [主机位](360-empty-light-200.png) · [操作区](360-empty-light-200-action.png) | [主机位](360-empty-dark-200.png) · [操作区](360-empty-dark-200-action.png) |
| 360×800 | 合法预估 | [主机位](360-preview-light-100.png) · [操作区](360-preview-light-100-action.png) | [主机位](360-preview-dark-100.png) · [操作区](360-preview-dark-100-action.png) | [主机位](360-preview-light-200.png) · [操作区](360-preview-light-200-action.png) | [主机位](360-preview-dark-200.png) · [操作区](360-preview-dark-200-action.png) |
| 360×800 | 明确免费 | [主机位](360-free-light-100.png) · [操作区](360-free-light-100-action.png) | [主机位](360-free-dark-100.png) · [操作区](360-free-dark-100-action.png) | [主机位](360-free-light-200.png) · [操作区](360-free-light-200-action.png) | [主机位](360-free-dark-200.png) · [操作区](360-free-dark-200-action.png) |
| 360×800 | 单价校验 | [主机位](360-invalid-light-100.png) · [操作区](360-invalid-light-100-action.png) | [主机位](360-invalid-dark-100.png) · [操作区](360-invalid-dark-100-action.png) | [主机位](360-invalid-light-200.png) · [操作区](360-invalid-light-200-action.png) | [主机位](360-invalid-dark-200.png) · [操作区](360-invalid-dark-200-action.png) |
| 360×800 | 站点未开启 | [主机位](360-blocked-light-100.png) · [操作区](360-blocked-light-100-action.png) | [主机位](360-blocked-dark-100.png) · [操作区](360-blocked-dark-100-action.png) | [主机位](360-blocked-light-200.png) · [操作区](360-blocked-light-200-action.png) | [主机位](360-blocked-dark-200.png) · [操作区](360-blocked-dark-200-action.png) |
| 360×800 | 结果待确认 | [主机位](360-uncertain-light-100.png) · [操作区](360-uncertain-light-100-action.png) | [主机位](360-uncertain-dark-100.png) · [操作区](360-uncertain-dark-100-action.png) | [主机位](360-uncertain-light-200.png) · [操作区](360-uncertain-light-200-action.png) | [主机位](360-uncertain-dark-200.png) · [操作区](360-uncertain-dark-200-action.png) |
| 320×640 | 长地点 | [主机位](320-long-light-100.png) · [操作区](320-long-light-100-action.png) | [主机位](320-long-dark-100.png) · [操作区](320-long-dark-100-action.png) | [主机位](320-long-light-200.png) · [操作区](320-long-light-200-action.png) | [主机位](320-long-dark-200.png) · [操作区](320-long-dark-200-action.png) |
| 320×640 | 未知币种 | [主机位](320-unknown-light-100.png) · [操作区](320-unknown-light-100-action.png) | [主机位](320-unknown-dark-100.png) · [操作区](320-unknown-dark-100-action.png) | [主机位](320-unknown-light-200.png) · [操作区](320-unknown-light-200-action.png) | [主机位](320-unknown-dark-200.png) · [操作区](320-unknown-dark-200-action.png) |
| 320×640 | 最大金额 | [主机位](320-maximum-light-100.png) · [操作区](320-maximum-light-100-action.png) | [主机位](320-maximum-dark-100.png) · [操作区](320-maximum-dark-100-action.png) | [主机位](320-maximum-light-200.png) · [操作区](320-maximum-light-200-action.png) | [主机位](320-maximum-dark-200.png) · [操作区](320-maximum-dark-200-action.png) |
| 320×640 | 键盘遮挡 | [主机位](320-keyboard-light-100.png) · [操作区](320-keyboard-light-100-action.png) | [主机位](320-keyboard-dark-100.png) · [操作区](320-keyboard-dark-100-action.png) | [主机位](320-keyboard-light-200.png) · [操作区](320-keyboard-light-200-action.png) | [主机位](320-keyboard-dark-200.png) · [操作区](320-keyboard-dark-200-action.png) |
| 390×844 | 标准预估 | [主机位](390-preview-light-100.png) · [操作区](390-preview-light-100-action.png) | [主机位](390-preview-dark-100.png) · [操作区](390-preview-dark-100-action.png) | [主机位](390-preview-light-200.png) · [操作区](390-preview-light-200-action.png) | [主机位](390-preview-dark-200.png) · [操作区](390-preview-dark-200-action.png) |
| 390×844 | 键盘遮挡 | [主机位](390-keyboard-light-100.png) · [操作区](390-keyboard-light-100-action.png) | [主机位](390-keyboard-dark-100.png) · [操作区](390-keyboard-dark-100-action.png) | [主机位](390-keyboard-light-200.png) · [操作区](390-keyboard-light-200-action.png) | [主机位](390-keyboard-dark-200.png) · [操作区](390-keyboard-dark-200-action.png) |
| 768×1024 | 平板居中 | [主机位](768-preview-light-100.png) · [操作区](768-preview-light-100-action.png) | [主机位](768-preview-dark-100.png) · [操作区](768-preview-dark-100-action.png) | [主机位](768-preview-light-200.png) · [操作区](768-preview-light-200-action.png) | [主机位](768-preview-dark-200.png) · [操作区](768-preview-dark-200-action.png) |

## 视觉复核与限制

已在本会话抽查浅色预估、深色最大金额、大字键盘操作区和双入口；主数/后果说明/错误及按钮可经滚动访问，最大金额在千位分组边界换行。底部弹层不增加新的深色hero，不引入额外卡片或强调色。最终消费级视觉结论仍由用户结合图册复核，不以测试通过替代。

矩阵曾发现原有充电曲线采样按钮在320宽200%溢出，已改为Wrap；共享sheet外壳增加heightFactor=1，消除内容自适应弹层上方的多余空白。费用入口局部约束ghost宽度，保持低强调与就近阅读，未全局重做按钮样式。

本图册不验证真实站点写入、PostgreSQL授权、多实例缓存、真机键盘/字体/TalkBack/VoiceOver、真实地图、性能或原生双端构建。
