import 'package:mileaf/src/map/map_key.dart';

class TestKeyStore implements MapKeyStore {
  String? value;
  bool fail = false;
  bool failRead = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write(String? key) async {
    if (fail) throw StateError('storage unavailable');
    value = key;
  }
}

Future<MapKeyController> configuredMapKeys() async {
  final keys = MapKeyController(TestKeyStore()..value = 'a' * 32);
  await keys.restore();
  return keys;
}
