import 'package:mileaf/src/session.dart';

class MemorySessionStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String record) async {
    value = record;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
