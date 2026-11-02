# 外观 v2 正式渲染图册（AV07）

- 日期：2026-11-02
- 分支：`main`（本地提交，未推送）
- 生成入口：`test/a_gallery_render_test.dart`（**沿用的既有 opt-in 入口**，未新增渲染测试；未设置 `MILEAF_RENDER_OUTPUT` 时整条测试 `skip`）
- 生成条件：360×800 逻辑像素、`devicePixelRatio = 1`、`toImage(pixelRatio: 2)` → PNG 720×1600；Inter 400/500/600 + 渲染机 CJK fallback（`/System/Library/Fonts/Supplemental/Arial Unicode.ttf`）
- 数据：`test/support/a_gallery_fixture.dart`（`aGalleryClient`）复用 `test/support/c_fixture.dart` 的合成快照；**不是真实站点、不是真机截图**
- 外观：由 `AppearanceController` + 内存 `AppearancePreferenceStore` 强制浅/深（同一条测试里同时设置 `platformBrightnessTestValue`，两者一致；不存在「浅深共用一套颜色」的可能）

## 生成命令

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/appearance-v2-renders/gallery \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
# 00:27 +1: All tests passed!   132 张，每张保存后立即 assert 无异常（无溢出/无裁切断言由 test 自身保证）
```

「旧/新对照」是把 `a-renders/gallery` 与新图按**同名同机位**左右拼接（左＝旧 A 玉绿，右＝外观 v2 电光蓝），条带文字为 `before / A jade (a-renders)` 与 `after / appearance v2 azure`：

```sh
# macOS 上用 Python + Pillow（仅渲染后处理，不是项目依赖）
python3 - <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw
root = Path("docs/implementation")
old, new, out = root/"a-renders/gallery", root/"appearance-v2-renders/gallery", root/"appearance-v2-renders/compare"
for page in ["overview","drives","charging","statistics","drive-detail","charge-detail"]:
    for mode in ("light","dark"):
        for scale in ("100","200"):
            name = f"{page}-normal-{mode}-{scale}.png"
            a, b = Image.open(old/name).convert("RGB"), Image.open(new/name).convert("RGB")
            w, h = a.size
            canvas = Image.new("RGB", (w*2+2, h+44), (255,255,255))
            canvas.paste(a, (0,44)); canvas.paste(b, (w+2,44))
            d = ImageDraw.Draw(canvas)
            d.rectangle([0,0,w*2+2,43], fill=(28,28,30))
            d.text((14,14), "before / A jade (a-renders)", fill=(240,240,240))
            d.text((w+16,14), "after / appearance v2 azure", fill=(240,240,240))
            d.line([(w,0),(w,h+44)], fill=(120,120,120), width=2)
            canvas.save(out/name, optimize=True)
PY
```

## 矩阵：11 页 × 3 态 × 2 外观 × 2 字号 = 132 张

票面 AV07 的必需范围是**四主 Tab + 两类详情 × 浅/深 × 100/200% × normal = 24 张**（下表前 6 行，每页每模式 4 张）。既有入口一次跑完 11 页（含 5 个专题），因此**超集归档 132 张**；`empty` / `missing` 两态也一并在图内，用于证明新色板下空态与缺失态仍然成立。

| # | 页面 | 文件前缀 | normal | empty | missing | 票面必需 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 概览 | `overview-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 2 | 行程 | `drives-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 3 | 充电 | `charging-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 4 | 统计（总览） | `statistics-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 5 | 行程详情 | `drive-detail-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 6 | 充电详情 | `charge-detail-*` | 浅/深 × 100/200 | ✓ | ✓ | ✅ |
| 7 | 专题·节奏 | `topic-rhythm-*` | ✓ | ✓ | ✓ | 超集 |
| 8 | 专题·能耗 | `topic-energy-*` | ✓ | ✓ | ✓ | 超集 |
| 9 | 专题·补能 | `topic-charging-*` | ✓ | ✓ | ✓ | 超集 |
| 10 | 专题·长期续航 | `topic-range-*` | ✓ | ✓ | ✓ | 超集 |
| 11 | 专题·停放观察 | `topic-parking-*` | ✓ | ✓ | ✓ | 超集 |

合计 **132 张**：132 个文件 sha256 互不相同（不存在「浅色渲染其实复用了深色」的空图）；66 对「同页同态同字号」的浅/深全部不同；66 对 100/200% 全部不同。

## 指纹

- 132 张 PNG：`17ac0e760e9d1e5dbf1b1bedb8dc99271eef5c11afe088edd2afec297c723fe3`
  （`sha256` over 排序后的「文件名:文件 sha256」行，行间 `\n`，末尾一个换行）
- 源码：`65dd739e7f4ba225a75dc818ef05f7b68f68b2e654ed73c205dca2ad0d00db89`
  （`find lib/src -name '*.dart'` + `test/a_gallery_render_test.dart` + `test/support/a_gallery_fixture.dart` + `test/support/c_fixture.dart` + `test/support/render_png.dart`，按路径排序后拼接；86 个文件）

