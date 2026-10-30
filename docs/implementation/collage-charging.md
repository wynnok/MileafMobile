# C「数据拼贴」充电账本（#12）

2026-10-30。仅调整充电列表视觉，沿用现有服务端总计、配对均价、日期筛选、结束日下钻、游标、缓存、币种和车辆隔离。

已知费用与次数覆盖组成唯一深色主 tile；补入电池和记录时长使用薄荷/沙色辅助 tile，150% 及以上字号单列。随后为每日补能图、AC/DC/未知、地点账目和最近充电。时间归期与时区移至下方数据说明。配对均价保留短提示，不改变数值或有效集。未知不补零、不并入 AC。

## 验证

- 确认的 App＋受控 HTTP seam：新增 `collage_charging_test.dart` 首次因缺少“费用覆盖”失败，再实现转绿；验证主次顺序、次数分母与首屏真实绘图区。
- `tool/flutterw test test/collage_charging_test.dart test/charging_test.dart test/charging_expansion_test.dart`：31 项通过，覆盖原分页、日期、切车、费用 null/0、均价、304 等行为。
- `tool/flutterw analyze`：无问题。
- `collage_charging_render_test.dart`：360×800、正常/空统计/缺失统计、浅深色、100%/200%，36 张正式 Flutter 渲染；每次导出检查 Flutter 异常，无 overflow。空统计图不绘制全零趋势。

图册位于 [charging/](collage-renders/charging/)，`home-` 为首屏，`evidence-` 为分类区域，`records-` 为地点/最近记录区域。图册使用受控合成 HTTP 响应，空/缺失状态重点覆盖统计摘要；地点数据沿用独立地点响应，不用列表页推导。

复现：设置 `MILEAF_FLUTTER_SDK` 指向已存在的项目 SDK，执行：

```sh
tool/flutterw test test/collage_charging_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/charging \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

未新增依赖、后端能力或修改配置。未推送或关闭工单；真机、真实站点与用户视觉验收保留待验。
