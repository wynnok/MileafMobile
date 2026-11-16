# 液态玻璃底栏图证

2026-11-16 由正式 Flutter App、固定 HTTP 夹具与共享组件生成。390×844 逻辑像素、DPR 2，输出 780×1688 PNG；Inter 使用项目字体，中文回退为 Arial Unicode；时区 `Asia/Shanghai`，采样时刻来自夹具 `2026-10-26T11:00:00Z`。

| 页面 | 浅色 | 深色 |
| --- | --- | --- |
| 概览首屏（底栏压在每日里程图上） | `overview-light.png` | `overview-dark.png` |
| 概览滚动后（正文经过栏下） | `overview-scrolled-light.png` | `overview-scrolled-dark.png` |
| 行程滚动后（列表经过栏下） | `drives-scrolled-light.png` | `drives-scrolled-dark.png` |
| 高对比实色回退 | `solid-light.png` | `solid-dark.png` |

`detail/` 是同一批机位的底栏裁切（780×262），用于看边缘、弯月与镜片；`geometry.json` 记录浮栏与材质的实际矩形；`contrast.json` 记录同一次运行中量取的标签与图标对比（测试同时按 4.5:1 / 3:1 断言，不通过即红）。

这些图证明：胶囊几何、内容透出、受光顶边与下沿弯月、镜片为第二层玻璃、实色回退下的中性镜片。它们**不**证明真机材质观感、系统「减少透明度 / 提高对比度」映射与滚动合成帧成本，这三项分别沿 #17 / #17 / #16 验收。

重新生成：

```
tool/flutterw test --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/liquid-glass-nav-renders \
  --dart-define='MILEAF_RENDER_FONT=/Library/Fonts/Arial Unicode.ttf' \
  test/liquid_glass_nav_render_test.dart
```
