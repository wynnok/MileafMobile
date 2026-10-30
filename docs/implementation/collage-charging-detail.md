# C「数据拼贴」充电详情（#13）

2026-10-30。本地实现，以 GitHub #13 的 C05 增量、Spec #1 2026-10-30 章节、ADR 0001 和原型 C chargeDetail 为依据；原 A 图册仅保留历史意义。

详情顺序为地点 → 深色 SOC 电池弧 → 入电/费用/时长结果 → 实际功率/电量曲线 → 两侧能量 → 过程数据说明、账目、环境和更多信息。复用 `collage.dart` 湖畔颜色；SOC 弧只绘制两端均已知的区间，缺失不补零；文本端点随系统字号排版。地点契约仅有地名/地址/围栏，未新增坐标或合成正式地图。加热状态和原始过程口径默认折叠，可展开核查。

未改请求、契约、能力声明、缓存、币种、车辆归属或后端；power/soc、扩展采样、按时间/电量切换和点读继续复用。两侧能量分别记录，不相加、不推导损耗率。大字结果自动换行，不限制 tile 高度。

## 验证

- 已确认测试边界：App 操作＋可控 HTTP。新增布局回归先失败：原 SOC 标题在 y=730，入电结果在 y=124；实施后通过，并保留 360×800 默认实际功率图完整可见检查。
- `tool/flutterw test --no-pub test/collage_charging_detail_test.dart test/charging_detail_test.dart test/charging_expansion_test.dart`：25 项通过。覆盖两入口、局部失败/重试、null/0/单点/多点、币种、404、归属/切车、条件缓存304、扩展能力与原始过程质量。折叠后的原测试增加真实展开操作。
- `tool/flutterw analyze --no-pub`：No issues found。
- `git diff --check`：通过。
- 可选渲染 `test/collage_charging_detail_render_test.dart`：1 项通过，生成24张 PNG，覆盖正常/空序列/缺失详情 × 浅深色 × 100%/200% × 首屏/曲线。全部截图前检查 Flutter 异常为空；目视检查正常浅色、深色大字、缺失浅色和空序列深色，未见横向溢出、标签重叠或伪造全零趋势。

运行均从此工作树，使用原项目 `.tooling/flutter`（`MILEAF_FLUTTER_SDK`）及当前工作树本地缓存；未安装全局工具或改配置。

```sh
MILEAF_FLUTTER_SDK=/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile/.tooling/flutter tool/flutterw test --no-pub test/collage_charging_detail_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/charging-detail '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Hiragino Sans GB.ttc'
```

图册：[`collage-renders/charging-detail/`](collage-renders/charging-detail/)。`empty` 指详情存在但序列为空；`missing` 指 SOC、能量、费用和时长未知，独立成功曲线仍可读。

## 待验与边界

本票未做双端构建（交由 #17 集成）、真机手势/读屏、真实站点/地图/Grafana 或性能外部验收；用户视觉验收保留待验。不推送、不部署、不关闭 issue。不修改原工作区已有脏文档及外部符号链接仓库。
