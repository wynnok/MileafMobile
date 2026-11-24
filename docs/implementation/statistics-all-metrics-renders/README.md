# 全部指标索引页（P15）版式修复样张

切片证据（[实施记录](../statistics-all-metrics-layout.md)）。本页是全仓唯一一个把
**索引卡直接顶在导航栏底缘**、并且**页尾说明行直接顶在卡片底缘**的二级页；样张
用来复核修好后的两段节奏与 R30.2 页尾形式。

| 文件 | 机位 | 用途 |
| --- | --- | --- |
| `p15-390-top.png` | 390×844，浅色，100% | 标准机位：首张卡从导航栏下方 8 起排；页尾「关于这些数据」分组标题 + 分组卡，与上方卡隔 32 |
| `p15-360-top.png` | 360×800，浅色，100% | 窄屏：两张卡同宽同线；页尾说明行与指标行的行尾箭头共用同一条竖线（修复前裸折叠行的箭头比卡内行右移 16）；「原始统计指标」的说明改写后单行（修复前 16 字断出孤字「细」） |
| `p15-360-notes.png` | 360×800，浅色，100%，展开「时间与时区」 | 说明行默认折叠、原位展开；展开内容读得到统计时区 |
| `p15-390-dark-top.png` | 390×844，深色，100% | 深色模式无回退 |
| `p15-390-200-top.png` | 390×844，浅色，200% | 大字：两段节奏仍成立，页尾落到第二屏（可滚动，无溢出） |

## 复现

```sh
./tool/flutterw test --no-pub test/apple_polish_ap11_render_test.dart \
  --dart-define=MILEAF_AP11_RENDER_OUTPUT=build/allmetrics-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

渲染入口是 opt-in：不传 `MILEAF_AP11_RENDER_OUTPUT` / `MILEAF_RENDER_FONT` 时跳过。
产物在 `build/allmetrics-renders/`（`build/` 是生成物，不入库），本目录只收
`all-metrics-*` 五张代表样张并改名。字体用系统 `Arial Unicode.ttf` 作 CJK 兜底
（与 `test/support/render_fonts.dart` 口径一致），DPR 1，safeArea 24/24。

## 与 AP11 正式图册的分工

`docs/implementation/apple-polish/AP11.md` 的机位用 `aGalleryClient` 的
normal/empty/missing/legacy/long 五个数据状态覆盖整页矩阵；本目录只覆盖本切片
关心的两段节奏与页尾形式，不重复状态档。
