# 视觉重构原型 · 实际浏览器验证

2026-10-30。对象：`docs/prototypes/visual-refresh/`，一次性设计原型。不是正式 Flutter、真机、真实站点或地图验收。

## 运行与素材

- 本地评审服务：`node docs/prototypes/visual-refresh/serve.mjs`，只监听 `127.0.0.1:8770`。
- 页面无数据库、网络请求、字体/图片 CDN、地图瓦片或持久化；CSP 禁止连接其他数据源。
- 截图由系统 Chrome headless 生成，`--force-device-scale-factor=2`、360×800 逻辑视口，输出 720×1600 PNG；没有安装额外依赖。
- 图册：`renders/index.html`；并排图：`renders/compare-light.png`。

## 交互检查

使用 Chrome DevTools Protocol 实际点击，未只检查静态 HTML：

| 检查 | 结果 |
| --- | --- |
| A/B/C 切换、底部四个 Tab | 通过；标题、手机 class 与内容随状态变化 |
| 概览指标 chip（里程/净电耗/补能/费用） | 通过；主图标题、单位、读数与选中态同步 |
| 图表柱子点读、前后读数 | 通过；读数与原始数组一致 |
| 本月 / 近7天 | 通过；A 概览、A 统计、B 概览、B 统计、驱动/充电周期均切换 |
| 最近行程 / 最近充电 → 详情 → 返回 | 通过；A/B/C 详情均可往返 |
| 统计章节 → 专题 | 通过；A/B/C 专题均可打开并显示对应内容 |
| 说明层（数据说明/比较依据/全部记录） | 通过；打开、遮罩、关闭、`Esc` 关闭均通过 |
| 浅色 / 深色 | 通过；三套方向均有深色截图，无控制台异常 |
| 200% 字号 | 通过横向溢出检查；A 概览、C 概览已单独截图。C 在 200% 时改为单列，A 主数与单位仍可读 |
| 并排模式 | 通过；3 台手机、方向标签正确 |
| 空数据 / 部分缺失 | A 概览演示；空态不画全零趋势，缺失净电耗显示“—”。B/C 固定正常样例以比较结构 |

## 全页面渲染检查

21 个组合：A/B/C × 概览/行程/充电/统计/行程详情/充电详情/专题。每个组合检查：

- 只有 1 台手机；
- `.screen` 正文非空（字符数 > 150）；
- `.screen.scrollWidth <= clientWidth + 1`，无横向溢出；
- 控制台无 `Runtime.exceptionThrown` / error 日志。

结果：**21/21 通过，0 个异常**。另检查 3 套 × 4 个主页面 × 200% 字号，**12/12 无横向溢出**。

## 截图

| 文件 | 内容 |
| --- | --- |
| `compare-light.png` | A/B/C 首屏并排，1440×1050 |
| `A-overview-light.png` / `A-overview-dark.png` | 推荐方向首屏，浅/深 |
| `A-drives-light.png` | 行程：期间摘要、节奏、当天记录 |
| `A-charging-light.png` | 充电：费用主屏、每日补能、AC/DC |
| `A-stats-light.png` | 统计：结论、参照主图、章节入口 |
| `A-drive-detail-light.png` | 详情：地图主视觉、结果、速度曲线 |
| `A-charge-detail-light.png` | 详情：SOC、功率曲线、两侧能量 |
| `A-topic-rhythm-light.png` | 统计专题：日历热图与星期节奏 |
| `B-overview-light.png` / `B-stats-dark.png` | 行笺志：纸面标题与编辑式章节 |
| `B-drives-light.png` / `B-charging-light.png` | 行笺志：行迹、补能账 |
| `B-drive-detail-light.png` / `B-charge-detail-light.png` | 行笺志：地图图版、账单 |
| `C-overview-light.png` / `C-overview-dark.png` | 数据拼贴：最大里程 tile 与车况 tile |
| `C-drives-light.png` / `C-charging-light.png` / `C-stats-light.png` | 拼贴：期间、补能、章节 |
| `C-drive-detail-light.png` / `C-charge-detail-light.png` | 拼贴：地图 tile 与功率 tile |
| `A-overview-200.png` / `C-overview-200.png` | 200% 排版检查 |
| `A-overview-empty.png` | 空数据 |
| `A-sheet.png` | 说明层 |

## 仍未验证

- 正式 Flutter 实际渲染、系统字体放大、TalkBack/VoiceOver、手势与真机布局。
- 真实 TeslaMate/Mileaf Server 数据、Grafana 对账、真实地图供应商、坐标参考系与网络可用性。
- 200% CSS 只用于浏览器排版检查，不等同系统字体或原生辅助功能通过。
- 用户审美选择与商业价值未验证；本原型只证明层级方案可运行、可比较。

## 边界

本轮只新增 `docs/product/visual-refresh-proposal.md` 与 `docs/prototypes/visual-refresh/` 下的原型、说明、截图。未改 `lib/`、`test/`、Spec、工单、依赖、构建配置、外部只读仓库或生产配置，未提交/推送。
