import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/data/models/pve_resource.dart';

void main() {
  test('uses the PVE storage id as the storage resource name', () {
    final resource = PveResource.fromJson({
      'id': 'storage/HomeCloud/local-lvm',
      'type': 'storage',
      'storage': 'local-lvm',
      'node': 'HomeCloud',
      'disk': 1024,
      'maxdisk': 2048,
    });

    expect(resource.name, 'local-lvm');
  });

  test('derives a storage name from the resource id when needed', () {
    final resource = PveResource.fromJson({
      'id': 'storage/HomeCloud/local',
      'type': 'storage',
      'node': 'HomeCloud',
    });

    expect(resource.name, 'local');
  });
}