> 两次运行：审查修复前（`bace9cfc…`）与修复后（`65dd739e…`）各出过一轮，132 张 PNG 的指纹**完全相同**（`17ac0e76…`）——修复只动按压高亮与注释，静态画面不变。归档的是修复后那一轮的图。

## 自查（图册自身的验收项）

### 1) 旧色板残留扫描：0 命中

对 132 张 PNG 逐像素统计精确色值命中（antialiasing 的混色不计，只看实心填充）：

| 旧色 | 含义 | 命中 |
| --- | --- | --- |
| `#F1F0EB` | 暖米画布（旧浅色底） | 0 |
| `#FAF9F5` / `#E9E7E0` | 暖米 surface / 骨架 | 0 |
| `#8A5A1F` / `#D8B27C` | 土黄参照（旧 reference） | 0 |
| `#1C6B4F` / `#74DDA8` | 墨绿/薄荷强调（旧 accent） | 0 |
| `#050806` / `#070908` / `#0E120F` | 绿黑 hero / 绿黑画布 / 绿黑 surface | 0 |
| `#121613` / `#9FB9AA` | 旧浅色正文 / 旧 hero muted | 0 |

反向核对新底色确实是新值：浅色图主导底色 `#F4F5F7`（64 张）或 `#070B11`（2 张，hero 面积占多数的页面）；深色图主导底色 `#0A0B0D`（63 张）或 `#06090E`（3 张）。

**深色「绿黑→冷黑」**：132 张里「绿偏像素」（`G > R+12` 且 `G > B+12` 且 `G > 40`）总数为 **0**，占 0.0%；深色画布 `#0A0B0D` 的蓝通道高于红通道（R10/G11/B13），旧画布 `#070908` 是 G>B>R（绿偏）。

### 2) hero 卡片几何：外距 12、圆角 20（图上量得）

量法：在 720×1600 的 PNG（1 逻辑像素 = 2 图像像素）里找「连续 ≥560px 的深色游程」作为卡片主体，取主体行的左右边界与圆角过渡行数。

| 图 | 卡片左右边界（px） | 外距（px → 逻辑） | 圆角过渡（px → 逻辑） |
| --- | --- | --- | --- |
| `overview-normal-light-100` | 24 / 695 | 24 → **12** | 39 ≈ **20** |
| `overview-normal-light-200` | 24 / 695 | 24 → **12** | 39 ≈ **20** |
| `charging-normal-light-100` | 24 / 695 | 24 → **12** | 39 ≈ **20** |
| `statistics-normal-light-100` | 24 / 695 | 24 → **12** | 39 ≈ **20** |
| `charge-detail-normal-light-100` | 24 / 695 | 24 → **12** | 39 ≈ **20** |
| `overview-normal-dark-100` | 0 / 719 | 0 → **满幅** | 0（无圆角） |

（`drives-*`、`drive-detail-*` 本就没有 hero，卡片游程检测为 0 行，符合预期。）

### 3) 无横向溢出、无裁切

- 132 张每张的保存入口都会 `expect(tester.takeException(), isNull)`：溢出会以 `RenderFlex overflowed` 异常让该张直接失败。本次运行 `All tests passed`，即无溢出异常。
- 每张图保存前还断言该页该态的标记文本确实在屏（normal 有主数、empty 有空态文案、missing 有 `—`），空态不得出现 normal 的数字、normal 不得出现空态文案（`markers` 表，132 条逐条校验）。
- 200% 图里长行按既有 large-text 分支换行（例：`statistics-normal-light-200` 的「10/26 60.0 km / 参照 55.4」+「点按读值」两行都在卡片内，无省略号）；卡片纵向随内容增长，超出视口的部分是**正常滚动**（底部导航是半透明浮层，内容在其下继续），与 `a-renders` 旧图行为一致（见 `compare/statistics-normal-light-200.png` 左右两侧相同的裁切位置）。

## 每张图证明什么

