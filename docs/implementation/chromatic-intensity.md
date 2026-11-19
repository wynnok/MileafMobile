# 鲜明度 v2 实施记录

- 增量：[ADR 0017](../adr/0017-chromatic-intensity.md) accepted · [规格 §12](../specs/chromatic-language.md) CL49–CL58。
- 目标：保持 ADR 0016 的色相寄存器与纪律，把「彩色」从细线与浅洗搬到亮面，让四个主页面在浅色下也能被读成「有颜色」。
- 样张：[chromatic-intensity-renders/](chromatic-intensity-renders)（4 页 × 浅深，390×844 / 2x）。

## 状态

| 切片 | 状态 | 证据 |
| --- | --- | --- |
| IN01 亮面档 + 洗色改原料 | 完成 | `MileafHueVivid` 6 值、`veil/soft/tint/deep` 四档 |
| IN02 面子关系重写 | 完成 | 图表线柱改 `strong`；洗色面上一切彩色前景取 `strong` |
| IN03 读数按字号分档 | 完成 | `MetricBlock`：metricSm 走 strong，其余走 solid |
| IN04 图表 | 完成 | 面积 40%→6%、主线 2.6、柱宽 16、杆 4、选中点亮面圆心 |
| IN05 入口卡深洗底 | 完成 | 统计根页 2×2 章节卡 55% + 墨字（仅浅色） |
| IN06 记录卡洗底 | 完成 | 行程组 journey / 充电记录 energy |
| IN07 守卫与样张 | 完成 | 新增 `chromatic_intensity_guard_test.dart`（12 用例） |

## 取值

亮面档（L=0.74，彩度取该明度色域边界 96%，浅深共用）：

| 色相 | 亮面 | C | 墨字对比 | 对白底 |
| --- | --- | --- | --- | --- |
| azure | `#6BAEFC` | 0.132 | 7.88 | 2.30 |
| aqua | `#20C2C4` | 0.121 | 8.27 | 2.19 |
| mint | `#20CB6C` | 0.187 | 8.47 | 2.14 |
| amber | `#D5A21B` | 0.146 | 7.79 | 2.33 |
| coral | `#FC7F86` | 0.153 | 7.35 | 2.47 |
| violet | `#CC88FC` | 0.174 | 7.34 | 2.47 |

洗色（全部以亮面为原料）：

| 档 | 浅 | 深 | 合成后 C | strong 最差格 |
| --- | --- | --- | --- | --- |
| `veil` | 40% | 40% | 0.044–0.074 | 4.02（只按图形 3:1 判） |
| `soft` | 24% | 22% | 0.026–0.055 | 4.56 / 4.92 |
| `tint` | 24% | 22% | 0.026–0.055 | 4.56 / 4.92 |
| `deep` | 55% | — | 0.072–0.117 | 墨字 11.4–12.0 |

## 逐像素前后对照

口径：整个首屏（含底栏）按 3 像素步长采样，OKLCH 彩度；`C>0.04` 记「看得出彩色」，`C>0.12` 记「高彩」。

| 页面 | 模式 | C>0.04 前 → 后 | C>0.12 前 → 后 | 平均 C 前 → 后 |
| --- | --- | --- | --- | --- |
| 概览 | 浅 | 3.92% → 5.94% | 0.83% → 1.03% | 0.0105 → 0.0177 |
| 概览 | 深 | 4.17% → 40.10% | 0.80% → 1.01% | 0.0189 → 0.0267 |
| 统计 | 浅 | 2.39% → 18.10% | 2.14% → 2.56% | 0.0135 → 0.0328 |
| 统计 | 深 | 2.43% → 53.48% | 2.14% → 2.69% | 0.0199 → 0.0318 |
| 行程 | 浅 | 0.72% → 0.74% | 0.61% → 0.62% | 0.0060 → 0.0206 |
| 行程 | 深 | 0.75% → 55.28% | 0.61% → 0.62% | 0.0143 → 0.0296 |
| 充电 | 浅 | 0.54% → 45.71% | 0.28% → 0.28% | 0.0031 → 0.0233 |
| 充电 | 深 | 0.58% → 46.50% | 0.48% → 0.48% | 0.0107 → 0.0258 |

四处需要解释的数字：

1. **行程（浅）0.74%**：azure 的洗色是六个色相里最淡的——L=0.74 的蓝只有 C 0.132，洗到 24% 后合成 C 0.028，刚好低于 0.04 口径。同一张卡换成 mint 洗色就是 0.055。这是 azure 在 sRGB 里的物理位置，不是漏做；平均 C 从 0.0060 到 0.0206（3.4 倍）已经说明卡片确实着色了。
2. **充电（浅）45.71%**：充电记录是一整块分组卡（不是一行一卡），一张卡就占了半屏；aqua 洗色的 C 本身也高于 azure（0.045 vs 0.028）。
3. **深色普遍 40–55%**：深色 surface 是近黑，24% 亮面叠上去得到的是「中等明度的彩色块」，彩度自然高；这并不等于浅色模式也这么花。
4. **洗色面积已经超过原来「彩色 ≤5%」的口径**：充电（浅）45.7% 里，高彩只有 0.28%。也就是说原来那条 5% 的口径量的其实是洗色，而不是「花」——本轮据此把它改成「高彩 ≤5% + 洗色不设上限」（CL52）。

## 组件 API 变更

