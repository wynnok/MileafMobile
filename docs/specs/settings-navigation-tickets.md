# 设置重整实施任务

依据 [设计规格](settings-navigation.md)。本次为已确认功能的本地 UI 调整。

| 任务 | 文件与模块 | 验收标准 |
| --- | --- | --- |
| SN01 设置首页 | settings_page.dart、workspace_page.dart、session_pages.dart | 两组五项；地图一步直达；无车辆共用入口；状态即时更新 |
| SN02 站点连接 | connection_management.dart | 摘要优先、表单按需展开、字段间距 16、取消清除草稿；候选失败保留连接；成功及退出返回主路由 |
| SN03 服务信息 | overview_page.dart | 移除地图配置入口，统一服务信息名称；版本、schema、兼容和单位信息分层；失败可重试 |
| SN04 验证与教程 | test/、docs/tutorial/amap-key-settings.md | 更新入口教程；导航和业务回归通过；浅深、大字号、键盘真实组件渲染审阅；双轴代码审查 |
