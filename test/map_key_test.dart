import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/map/map_key.dart';

import 'support/map_key_fixture.dart';

void main() {
  test('首次保存可用，初始化后替换待重启，清除立即停用', () async {
    final store = TestKeyStore();
    final keys = MapKeyController(store);
    await keys.restore();
    expect(keys.available, isFalse);
    await keys.save('a' * 32);
    expect(keys.available, isTrue);
    expect(keys.restartRequired, isFalse);
    expect(keys.keyForMap(), 'a' * 32);
    await keys.save('b' * 32);
    expect(keys.restartRequired, isTrue);
    expect(keys.keyForMap(), 'a' * 32);
    await keys.clear();
    expect(keys.available, isFalse);
    expect(keys.keyForMap(), isNull);
    expect(keys.restartRequired, isTrue);
    await keys.save('a' * 32);
    expect(keys.restartRequired, isFalse);
  });
  test('保存和清除失败保留原值，重启后恢复最新配置', () async {
    final store = TestKeyStore();
    final keys = MapKeyController(store);
    await keys.restore();
    await keys.save('a' * 32);
    keys.keyForMap();
    store.fail = true;
    await expectLater(keys.save('b' * 32), throwsStateError);
    await expectLater(keys.clear(), throwsStateError);
    expect(keys.savedKey, 'a' * 32);
    expect(keys.restartRequired, isFalse);
    expect(keys.busy, isFalse);
    store.fail = false;
    await keys.save('b' * 32);
    final restarted = MapKeyController(store);
    await restarted.restore();
    expect(restarted.restartRequired, isFalse);
    expect(restarted.keyForMap(), 'b' * 32);
  });

  test('空白和错误格式不会写入，粘贴外层空格可去除', () async {
    final store = TestKeyStore();
    final keys = MapKeyController(store);
    await keys.restore();
    await expectLater(keys.save(''), throwsFormatException);
    await expectLater(keys.save('a b'), throwsFormatException);
    expect(store.value, isNull);
    await keys.save('  ${'c' * 32}  ');
    expect(keys.savedKey, 'c' * 32);
  });
  test('同进程引擎重建保留原生快照与待重启状态', () async {
    final store = TestKeyStore()..value = 'b' * 32;
    final keys = MapKeyController(store, readProcessKey: () async => 'a' * 32);
    await keys.restore();
    expect(keys.restartRequired, isTrue);
    expect(keys.keyForMap(), 'a' * 32);
    await keys.clear();
    final recreated = MapKeyController(
      store,
      readProcessKey: () async => 'a' * 32,
    );
    await recreated.restore();
    expect(recreated.available, isFalse);
    expect(recreated.restartRequired, isTrue);
  });

  test('读取失败可重试，恢复后可保存', () async {
    final store = TestKeyStore()..failRead = true;
    final keys = MapKeyController(store);
    await keys.restore();
    expect(keys.readFailed, isTrue);
    expect(keys.available, isFalse);
    store.failRead = false;
    await keys.restore();
    await keys.save('c' * 32);
    expect(keys.available, isTrue);
  });

  test('异步恢复完成前销毁控制器，不再发布通知', () async {
    final pending = Completer<String?>();
    final keys = MapKeyController(
      TestKeyStore(),
      readProcessKey: () => pending.future,
    );
    var notifications = 0;
    keys.addListener(() => notifications++);
    final restoring = keys.restore();
    keys.dispose();
    pending.complete(null);
    await restoring;
    expect(notifications, 0);
  });
  test('并发保存和清除互斥，后续操作可重试', () async {
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    final saving = keys.save('a' * 32);
    await expectLater(keys.clear(), throwsStateError);
    await saving;
    expect(keys.savedKey, 'a' * 32);
    await keys.clear();
    expect(keys.available, isFalse);
  });
}
