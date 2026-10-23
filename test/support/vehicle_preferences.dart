import 'package:mileaf/src/workspace.dart';

class MemoryVehiclePreferences implements VehiclePreferenceStore {
  final values = <String, int>{};
  @override
  Future<int?> read(String site) async => values[site];
  @override
  Future<void> write(String site, int id) async {
    values[site] = id;
  }
}
