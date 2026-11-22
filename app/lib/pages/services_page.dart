import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../charts/charts.dart';
import '../core/palette.dart';
import '../models/models.dart';
import '../widgets/panel.dart';

/// Lists the running containers with controls to start and stop them.
class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.services,
    required this.onAction,
    this.pendingId,
  });

  final List<Service> services;
  final void Function(Service service, String action) onAction;
  final String? pendingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Text('服务与容器', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          '${services.length} 个容器 · ${services.where((s) => s.isRunning).length} 个运行中',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Space.xl),
        if (services.isEmpty)
          Panel(
            child: EmptyState(
              message: '没有找到容器',
              icon: LucideIcons.container,
            ),
          )
        else
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  _ServiceRow(
                    service: services[i],
                    pending: pendingId == services[i].id,
                    onAction: onAction,
                  ),
                  if (i != services.length - 1)
                    Divider(height: 1, color: theme.dividerColor),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.pending,
    required this.onAction,
  });

  final Service service;
  final bool pending;
  final void Function(Service service, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = service.isRunning;
    final statusColor = running ? Palette.healthy : Palette.idle;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Space.rSm),
            ),
            child: Icon(
              LucideIcons.container,
              size: 15,
              color: statusColor,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  service.image,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (service.ports.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(
                service.ports,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(width: Space.md),
          StatusChip(
            label: running ? '运行中' : service.state,
            color: statusColor,
            dense: true,
          ),
          const SizedBox(width: Space.md),
          SizedBox(
            width: 74,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (pending)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                else ...[
                  IconButton(
                    tooltip: running ? '停止' : '启动',
                    iconSize: 15,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAction(
                      service,
                      running ? 'stop' : 'start',
                    ),
                    icon: Icon(
                      running ? LucideIcons.circleStop : LucideIcons.circlePlay,
                    ),
                  ),
                  IconButton(
                    tooltip: '重启',
                    iconSize: 15,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAction(service, 'restart'),
                    icon: const Icon(LucideIcons.rotateCcw),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Storage overview with per volume usage.
class StoragePage extends StatelessWidget {
  const StoragePage({super.key, required this.volumes, required this.disks});

  final List<Volume> volumes;
  final List<Disk> disks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = volumes.fold<int>(0, (s, v) => s + v.total);
    final used = volumes.fold<int>(0, (s, v) => s + v.used);

    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Text('存储', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          '${Fmt.bytes(used)} 已用 / ${Fmt.bytes(total)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Space.xl),

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '容量分布',
                icon: LucideIcons.hardDrive,
              ),
              const SizedBox(height: Space.lg),
              SegmentedBar(
                segments: [
                  (color: Palette.moss, value: used.toDouble()),
                  (color: Palette.canvasDeep, value: (total - used).toDouble()),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  _LegendDot(color: Palette.moss, label: '已用'),
                  const SizedBox(width: Space.lg),
                  _LegendDot(color: Palette.canvasDeep, label: '可用'),
                  const Spacer(),
                  Text(
                    total == 0
                        ? '—'
                        : '${(used / total * 100).toStringAsFixed(1)}% 已用',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: Space.lg),

        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < volumes.length; i++) ...[
                _VolumeRow(volume: volumes[i]),
                if (i != volumes.length - 1)
                  Divider(height: 1, color: theme.dividerColor),
              ],
              if (volumes.isEmpty)
                const EmptyState(message: '没有挂载的卷', icon: LucideIcons.hardDrive),
            ],
          ),
        ),

        if (disks.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < disks.length; i++) ...[
                  _DiskRow(disk: disks[i]),
                  if (i != disks.length - 1)
                    Divider(height: 1, color: theme.dividerColor),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.volume});

  final Volume volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _usageColor(volume.percent);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.hardDrive, size: 13, color: color),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  volume.mountpoint,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${Fmt.bytes(volume.used)} / ${Fmt.bytes(volume.total)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: Space.md),
              SizedBox(
                width: 46,
                child: Text(
                  '${volume.percent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          MeterBar(value: volume.percent, color: color, height: 5),
          const SizedBox(height: 4),
          Text(
            '${volume.device}  ·  ${volume.fsType}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DiskRow extends StatelessWidget {
  const _DiskRow({required this.disk});

  final Disk disk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthy = disk.smartOk || disk.health.toLowerCase() == 'passed';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.hardDrive,
            size: 14,
            color: healthy ? Palette.healthy : Palette.inkFaint,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(disk.model, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${disk.name} · ${Fmt.bytes(disk.size)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (disk.temperature != null) ...[
            Icon(
              LucideIcons.thermometer,
              size: 12,
              color: Palette.inkFaint,
            ),
            const SizedBox(width: 4),
            Text(
              Fmt.celsius(disk.temperature!),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: Space.lg),
          ],
          StatusChip(
            label: disk.health == 'unknown' ? '未检测' : disk.health,
            color: healthy ? Palette.healthy : Palette.idle,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Hardware sensors: temperatures and fan speeds.
class HardwarePage extends StatelessWidget {
  const HardwarePage({super.key, required this.sensors});

  final Sensors sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Text('硬件', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          '${sensors.temperatures.length} 个温度传感器 · ${sensors.fans.length} 个风扇',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Space.xl),

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 860;
            final temps = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: '温度',
                    icon: LucideIcons.thermometer,
                  ),
                  const SizedBox(height: Space.md),
                  if (sensors.temperatures.isEmpty)
                    const EmptyState(message: '没有可读的温度传感器')
                  else
                    for (final t in sensors.temperatures)
                      _SensorRow(
                        name: t.name,
                        value: t.value,
                        max: t.critical > 0 && t.critical < 200
                            ? t.critical
                            : t.high > 0 && t.high < 200
                                ? t.high
                                : 100,
                        unit: '°C',
                      ),
                ],
              ),
            );

            final fans = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: '风扇',
                    icon: LucideIcons.wind,
                  ),
                  const SizedBox(height: Space.md),
                  if (sensors.fans.isEmpty)
                    const EmptyState(message: '没有可读的风扇转速')
                  else
                    for (final f in sensors.fans)
                      _SensorRow(
                        name: f.name,
                        value: f.speedRpm,
                        max: 6000,
                        unit: 'RPM',
                      ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: temps),
                  const SizedBox(width: Space.lg),
                  Expanded(child: fans),
                ],
              );
            }
            return Column(
              children: [temps, const SizedBox(height: Space.lg), fans],
            );
          },
        ),
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.name,
    required this.value,
    required this.max,
    required this.unit,
  });

  final String name;
  final double value;
  final double max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = max <= 0 ? 0.0 : (value / max * 100).clamp(0, 100).toDouble();
    final color = _usageColor(pct);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)} $unit',
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 5),
          MeterBar(value: pct, color: color, height: 4),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// Picks a colour that shifts from moss to clay as usage climbs.
Color _usageColor(double percent) {
  if (percent >= 90) return Palette.rust;
  if (percent >= 75) return Palette.amber;
  if (percent >= 50) return Palette.clay;
  return Palette.moss;
}