| 页面 | 证明 |
| --- | --- |
| `overview-*` | 浅色 hero 是纸面上的卡片（外距 12、圆角 20、无描边无阴影、品牌行在纸面且字标为深墨）；深色 hero 仍满幅并吞掉品牌行。320 km 主数 + 电量环 + 三读数；本月主数与主图；浅色下无暖米底、无土黄参照线；空态不画全零、缺失 `—` |
| `drives-*` | 列表页无 hero（形态判据只在有 hero 的页面生效）；期间主数、节奏条带、最近的路；空态 0.0 km + 「这段时间还没有行程」，缺失 `—` |
| `charging-*` | 费用 hero 在浅色是卡片、深色满幅；三读数与 stem 图；空态费用 `—` 且不画全零补能图 |
| `statistics-*` | 浅色「里程走势」是卡片（§6.1 判据的第四处调用点），卡内系列用 `accentHero`、网格 `heroText` 12%；2×2 章节卡仍在；200% 读数换行不裁切 |
| `drive-detail-*` | 详情页首个视觉是地图/路线与速度曲线，非 hero；浅色地图同意条与卡片同底色；200% 下同意条三行说明完整 |
| `charge-detail-*` | 电量区间弧 hero 在浅色是卡片、深色满幅；三结果 2×2；功率曲线；missing 保留 46.8 kWh / ¥71.28 / 34 分钟 |
| `topic-rhythm-*` | 活跃天数、每日用车热图（最强格 9px 日期为深墨，4.5:1 以上）、证据 2×2 |
| `topic-energy-*` | 温度分组主数 + 分组点图；空态「区间内无已完成行程」 |
| `topic-charging-*` | 已知支出、均价、覆盖、入电量走势；AC/DC/未知三段＝`accent` / `azure600` / `textFaint`，肉眼可分辨 |
| `topic-range-*` | 6/12 个月窗口、所选月中位数、P10–P90 波动带；参照虚线用中性 `steel` 而非土黄 |
| `topic-parking-*` | 有效窗口 SOC 变化 hero、分桶柱、状态分布；缺失显示「分桶SOC变化缺失，不补零」 |

## 与 Spec §13 验收清单的对应

| §13 条目 | 图册证据 |
| --- | --- |
| 浅色 hero 12 外距 + 20 圆角卡片；深色满幅；同页不混用 | 本文件「自查 2)」的量测表 + 每页 4 张浅/深对照 |
| 浅色概览 top bar 在纸面、图标深色；深色 top bar 在 hero 内、图标浅色 | `overview-normal-light-100` / `-dark-100`（左深右浅逐张对比） |
| 浅色画布 `#F4F5F7`、卡片 `#FFFFFF`；无暖米底与土黄线条 | 本文件「自查 1)」的 0 命中表 |
| 所有强调色文字用 `accentStrong`；浅色无 3.25:1 蓝字 | `compare/*-light-*`：选中 chip、导航标签、`全部指标` 均为深蓝 `#0B62C4`；浅蓝 `#2688F5` 只出现在线/点/弧/指示条 |
| 7 处 hero 调用浅色均为卡片、无横向溢出（含 200%） | 6 页 × 4 张 + 3 个专题 hero；溢出由每张的异常断言兜住 |
| 图表系列、参照、当前点、hero 内图表两模式可读 | `overview-*`、`statistics-*`、`topic-*` 实线/虚线/当前点；`compare/` 左右同机位可直接比色 |
| 四主 Tab + 两类详情 × 浅/深 × 100/200% 全部重出并归档 | 本目录 `gallery/` 132 张（必需 24 张 + 超集 108 张） |

## 旧 / 新对照（24 张）

`compare/` 下与 `docs/implementation/a-renders/gallery/` 同名同机位拼接：

`overview` `drives` `charging` `statistics` `drive-detail` `charge-detail` × `light` `dark` × `100` `200`，文件名与 `gallery/` 完全一致（如 `compare/overview-normal-dark-100.png` 左＝A 玉绿、右＝外观 v2）。

看什么：

1. **浅色**：旧图整张暖米底 + hero 满幅深绿渐变；新图纸面中性、hero 成为 12 外距的冷黑卡片，品牌行回到纸面。
2. **深色**：旧图是绿黑（hero 与画布都带绿调）；新图是冷黑（`#06090E` hero / `#0A0B0D` 画布，蓝通道略高）。
3. **强调色**：旧图薄荷绿到青绿；新图电光蓝，且文字一律用更深的 `accentStrong`。
4. **参照线**：旧图土黄虚线；新图中性钢灰虚线，与数据系列不再争色。

## 未覆盖项（不由本图册证明）

1. **真机**：没有 Android/iOS 实机截图；系统栏图标、安全区、平台字体回退（Inter + CJK）、TalkBack/VoiceOver 仍需真机验收。
2. **真实站点**：全部合成 fixture；真实数据下的极端字符串（超长站点名、异常单位、未知币种）未覆盖。
3. **地图**：渲染里是「底图未启用」同意条与占位，不是真实高德底图；底图/CRS/许可/大陆网络仍待验。
4. **宽度**：只有 360 宽。320/390 的形态与内容宽由 `a_overview_test` 的 12 条矩阵断言守住（264/304/334），但没有归档渲染图。
5. **主题切换中间态**：200ms 颜色过渡由 `design_tokens_test` 的插值断言守住，图册是静态终态，看不到过渡。
6. **hover / focus / pressed**：widget 测试覆盖，图册只出常态。
7. **性能**：没有任何帧时间或冷启动数据。
8. 图册不是设计验收结论；它只证明「实现按 Spec 渲染」。用户对观感的接受与否是另一件事。
