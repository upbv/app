import 'package:material_ui/material_ui.dart';

import '../core/palette.dart';

/// Traffic light window buttons, styled after the macOS title bar.
class TrafficLights extends StatelessWidget {
  const TrafficLights({super.key, this.onClose, this.onMinimize, this.onMaximize});

  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Light(color: const Color(0xFFFF5F57), onTap: onClose),
        const SizedBox(width: 8),
        _Light(color: const Color(0xFFFFBD2E), onTap: onMinimize),
        const SizedBox(width: 8),
        _Light(color: const Color(0xFF28C840), onTap: onMaximize),
      ],
    );
  }
}

class _Light extends StatelessWidget {
  const _Light({required this.color, this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// The draggable title bar that sits above the content area.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onClose,
    this.onMinimize,
    this.onMaximize,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: Space.titleBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurface : Palette.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Palette.darkHairline : Palette.hairline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          TrafficLights(
            onClose: onClose,
            onMinimize: onMinimize,
            onMaximize: onMaximize,
          ),
          const SizedBox(width: Space.lg),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Space.md),
          ],
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: Space.sm),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// The vertical navigation rail on the left of the window.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.footer,
    this.width = Space.sidebarWidth,
  });

  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurface : Palette.surfaceAlt,
        border: Border(
          right: BorderSide(
            color: isDark ? Palette.darkHairline : Palette.hairline,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.md),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _SidebarTile(
              item: item,
              selected: index == selectedIndex,
              onTap: () => onSelect(index),
            );
          }),
          const Spacer(),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: footer,
            ),
          ],
        ],
      ),
    );
  }
}

/// One entry in the sidebar.
class SidebarItem {
  const SidebarItem({
    required this.label,
    required this.icon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String? badge;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: 1,
      ),
      child: Material(
        color: selected
            ? (isDark ? Palette.darkSurfaceAlt : Palette.lichen)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Space.rSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Space.rSm),
          hoverColor: (isDark ? Colors.white : Palette.ink)
              .withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 7,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 15,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? theme.textTheme.titleSmall?.color
                          : theme.textTheme.bodyMedium?.color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.badge != null)
                  Text(
                    item.badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
