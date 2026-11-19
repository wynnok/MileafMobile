# 行程焦点卡卡头重排图证

2026-11-18 由 `test/period_header_render_test.dart` 导出，字体为 Inter + 系统 CJK 回退（`/System/Library/Fonts/Supplemental/Arial Unicode.ttf`），夹具 `test/fixtures/driving-stats.json`，时区 `Asia/Shanghai`，参照时刻 `2026-11-18T12:00Z`（近 30 天 = 10月20日–11月18日，13 字）。机位 DPR 1，截图按 `pixelRatio: 2` 导出（PNG 为逻辑尺寸的 2 倍）。全部为改动**后**的实际渲染。

| 文件 | 机位 | 用途 |
| --- | --- | --- |
| `header-360x800-100-light.png` | 行程 · 浅色 · 360 · 100% | 用户截屏机位：期间名与区间同一行，区间右端与卡片内容右沿同线 |
| `header-360x800-100-dark.png` | 行程 · 深色 · 360 · 100% | 深色同构 |
| `header-390x844-150-light.png` | 行程 · 浅色 · 390 · 150% | 区间整段落到期间名下一行、同左缘 |
| `header-320x568-200-light.png` | 行程 · 浅色 · 320 · 200% | 整段区间也放不下：只在 DF3 连接号后断行 |

说明、判定与验证命令见 [实施记录](../period-header.md)。真机字体、读屏与性能不在本图册范围（#16/#17）。
