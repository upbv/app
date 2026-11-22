import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/palette.dart';
import 'core/theme.dart';

import 'pages/overview_page.dart';
import 'pages/services_page.dart';
import 'pages/system_page.dart';
import 'services/dashboard_controller.dart';
import 'widgets/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashboardApp());
}

/// Root of the dashboard application.
class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  final DashboardController _controller = DashboardController();
  ThemeMode _themeMode = ThemeMode.light;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemUi.apply(_themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      SystemUi.apply(
        _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Dashboard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          home: _Shell(
            controller: _controller,
            selectedIndex: _selectedIndex,
            themeMode: _themeMode,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onToggleTheme: _toggleTheme,
          ),
        );
      },
    );
  }
}

/// The window chrome: title bar on top, sidebar on the left, page in the middle.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.controller,
    required this.selectedIndex,
    required this.themeMode,
    required this.onSelect,
    required this.onToggleTheme,
  });

  final DashboardController controller;
  final int selectedIndex;
  final ThemeMode themeMode;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = <SidebarItem>[
      SidebarItem(label: '概览', icon: LucideIcons.layoutDashboard),
      SidebarItem(
        label: '服务',
        icon: LucideIcons.container,
        badge: controller.services.isEmpty
            ? null
            : '${controller.services.where((s) => s.isRunning).length}',
      ),
      SidebarItem(label: '存储', icon: LucideIcons.hardDrive),
      SidebarItem(label: '硬件', icon: LucideIcons.gauge),
      SidebarItem(label: '系统', icon: LucideIcons.server),
    ];

    return Scaffold(
      body: Column(
        children: [
          TitleBar(
            title: 'Dashboard',
            subtitle: controller.metrics?.host ?? '',
            leading: Row(
              children: [
                Icon(
                  LucideIcons.leaf,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            actions: [
              _StatusDot(online: controller.online),
              const SizedBox(width: Space.md),
              IconButton(
                tooltip: themeMode == ThemeMode.light ? '深色' : '浅色',
                iconSize: 15,
                visualDensity: VisualDensity.compact,
                onPressed: onToggleTheme,
                icon: Icon(
                  themeMode == ThemeMode.light
                      ? LucideIcons.moon
                      : LucideIcons.sun,
                ),
              ),
              IconButton(
                tooltip: '刷新',
                iconSize: 15,
                visualDensity: VisualDensity.compact,
                onPressed: controller.busy ? null : controller.refreshAll,
                icon: controller.busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : const Icon(LucideIcons.refreshCw),
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  items: items,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  footer: _SidebarFooter(
                    isDark: isDark,
                    online: controller.online,
                    baseUrl: controller.apiBaseUrl,
                  ),
                ),
                Expanded(
                  child: Container(
                    color: isDark ? Palette.darkCanvas : Palette.canvas,
                    child: _page(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page() {
    switch (selectedIndex) {
      case 1:
        return ServicesPage(
          services: controller.services,
          onAction: controller.runServiceAction,
        );
      case 2:
        return StoragePage(
          volumes: controller.volumes,
          disks: controller.disks,
        );
      case 3:
        return HardwarePage(sensors: controller.sensors);
      case 4:
        return SystemPage(
          host: controller.host,
          apiBaseUrl: controller.apiBaseUrl,
          online: controller.online,
          onBaseUrlChanged: controller.setBaseUrl,
          error: controller.error,
        );
      default:
        return OverviewPage(
          metrics: controller.metrics,
          history: controller.history,
        );
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = online ? Palette.healthy : Palette.danger;

    return Tooltip(
      message: online ? '实时连接正常' : '实时连接断开',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            online ? '实时' : '离线',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.isDark,
    required this.online,
    required this.baseUrl,
  });

  final bool isDark;
  final bool online;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceAlt : Palette.canvasDeep,
        borderRadius: BorderRadius.circular(Space.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.plug,
                size: 11,
                color: online ? Palette.healthy : Palette.danger,
              ),
              const SizedBox(width: 5),
              Text(
                '后端',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            baseUrl.replaceFirst(RegExp(r'^https?://'), ''),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
