# AMap SDK reflection/native entry points; keep the map module intact.
-keep class com.amap.api.maps.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.amap.api.trace.** { *; }
-dontwarn net.jafama.**
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