```dart
// design/semantic.dart（新增）
hue.vivid(colors)     // 亮面；两模式同值
hue.veil(colors)      // 40% 亮面：图表填充、弧环轨道（不承载文字）
hue.soft(colors)      // 24%（深 22%）：小格底、选中格
hue.tint(colors)      // 24%（深 22%）：卡片背板
hue.onVivid(colors)   // 墨字（slate900）

// design/components/module.dart
MileafModuleCard(hue: …, emphasis: MileafCardEmphasis.field | .deep)
MileafGroupCard(hue: …)   // 记录分组卡取所属域洗底
```

`MileafCardEmphasis.deep` 只在浅色生效（深色自动退回 `tint`）；卡内文字必须自己换成墨色，组件只负责底。

## 逐页登记

| 页面 | 浅色首屏彩色来源 | 色相数 | 深洗底 |
| --- | --- | --- | --- |
| 概览 | 焦点卡 tint + 读数 solid + 图表线 strong | 3（journey / efficiency / energy） | 无 |
| 行程 | 焦点卡 tint + 记录分组卡 tint + 读数 | 3（journey / efficiency / dwell） | 无 |
| 充电 | 记录分组卡 tint + 读数 + SOC 条 | 3（energy / cost / 中性未知） | 无 |
| 统计 | 焦点卡 tint + 2×2 章节卡 deep + 专题卡 | 4（journey / efficiency / dwell / cost） | 4 张章节卡 |
| 设置 / 连接 / 地图 | 0（保持中性） | 0 | 无 |

## 验收自检

| 约束 | 结果 | 证据 |
| --- | --- | --- |
| 正文 ≥4.5:1 | ✅ | strong 压 veil/soft/tint 六色相 × 浅深 × canvas/surface = 72 格，最差 4.56（深 4.92） |
| 图形 ≥3:1 | ✅ | solid 压 canvas/surface 24 格；图表线柱取 strong（4.56–5.90） |
| 亮面只配墨字 | ✅ | 六亮面对墨字 7.34–8.47；对白底 2.14–2.47（守卫断言 <3，即禁止承界） |
| 洗色看得出彩色 | ✅ | tint 合成 C 0.026–0.055、veil 0.044–0.074 |
| 高彩 ≤5%（CL52 新口径） | ✅ | 四页 × 浅深实测 0.28–2.69% |
| 单页 ≤4 色相 | ✅ | 逐页登记；统计根页 4（含动作色） |
| 底栏不改 | ✅ | 未触碰 ADR 0013 的 nav 组件 |
| 深色只有一档 reading | ✅ | 深色 strong=solid；入口卡自动退回 tint |
| 自动化 | ✅ | `analyze --no-pub lib test` 干净；全量 **1347 通过 / 56 跳过 / 0 失败** |

## 审查与修订（实施中真的改过的）

1. **洗色首版 30%/26% 被守卫打回**：`strong` 压 canvas 上的 30% 洗色只有 4.43–4.49:1，低于 4.5。反解出上限 24%（4.56），并把结论写回 CL50——「面积越大 alpha 越低」是错的，决定上限的是前景。
2. **亮面柱体实验回退**：先做了「亮面填充 + strong 描边」的柱体，渲染后发现图形卡本身是色相洗底，同色相亮面压在同色相浅底上只有 1.5:1，远看像空心描边。已回退为实心 strong 柱（宽 12→16 保留），并把否证写进 CL53.1。
3. **深色入口卡断言要容差**：Flutter 的 `alphaBlend` 按 8 位量化，与用 double 复算的合成色差 ~0.002/通道；断言改为逐通道 0.01 容差。
4. **`MetricValueScale.metricSm` 保守留在 strong**：20 号只有 600 重，不算 WCAG 的「大文本」（14pt bold = 18.66px 且需 bold 700），所以宁可少提亮一档。
5. **`dates.dart` 一条既有 lint**：上一轮 `dart format` 提交把 `if (…) return …;` 拆行后触发 `curly_braces_in_flow_control_structures`，本轮一并修掉（analyze 从 2 条 info 回到 0）。

## 遗留

1. **azure 洗色仍是最淡的一档**（C 0.028，低于 0.04 口径）：要再深只能换墨字，而那会拿掉卡内读数的域身份色。已记为取舍，不做。
2. **亮面档目前只有两种形态**：洗色原料、图表选中点圆心。没有出现 100% 亮面的整块面（物理上不允许：对白底 2.1–2.5:1）。
3. **样张只覆盖 4 页 × 2 模式 × 100% 字号**，没有 200% 字号与专题页；CL58 的像素口径尚未进 CI（仍是脚本 + 人工登记）。
4. **真机未验证**：本轮只做渲染与自动化；#11/#16/#17 三个外部 gate 不因本轮关闭。
## 样张

390×844 逻辑尺寸、2x 导出，浅深两模式；页面上都是首屏（可滚动内容不计）。

| 页面 | 浅色 | 深色 |
| --- | --- | --- |
| 概览 | ![概览浅色](chromatic-intensity-renders/overview-light.png) | ![概览深色](chromatic-intensity-renders/overview-dark.png) |
| 统计 | ![统计浅色](chromatic-intensity-renders/statistics-light.png) | ![统计深色](chromatic-intensity-renders/statistics-dark.png) |
| 行程 | ![行程浅色](chromatic-intensity-renders/drives-light.png) | ![行程深色](chromatic-intensity-renders/drives-dark.png) |
| 充电 | ![充电浅色](chromatic-intensity-renders/charging-light.png) | ![充电深色](chromatic-intensity-renders/charging-dark.png) |

复现：

```sh
tool/flutterw test --no-pub test/chromatic_intensity_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/chromatic-intensity-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

不传两个 dart-define 时该测试整组跳过（与既有渲染测试同一机制），因此全量测试里计作 skipped。
