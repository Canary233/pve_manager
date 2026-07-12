import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/data/models/node_status.dart';

void main() {
  test('parses thermalstate numeric readings', () {
    final status = NodeStatus.fromJson({
      'thermalstate': {
        'Package id 0': {'temp1_input': 52.4, 'temp1_crit': 100},
        'Core 0': {'temp2_input': '47.8'},
      },
    });

    expect(status.thermalState.sensors, hasLength(2));
    expect(status.thermalState.hottest?.label, 'Package id 0');
    expect(status.thermalState.hottest?.celsius, 52.4);
    expect(
      status.thermalState.format(fallbackLabel: 'Temperature'),
      'Package id 0 52.4°C · Core 0 47.8°C',
    );
  });

  test('parses thermalstate sensors command text', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
coretemp-isa-0000
Package id 0:  +61.0°C  (high = +82.0°C, crit = +100.0°C)
Core 0:        +55.0°C  (high = +82.0°C, crit = +100.0°C)
              (crit = +100.0°C)
''',
    });

    expect(status.thermalState.sensors, hasLength(2));
    expect(status.thermalState.hottest?.label, 'Package id 0');
    expect(status.thermalState.hottest?.celsius, 61);
  });

  test('ignores empty and threshold-only thermalstate values', () {
    final status = NodeStatus.fromJson({
      'thermalstate': {
        'temp1_crit': 100,
        'fan1_input': 1200,
        'noise': 'not a temperature',
      },
    });

    expect(status.thermalState.isEmpty, isTrue);
    expect(status.thermalState.format(fallbackLabel: 'Temperature'), '-');
  });

  test('parses sysfs millidegree readings from command output', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
sysfs x86_pkg_temp: 57000
hwmon coretemp Package id 0: 62000
sysfs acpitz: 27800
sysfs bogus: 2000
''',
    });

    expect(status.thermalState.sensors, hasLength(3));
    expect(status.thermalState.hottest?.label, 'Package id 0');
    expect(status.thermalState.hottest?.source, 'hwmon coretemp');
    expect(status.thermalState.hottest?.celsius, 62);
  });

  test('groups cpu and disk temperatures for system info display', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +40.0°C  (high = +82.0°C, crit = +100.0°C)
Core 0:        +34.0°C  (high = +82.0°C, crit = +100.0°C)
Core 1:        +38.0°C  (high = +82.0°C, crit = +100.0°C)

nvme-pci-0200
Adapter: PCI adapter
Composite:    +37.9°C  (low  = -273.1°C, high = +84.8°C)
Sensor 1:     +37.9°C

nvme-pci-0300
Adapter: PCI adapter
Composite:    +42.0°C  (low  = -273.1°C, high = +84.8°C)

smartctl /dev/sda
194 Temperature_Celsius     0x0022   064   052   000    Old_age   Always       -       36 (Min/Max 23/44)
''',
    });

    expect(status.thermalState.cpuPackageSensor?.celsius, 40);
    expect(status.thermalState.cpuCoreSensors.map((sensor) => sensor.celsius), [
      38,
      34,
    ]);

    final disks = status.thermalState.diskTemperatures;
    expect(disks, hasLength(3));
    expect(disks[0].type, NodeDiskTemperatureType.nvme);
    expect(disks[0].index, 0);
    expect(disks[0].celsius, 37.9);
    expect(disks[1].type, NodeDiskTemperatureType.nvme);
    expect(disks[1].index, 1);
    expect(disks[1].celsius, 42);
    expect(disks[2].type, NodeDiskTemperatureType.sata);
    expect(disks[2].index, 0);
    expect(disks[2].celsius, 36);
  });

  test('parses sata smartctl drive temperature formats', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
smartctl /dev/sdb -d sat
Current Drive Temperature:     31 C
Drive Trip Temperature:        60 C

smartctl /dev/sdc
194 Temperature_Celsius     0x0022   070   050   000    Old_age   Always       -       28

drivetemp-scsi-0-0
Adapter: SCSI adapter
temp1:        +33.0°C
''',
    });

    final disks = status.thermalState.diskTemperatures;
    expect(disks, hasLength(3));
    expect(disks.map((disk) => disk.type), [
      NodeDiskTemperatureType.sata,
      NodeDiskTemperatureType.sata,
      NodeDiskTemperatureType.sata,
    ]);
    expect(disks.map((disk) => disk.celsius), [33, 31, 28]);
  });

  test('parses sata smartctl scan-open output from HomeCloud', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
smartctl /dev/sda -d sat
194 Temperature_Celsius     0x0022   065   053   000    Old_age   Always       -       35 (Min/Max 5/53)
244 Temp_Throttle_Status    0x0032   000   100   ---    Old_age   Always       -       0

smartctl /dev/sdb -d sat
194 Temperature_Celsius     0x0022   100   100   050    Old_age   Always       -       28

smartctl /dev/sdc -d sat
194 Temperature_Celsius     0x0032   100   100   050    Old_age   Always       -       40
''',
    });

    final disks = status.thermalState.diskTemperatures;
    expect(disks, hasLength(3));
    expect(disks.map((disk) => disk.type), [
      NodeDiskTemperatureType.sata,
      NodeDiskTemperatureType.sata,
      NodeDiskTemperatureType.sata,
    ]);
    expect(disks.map((disk) => disk.celsius), [35, 28, 40]);
  });

  test('keeps smartctl disk sources separated with terminal escapes', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
\x1B[0m\x1B[49msmartctl /dev/sda -d sat\x1B[K\r
194 Temperature_Celsius     0x0022   065   053   000    Old_age   Always       -       35
\x1B[2K\x1B[0msmartctl /dev/sdb -d sat\r
194 Temperature_Celsius     0x0022   100   100   050    Old_age   Always       -       28
\x1B[0msmartctl /dev/sdc -d sat
194 Temperature_Celsius     0x0032   100   100   050    Old_age   Always       -       40
''',
    });

    final disks = status.thermalState.diskTemperatures;
    expect(disks, hasLength(3));
    expect(disks.map((disk) => disk.source), [
      'smartctl /dev/sda -d sat',
      'smartctl /dev/sdb -d sat',
      'smartctl /dev/sdc -d sat',
    ]);
    expect(disks.map((disk) => disk.celsius), [35, 28, 40]);
  });

  test('binds smartctl disk models to temperatures', () {
    final status = NodeStatus.fromJson({
      'thermalstate': '''
smartctl /dev/nvme0 -d nvme
Model Number:                       HYV1TBX3(Pro)
Temperature:                        40 Celsius

smartctl /dev/nvme1 -d nvme
Model Number:                       HYV512X3(PRO)
Temperature:                        41 Celsius

smartctl /dev/sda -d sat
Device Model:     WDC WDS120G2G0A-00JH30
194 Temperature_Celsius     0x0022   065   053   000    Old_age   Always       -       33

smartctl /dev/sdb -d sat
Device Model:     NANASHI'S SSD 160G
194 Temperature_Celsius     0x0022   100   100   050    Old_age   Always       -       28
''',
    });

    final disks = status.thermalState.diskTemperatures;
    expect(disks, hasLength(4));
    expect(disks.map((disk) => disk.model), [
      'HYV1TBX3(Pro)',
      'HYV512X3(PRO)',
      'WDC WDS120G2G0A-00JH30',
      "NANASHI'S SSD 160G",
    ]);
    expect(disks.map((disk) => disk.celsius), [40, 41, 33, 28]);
  });

  test('does not classify smartctl readings as CPU Tctl sensors', () {
    final state = NodeThermalState.fromJson('''
coretemp-isa-0000
Package id 0: +48.0°C

smartctl /dev/nvme0 -d nvme
Temperature: 52 Celsius
''');

    expect(state.cpuPackageSensor?.celsius, 48);
    expect(state.cpuSensors, hasLength(1));
    expect(state.diskTemperatures.single.celsius, 52);
  });
}
