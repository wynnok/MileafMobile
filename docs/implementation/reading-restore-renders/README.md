# 阅读恢复正式渲染（#24）

> 2026-11-11 状态说明（最终集成会话补记）：本目录是 #24 的 8 张样张，字体加载仍是 #26 之前的方式（CJK 字形注册成 `Inter`）。#26 之后同机位的当前版本在 [`readability-renders/reading/`](../readability-renders/README.md)，两者 8 张全部逐字节不同、差异只在文字字形。本目录**保留为 #26 字体修订前的对照**，未删除、未覆盖（本会话不允许删除前序会话证据）。当前一代图册与并列图册的规范冲突见 `readability-renders/README.md` 的「图册归属」节。

- 日期：2026-11-11
- 分支：`main`（工作树，未提交）
- 生成入口：`test/reading_restore_render_test.dart`（opt-in；未设置 `MILEAF_RENDER_OUTPUT` 时整条测试 `skip`）
- 生成条件：360×800 逻辑像素、`devicePixelRatio = 1`、`toImage(pixelRatio: 2)` → PNG 720×1600；Inter 400/500/600 来自 `assets/fonts/`，CJK 回退为渲染机 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`
- 数据：`test/overview_statistics_reading_test.dart` 的 `readingClient`/`dayStats` 合成 HTTP（App＋可控 HTTP），**不是真实站点、不是真机截图**
- 外观：`AppearanceController` + 内存 store 强制浅/深；字号 100% / 200%

## 场景

同一入口先操作、再切到「行程」、再返回，然后截图：

- 概览：切到近7天、滚到里程图；返回后期间与滚动位置保持。
- 统计：切到近7天、滚到里程走势；返回后期间与滚动位置保持。

每页 × 浅/深 × 100/200% = 8 张。

## 生成命令

```sh
./tool/flutterw test --no-pub test/reading_restore_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/reading-restore-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
# 00:04 +1: All tests passed!（8 张；保存后立即断言无异常）
```

## 文件

| 文件 | 页面 | 外观 | 字号 |
| --- | --- | --- | --- |
| `overview-light-100.png` | 概览（返回后） | 浅 | 100% |
| `overview-light-200.png` | 概览（返回后） | 浅 | 200% |
| `overview-dark-100.png` | 概览（返回后） | 深 | 100% |
| `overview-dark-200.png` | 概览（返回后） | 深 | 200% |
| `statistics-light-100.png` | 统计（返回后） | 浅 | 100% |
| `statistics-light-200.png` | 统计（返回后） | 浅 | 200% |
| `statistics-dark-100.png` | 统计（返回后） | 深 | 100% |
| `statistics-dark-200.png` | 统计（返回后） | 深 | 200% |

## 证据边界

- 证明：返回后页面仍为正式 Flutter 组件，期间/选点/滚动恢复，四种代表状态无溢出或裁切异常。
- 不证明：设备真实字体回退、读屏、真机、真实站点。CJK 使用测试回退字体；随包 Inter 的最终字体入口仍由 #26 修正，本轮不宣称字体验收。
- 不证明：真实点击坐标、动画或性能；这些属 #16/#17 外部 gate。
