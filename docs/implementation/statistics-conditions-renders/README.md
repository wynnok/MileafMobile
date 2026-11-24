# 能耗专题（P08）版式修复样张

切片证据（[实施记录](../statistics-conditions-layout.md)）。夹具使用**高精度合成浮点**（`164.38290651723641` 等 15 位有效数字）与三组温区标签（5至10°C / 10至15°C / 15至20°C），复现长读数、舍入与窄屏折行。夹具在 `test/support/raw_conditions_fixture.dart`（`rawConditions()` 与真实形态 `denseConditions()`）。

| 文件 | 机位 | 用途 |
| --- | --- | --- |
| `p08-430-top.png` | 430×932，浅色，100% | 宽屏一屏：结论卡 efficiency 洗色底（焦点卡）、卡间 12、读数取整、三段轨道单行 |
| `p08-390-top.png` | 390×844，浅色，100% | 标准机位 |
| `p08-360-top.png` | 360×800，浅色，100% | 窄屏：三段控件折行后轨道退回内容容器半径（原「团块」位置） |
| `p08-360-bottom.png` | 360×800，浅色，100%，滚到底 | 样本明细、下钻行与同页卡片同宽同线、页尾说明的 section 间距 |
| `p08-390-200-top.png` | 390×844，浅色，200% | 大字：结论卡与主图卡仍各成一张卡，读数与分段不互压 |
| `p08-390-dark-top.png` | 390×844，深色，100% | 深色模式无回退 |
| `p08-390-dense13-top.png` | 390×844，浅色，100%，13 组 | 真实组数：点图 13 个点只放行 7 个读数（不叠压）；组数超过 6 时分段轨道换成下拉胶囊（只显示当前组） |
| `p08-390-200-dense13-top.png` | 390×844，浅色，200%，13 组 | 真实组数 × 大字：读数进一步减到 3 个；这一组合顺带暴露并修掉了轴标签 `clamp` 越界抛异常 |

2026-11-24 发布前以 ADR 0021 配色和合成夹具重新生成全部 8 个机位。

## 复现

```sh
./tool/flutterw test --no-pub test/statistics_conditions_raw_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=build/conditions-fix-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

渲染入口是 opt-in：不传 `MILEAF_RENDER_OUTPUT` / `MILEAF_RENDER_FONT` 时跳过。字体用系统 `Arial Unicode.ttf` 作为 CJK 兜底（与 `test/support/render_fonts.dart` 的口径一致），测试视口 DPR 1、safeArea 24/24，PNG 以 2 倍视口尺寸导出。

## 与 AP12a 正式图册的分工

`docs/implementation/apple-polish/AP12a.md` 的矩阵（`test/apple_polish_ap12a_render_test.dart`）用**整数化**夹具（248/210/195、30 km），覆盖的是版式骨架与状态档；本目录专门覆盖「高精度浮点 + 窄屏温区标签 + 密集分组」下的读数宽度与折行，两者互补，不重复。
