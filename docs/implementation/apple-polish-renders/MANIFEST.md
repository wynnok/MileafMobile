# Apple 质感精修统一图册（AP14 收口登记）

2026-11-18 由 AP14 建立索引。单一新图册按票分目录，每目录自带 manifest
（输入 SHA、夹具、时区、字体路径与哈希、尺寸、DPR、材质与偏好、图像哈希）。
旧代图册处理按 `render-archive.md`（P-5 需单独确认），本目录不存已归档代。

| 目录 | 内容 | manifest | 输入冻结点 / input_sha |
| --- | --- | --- | --- |
| `before/` | AP00 基线（ADR0014 前） | `before/manifest.json` | FP0 / 6492c83 |
| `AP01/` | 角色板与图标板（浅深、100/200%） | `AP01/manifest.json` | — |
| `AP02/` | 外壳（展开/收起、滚动 0/8/16/100、大内容查看器、实色）＋ geometry.json | `AP02/manifest.json` | — |
| `AP03/` | 控件与弹层 | `AP03/manifest.json` | — |
| `AP04/` | 内容组件 | `AP04/manifest.json` | — |
| `AP05/` | 图表语法 | `AP05/manifest.json` | — |
| `review/` | AP07 代表页评审包（41 张） | `review/manifest.json` | FP2 / 1f3c721 |
| `AP08/` | 概览全状态 | `AP08/manifest.json` | FP3 / 8ea7e29 |
| `AP09/` | 行程列表与详情、地图 | `AP09/manifest.json` | FP3 / 8ea7e29 |
| `AP10/` | 充电账本与详情 | `AP10/manifest.json` | FP3 / 8ea7e29 |
| `AP11/` | 统计首页与全部指标 | `AP11/AP11-manifest.json` | FP3 / 8ea7e29 |
| `AP12a/` | 专题（节奏、能耗、补能） | `AP12a/gallery/ap12a-manifest.json` | FP3 / 8ea7e29 |
| `AP12b/` | 专题（长期续航、停放观察） | `AP12b/manifest.json` | FP3 / 8ea7e29 |
| `AP13/` | 设置、接入、费用补录 | `AP13/manifest.json` | FP3 / 8ea7e29 |
| `AP14/` | 集成收口机位（概览全机位，含 D-AP08-05 电量弧修复后的 130%） | `AP14/manifest.json` | FP4 / a5f0ee7 |

- AP14 机位按 `apple_polish_ap08_render_test.dart` 入口重采，输入为 FP4 登记提交
  `a5f0ee7` 上的集成收口代码；与 AP08 目录的差异即 AP14 组件修复（电量弧
  130% 紧贴、cp09 措辞收口）的可视对照。
- 每页前后对照与目视清单见各票 `docs/implementation/apple-polish/APxx.md`。
- 图像哈希 fnv1a64，字体 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`
  （fnv1a64 `3dbc05ebd911cf0b`），DPR 1，材质 glass，safeArea 上下 24（safe0 机位 0）。
