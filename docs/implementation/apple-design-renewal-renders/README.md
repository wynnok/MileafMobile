# Apple 风格焕新正式图证

2026-11-16 由正式 Flutter App、固定 HTTP 夹具与共享组件生成。代表图尺寸为 390×844 逻辑像素，DPR 2，输出为 780×1688 PNG；Inter 使用项目字体，中文测试回退为 Arial Unicode。输入固定点为 `5c7683f`，时区为 `Asia/Shanghai`，采样时间来自夹具 `2026-10-26T11:00:00Z`。

| 页面 | 浅色 | 深色 |
| --- | --- | --- |
| 概览 | `overview-light.png` | `overview-dark.png` |
| 行程 | `drives-light.png` | `drives-dark.png` |
| 统计首页 | `statistics-light.png` | `statistics-dark.png` |
| 充电详情 | `charging-detail-light.png` | `charging-detail-dark.png` |
| 费用补录 | `charging-cost-light.png` | `charging-cost-dark.png` |

代表图验证同调车况表面、浮动导航、完整字阶、图表读值、SOC 弧与不透明表单；对应几何框见 `geometry.json`，文件哈希见 `manifest.json`。

`matrix/` 是 41 张快速审查切片，覆盖浅/深色、320/360/768 宽、100%/200% 字号、正常/空/缺失/失败/进行中/超长状态，以及首屏、操作位、专题和地图状态。`full-matrix/` 保留 U04–U10 十个正式入口生成的完整 opt-in 证据，共 1006 张唯一 PNG、119 MiB；每张文件的 SHA-256、尺寸、DPR、字体、材质模式、夹具与采样时刻记录在 `full-matrix-manifest.json`。文件名沿用生成器的 `任务-页面-场景-外观-宽度-字号-机位.png` 格式，manifest 为尺寸和材质模式的权威索引。

材质模式的本地证据区分首屏实色、内容经过后的磨砂、高对比实色、减少透明度实色与模态覆盖实色；所有矩阵使用固定视觉夹具，不能替代设备上的系统设置映射。地图真实底图、真实站点、键盘与读屏真机行为、Liquid Glass 的系统级折射及设备性能不由本图册证明，继续沿 #11/#16/#17 验收。
