/// Human readable formatting helpers shared across the dashboard.
class Fmt {
  const Fmt._();

  /// Formats a byte count with binary units.
  static String bytes(num value, {int decimals = 1}) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var v = value.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final d = i == 0 ? 0 : decimals;
    return '${v.toStringAsFixed(d)} ${units[i]}';
  }

  /// Formats a transfer rate.
  static String rate(num bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${bytes(bytesPerSecond)}/s';
  }

  static String percent(double value, {int decimals = 0}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formats a duration given in seconds as "3d 4h" or "12m 30s".
  static String duration(int seconds) {
    if (seconds <= 0) return '—';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static String celsius(double value) => '${value.toStringAsFixed(0)}°C';

  static String clock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
