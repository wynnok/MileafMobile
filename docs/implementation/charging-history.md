# Ticket #12：充电历史与站点币种

## 交付与接口

充电入口使用固定 OpenAPI 生成的 ChargingSessionPage，复用 SessionController 的授权 GET、BusinessCache 与 CalendarContext。20 条不透明游标分页保留服务端顺序、按 ID 去重；滚动或按钮继续，加载期间不会重复翻页。失败保留已加载记录，局部重试保留失败页游标；刷新和日期变化重新读取第一页。当前请求带准确连接、会话、车辆和完整日期参数；迟到结果不会污染新归属。刷新使用新的当前时刻截断今天。

默认今天与前 29 日本地日历日；自定义输入含首尾日期，转换为 UTC 半开区间，历史结束日按 IANA 日历次日零点处理。没有统计的 730 天上限；非法、未来或零长度区间不发请求。ChargingFilter 只保存本次会话的日历日期，前台换日/时区后相对窗口重算，自定义日期保留并按新 IANA 重算。切车与查询上下文变化重置分页；只对当前可见资源响应前台。

列表依据 is_active 标记进行中，is_dc=null 为分类未知，不归入 AC；充入电池与电网侧能量单独命名。费用 null 保留缺失、零显示 0，不推断人民币；地点优先 display_name，缺失显示未知地点，保留地址/围栏，无逆地理编码。记录点击通过 onRecord('charge', id) 传递；完整详情由后续 Ticket #13 接入。

CurrencyPreferenceStore 是平台普通偏好边界，PreferenceCurrencyStore 使用 SharedPreferencesAsync，以准确站点 URI 保存 currency 标签。CurrencySettings(site, store) 是可复用 ChangeNotifier，restore/select 读写站点偏好，code 是已选代码或 null，amount(number) 保留原数字并最多展示两位小数。后续充电详情和统计共享 WorkspacePage 所拥有的同一实例，不新建互不通知的设置副本。设置仅提供币种标签、不换汇、不推断设备地区、不修改服务端数据；必须明确用户需确保站点所有记录使用同一币种。

## 自动化证据

App 操作与可控 HTTP 主边界覆盖固定后端样本解码、能量/费用口径、未知分类/地点与进行中、分页失败保留/重试/去重、200→304、刷新游标与截止时刻、DST 历史日、非法日期、切车迟到、前台换日/时区、币种选择/重启恢复，以及 360 宽 200% 字深色和可恢复详情导航意图。没有为 DTO/私有状态另设测试缝。

固定充电样本来自项目已保存的合成数据库真实 HTTP 输出，不是用户真实位置或账号数据；固定 OpenAPI 与生成器闭包保证字段不被手工简化。DTO 可通过项目 Flutter 包装器运行生成器、指定 ChargingSessionPage 根复现；数组支持复用 Ticket #9 的同一生成器扩展。

## 外部待验

本票保持开放：真实站点多页充电读取与 Grafana 同口径对账、Android/iPhone 普通偏好杀进程恢复、双端真实屏幕阅读器/系统返回仍待条件具备后验收。代码与 App 自动化不等同这些外部项目通过；用户已批准代码先行、保留 Ticket 原生阻塞边和外部验收。
