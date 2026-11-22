import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../charts/charts.dart';
import '../core/format.dart';
import '../core/palette.dart';
import '../models/models.dart';
import '../widgets/panel.dart';

/// A single statistic tile with a gauge, a label and a detail line.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.percent,
    required this.color,
    required this.icon,
    this.detail,
    this.gauge = true,
  });

  final String title;
  final String value;
  final String unit;
  final double percent;
  final Color color;
  final IconData icon;
  final String? detail;
  final bool gauge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(title, style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: Space.md),
          if (gauge)
            Center(
              child: RadialGauge(
                value: percent,
                color: color,
                label: value,
                caption: unit,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
                ),
                const SizedBox(width: 5),
                Text(unit, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Space.md),
            MeterBar(value: percent, color: color),
          ],
          if (detail != null) ...[
            const SizedBox(height: Space.md),
            Text(
              detail!,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// The main overview page: status, gauges and live charts.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.metrics, required this.history});

  final Metrics? metrics;
  final List<Metrics> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = metrics;

    final cpuSeries = history.map((e) => e.cpuPercent).toList();
    final memSeries = history
        .map((e) => e.memTotal == 0 ? 0.0 : e.memUsed / e.memTotal * 100)
        .toList();
    final rxSeries = history.map((e) => e.netRx.toDouble()).toList();
    final txSeries = history.map((e) => e.netTx.toDouble()).toList();

    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('概览', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                    m == null
                        ? '等待数据'
                        : '最近更新 ${Fmt.clock(m.collectedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (m != null)
              Row(
                children: [
                  _LiveBadge(label: '负载 ${m.load1.toStringAsFixed(2)}'),
                  const SizedBox(width: Space.sm),
                  if (m.tempC != null)
                    _LiveBadge(
                      label: Fmt.celsius(m.tempC!),
                      color: m.tempC! > 80 ? Palette.rust : Palette.moss,
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: Space.xl),

        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 1100
                ? 4
                : constraints.maxWidth > 700
                    ? 2
                    : 1;
            final gap = Space.lg;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            final tiles = <Widget>[
              StatTile(
                title: 'CPU',
                value: m == null ? '—' : m.cpuPercent.toStringAsFixed(0),
                unit: 'percent',
                percent: m?.cpuPercent ?? 0,
                color: Palette.moss,
                icon: LucideIcons.cpu,
                detail: m == null ? null : 'load ${m.load1.toStringAsFixed(2)}',
              ),
              StatTile(
                title: '内存',
                value: m == null ? '—' : Fmt.bytes(m.memUsed),
                unit: 'of ${m == null ? '' : Fmt.bytes(m.memTotal)}',
                percent: m?.memPercent ?? 0,
                color: Palette.water,
                icon: LucideIcons.memoryStick,
                detail: m == null ? null : '${m.memPercent.toStringAsFixed(1)}% 已用',
              ),
              StatTile(
                title: '磁盘',
                value: m == null ? '—' : Fmt.bytes(m.diskUsed),
                unit: 'of ${m == null ? '' : Fmt.bytes(m.diskTotal)}',
                percent: m?.diskPercent ?? 0,
                color: Palette.bark,
                icon: LucideIcons.hardDrive,
                detail: m == null ? null : '${m.diskPercent.toStringAsFixed(1)}% 已用',
              ),
              StatTile(
                title: '网络',
                value: m == null ? '—' : Fmt.rate(m.netRx + m.netTx),
                unit: 'down / up',
                percent: 0,
                color: Palette.clay,
                icon: LucideIcons.network,
                gauge: false,
                detail: m == null
                    ? null
                    : '↓ ${Fmt.rate(m.netRx)}   ↑ ${Fmt.rate(m.netTx)}',
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: tiles
                  .map((t) => SizedBox(width: width, child: t))
                  .toList(),
            );
          },
        ),

        const SizedBox(height: Space.lg),

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 860;
            final chart = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'CPU 使用率',
                    icon: LucideIcons.activity,
                    subtitle: '最近 ${history.length} 个采样',
                  ),
                  const SizedBox(height: Space.md),
                  SparklineChart(
                    values: cpuSeries,
                    color: Palette.moss,
                    height: 150,
                  ),
                ],
              ),
            );

            final memChart = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: '内存使用率',
                    icon: LucideIcons.memoryStick,
                    subtitle: '百分比',
                  ),
                  const SizedBox(height: Space.md),
                  SparklineChart(
                    values: memSeries,
                    color: Palette.water,
                    height: 150,
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: Space.lg),
                  Expanded(child: memChart),
                ],
              );
            }
            return Column(
              children: [chart, const SizedBox(height: Space.lg), memChart],
            );
          },
        ),

        const SizedBox(height: Space.lg),

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 860;
            final down = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: '下行流量',
                    icon: LucideIcons.arrowDown,
                    subtitle: 'bytes/s',
                  ),
                  const SizedBox(height: Space.md),
                  SparklineChart(
                    values: rxSeries,
                    color: Palette.clay,
                    height: 130,
                  ),
                ],
              ),
            );

            final up = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: '上行流量',
                    icon: LucideIcons.arrowUp,
                    subtitle: 'bytes/s',
                  ),
                  const SizedBox(height: Space.md),
                  SparklineChart(
                    values: txSeries,
                    color: Palette.sage,
                    height: 130,
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: down),
                  const SizedBox(width: Space.lg),
                  Expanded(child: up),
                ],
              );
            }
            return Column(
              children: [down, const SizedBox(height: Space.lg), up],
            );
          },
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? Palette.moss;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Space.rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}
