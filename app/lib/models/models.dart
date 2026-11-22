/// Data models mirroring the JSON produced by the Go backend.
library;

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class Metrics {
  const Metrics({
    required this.host,
    required this.collectedAt,
    required this.cpuPercent,
    required this.load1,
    required this.memUsed,
    required this.memTotal,
    required this.diskUsed,
    required this.diskTotal,
    required this.netRx,
    required this.netTx,
    this.tempC,
  });

  final String host;
  final DateTime collectedAt;
  final double cpuPercent;
  final double load1;
  final int memUsed;
  final int memTotal;
  final int diskUsed;
  final int diskTotal;
  final int netRx;
  final int netTx;
  final double? tempC;

  double get memPercent => memTotal == 0 ? 0 : memUsed / memTotal * 100;
  double get diskPercent => diskTotal == 0 ? 0 : diskUsed / diskTotal * 100;

  factory Metrics.fromJson(Map<String, dynamic> json) => Metrics(
        host: json['host'] as String? ?? '',
        collectedAt:
            DateTime.tryParse(json['collectedAt'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        cpuPercent: _toDouble(json['cpuPercent']),
        load1: _toDouble(json['load1']),
        memUsed: _toInt(json['memUsed']),
        memTotal: _toInt(json['memTotal']),
        diskUsed: _toInt(json['diskUsed']),
        diskTotal: _toInt(json['diskTotal']),
        netRx: _toInt(json['netRx']),
        netTx: _toInt(json['netTx']),
        tempC: json['tempC'] == null ? null : _toDouble(json['tempC']),
      );
}

class HostInfo {
  const HostInfo({
    required this.host,
    required this.osName,
    required this.arch,
    required this.kernel,
    required this.uptimeSeconds,
    required this.bootTime,
    required this.hostname,
    required this.virtualized,
    required this.containerized,
  });

  final String host;
  final String osName;
  final String arch;
  final String kernel;
  final int uptimeSeconds;
  final DateTime? bootTime;
  final String hostname;
  final bool virtualized;
  final bool containerized;

  factory HostInfo.fromJson(Map<String, dynamic> json) => HostInfo(
        host: json['host'] as String? ?? '',
        osName: json['osName'] as String? ?? '',
        arch: json['arch'] as String? ?? '',
        kernel: json['kernel'] as String? ?? '',
        uptimeSeconds: _toInt(json['uptimeSeconds']),
        bootTime:
            DateTime.tryParse(json['bootTime'] as String? ?? '')?.toLocal(),
        hostname: json['hostname'] as String? ?? '',
        virtualized: json['virtualized'] as bool? ?? false,
        containerized: json['containerized'] as bool? ?? false,
      );
}

class Volume {
  const Volume({
    required this.mountpoint,
    required this.device,
    required this.fsType,
    required this.total,
    required this.used,
    required this.free,
  });

  final String mountpoint;
  final String device;
  final String fsType;
  final int total;
  final int used;
  final int free;

  double get percent => total == 0 ? 0 : used / total * 100;

  factory Volume.fromJson(Map<String, dynamic> json) => Volume(
        mountpoint: json['mountpoint'] as String? ?? '',
        device: json['device'] as String? ?? '',
        fsType: json['fsType'] as String? ?? '',
        total: _toInt(json['total']),
        used: _toInt(json['used']),
        free: _toInt(json['free']),
      );
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.ports,
    this.startedAt,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String ports;
  final DateTime? startedAt;

  bool get isRunning => state == 'running';

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        state: json['state'] as String? ?? 'unknown',
        status: json['status'] as String? ?? '',
        ports: json['ports'] as String? ?? '',
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal(),
      );
}

class Disk {
  const Disk({
    required this.name,
    required this.model,
    required this.serial,
    required this.size,
    required this.health,
    required this.smartOk,
    required this.mountpoint,
    required this.rotational,
    this.temperature,
  });

  final String name;
  final String model;
  final String serial;
  final int size;
  final String health;
  final bool smartOk;
  final String mountpoint;
  final bool rotational;
  final double? temperature;

  factory Disk.fromJson(Map<String, dynamic> json) => Disk(
        name: json['name'] as String? ?? '',
        model: json['model'] as String? ?? '',
        serial: json['serial'] as String? ?? '',
        size: _toInt(json['size']),
        health: json['health'] as String? ?? 'unknown',
        smartOk: json['smartOk'] as bool? ?? false,
        mountpoint: json['mountpoint'] as String? ?? '',
        rotational: json['rotational'] as bool? ?? false,
        temperature:
            json['temperature'] == null ? null : _toDouble(json['temperature']),
      );
}

class Temperature {
  const Temperature({
    required this.name,
    required this.value,
    required this.high,
    required this.critical,
  });

  final String name;
  final double value;
  final double high;
  final double critical;

  factory Temperature.fromJson(Map<String, dynamic> json) => Temperature(
        name: json['name'] as String? ?? '',
        value: _toDouble(json['value']),
        high: _toDouble(json['high']),
        critical: _toDouble(json['critical']),
      );
}

class Fan {
  const Fan({required this.name, required this.speedRpm});

  final String name;
  final double speedRpm;

  factory Fan.fromJson(Map<String, dynamic> json) => Fan(
        name: json['name'] as String? ?? '',
        speedRpm: _toDouble(json['speedRpm']),
      );
}

class Sensors {
  const Sensors({required this.temperatures, required this.fans});

  final List<Temperature> temperatures;
  final List<Fan> fans;

  factory Sensors.fromJson(Map<String, dynamic> json) => Sensors(
        temperatures: (json['temperatures'] as List<dynamic>? ?? [])
            .map((e) => Temperature.fromJson(e as Map<String, dynamic>))
            .toList(),
        fans: (json['fans'] as List<dynamic>? ?? [])
            .map((e) => Fan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
