# MC01 / MC02 记录：语义色相 token 与对比度守卫

## 做了什么

- `lib/src/design/tokens.dart`：新增 `MileafHueRamp`（六色相 × 浅 solid / 浅 strong / 深 单档，共 18 个常量）与 `MileafHueWash`（soft 16% / tint 8%）。**既有常量一个都没改**。
- `lib/src/design/semantic.dart`：新增 `enum MileafHue`、`enum MileafDataDomain`、`extension MileafDataDomainHue`（域 → 色相）、`extension MileafHueTone`（solid / strong / soft / tint / onStrong）、`extension MileafDataDomainTone`。不新增 `MileafColors` 字段，解析只读 `isDark` 与既有前景。
- 新测试：`test/chromatic_hue_token_test.dart`（11 用例）、`test/chromatic_contrast_guard_test.dart`（81 用例）。

## 取值是怎么来的（可复核）

```
浅色 solid：对 #FFFFFF 3.55:1（= azure500 实测），C = 0.95 × 该 L 下 OKLCH 可用彩度
浅色 strong：对 #FFFFFF 5.90:1（= azure600 实测），且须对 soft16 合成底 ≥4.60
深色      ：对 #12161C 7.42:1（= azure300 实测），C = 0.90 × 可用彩度
```

色相角（OKLCH）：253 / 196 / 152 / 85 / 18 / 310 —— 相邻 44–68°，没有参考 App 在蓝紫段 21° 的密簇。

## 实测（守卫结果）

| 断言 | 结果 |
| --- | --- |
| solid 对 surface / canvas ≥3.0 | 全部通过（实测 3.25–3.59） |
| strong 对 canvas / surface ≥4.5 | 全部通过（实测 5.41–6.17） |
| strong 对 soft 合成底（over canvas / over surface）≥4.5 | 全部通过（实测 4.60–5.02） |
| onStrong 对 strong 实心底 ≥4.5 | 全部通过（浅 5.90–6.17 / 深 8.05–11.31） |
| text 对 tint 合成底 ≥4.5 | 全部通过 |
| azure 与 accent/accentStrong 逐字节一致 | 通过 |

## 遗留

- `amber` 在浅色只能是金棕（CL-偏差，见规格 §10）：明亮琥珀对白底物理上过不了 3:1。
- 深色只有两档强度（CL02.1）。
