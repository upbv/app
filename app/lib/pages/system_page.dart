import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/palette.dart';
import '../models/models.dart';
import '../widgets/panel.dart';

/// Host details plus the connection settings for the backend.
class SystemPage extends StatelessWidget {
  const SystemPage({
    super.key,
    required this.host,
    required this.apiBaseUrl,
    required this.online,
    required this.onBaseUrlChanged,
    this.error,
  });

  final HostInfo? host;
  final String apiBaseUrl;
  final bool online;
  final ValueChanged<String> onBaseUrlChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = host;

    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Text('系统', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          online ? '已连接' : '未连接',
          style: theme.textTheme.bodySmall?.copyWith(
            color: online ? Palette.healthy : Palette.danger,
          ),
        ),
        const SizedBox(height: Space.xl),

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: '主机信息',
                icon: LucideIcons.server,
              ),
              const SizedBox(height: Space.md),
              if (h == null)
                const EmptyState(message: '尚未获取主机信息')
              else ...[
                _InfoRow(label: '主机名', value: h.hostname),
                _InfoRow(label: '系统', value: h.osName),
                _InfoRow(label: '内核', value: h.kernel),
                _InfoRow(label: '架构', value: h.arch),
                _InfoRow(label: '运行时长', value: Fmt.duration(h.uptimeSeconds)),
                _InfoRow(
                  label: '启动时间',
                  value: h.bootTime == null
                      ? '—'
                      : '${h.bootTime!.year}-${_two(h.bootTime!.month)}-${_two(h.bootTime!.day)} '
                          '${_two(h.bootTime!.hour)}:${_two(h.bootTime!.minute)}',
                ),
                _InfoRow(
                  label: '虚拟化',
                  value: h.virtualized ? '是' : '否',
                ),
                _InfoRow(
                  label: '容器内',
                  value: h.containerized ? '是' : '否',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: Space.lg),

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: '后端连接',
                icon: LucideIcons.plug,
              ),
              const SizedBox(height: Space.md),
              _ApiUrlField(
                value: apiBaseUrl,
                onApply: onBaseUrlChanged,
              ),
              const SizedBox(height: Space.sm),
              Text(
                '修改后会自动重新连接并刷新数据',
                style: theme.textTheme.bodySmall,
              ),
              if (error != null) ...[
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: Palette.danger,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Palette.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Editable backend URL that keeps its own controller so the field stays in
/// sync when the address changes elsewhere.
class _ApiUrlField extends StatefulWidget {
  const _ApiUrlField({required this.value, required this.onApply});

  final String value;
  final ValueChanged<String> onApply;

  @override
  State<_ApiUrlField> createState() => _ApiUrlFieldState();
}

class _ApiUrlFieldState extends State<_ApiUrlField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_ApiUrlField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() => widget.onApply(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? Palette.darkSurfaceAlt
            : Palette.canvasDeep,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.rSm),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: '应用',
          iconSize: 16,
          onPressed: _apply,
          icon: const Icon(LucideIcons.check),
        ),
      ),
      onSubmitted: (_) => _apply(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.titleSmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
