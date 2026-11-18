# Before 图册（AP00）

ADR0014 之前的当前态渲染。输入冻结点 FP0（6492c83）。渲染入口 test/apple_polish_render_test.dart（opt-in，需 MILEAF_RENDER_OUTPUT 与 MILEAF_RENDER_FONT）。

当前态的完整矩阵见 docs/implementation/apple-design-renewal-renders/full-matrix/（ADR0012）与 liquid-glass-nav-renders、overview-chart-header-renders（ADR0013 与概览图表头）。本目录承载 AP00 重新采集的 before 首屏与 manifest。

命名：before-<页面>-<浅深>-<宽>-<字号>-<机位>.png。manifest 记录输入 SHA、夹具、时区、字体路径与哈希、尺寸、DPR、材质与偏好。
