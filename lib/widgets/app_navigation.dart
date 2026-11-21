import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/app_tokens.dart';
import 'brand_mark.dart';
import 'tappable.dart';

/// One place the app can go.
///
/// Every destination uses one icon, from the Lucide set, whether or not it is
/// the current one. The current one is shown by colour and a faint fill, not by
/// swapping to a heavier drawing, so the four icons always have the same
/// weight.
class AppDestination {
  const AppDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The four tabs, in order. The same list feeds the sidebar, the rail and the
/// bottom bar, so they can never disagree.
const List<AppDestination> appDestinations = [
  AppDestination(label: 'Home', icon: LucideIcons.house),
  AppDestination(label: 'Insights', icon: LucideIcons.chartNoAxesCombined),
  AppDestination(label: 'Watchlist', icon: LucideIcons.eye),
  AppDestination(label: 'Settings', icon: LucideIcons.settings2),
];

/// Index of the Watchlist tab, which carries the "new breaches" count.
const int watchlistDestinationIndex = 2;

/// The size of every navigation icon, in the sidebar, the rail and the bar.
const double navIconSize = 20;

String _newBreachesLabel(int count) => '$count new ${count == 1 ? 'breach' : 'breaches'}';

/// The colour of a navigation item's icon and label: blue for the current one,
/// muted grey for the rest.
Color _navColor(bool selected) => selected ? AppColors.accent : AppColors.textSecondary;

/// The sidebar's label: 14px, medium weight, in both states.
TextStyle? _sidebarLabel(BuildContext context, Color color) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

/// Navigation for wide windows: the logo, then a labelled row per tab.
///
/// Rows are 46px tall with a 12px gap between icon and label, 10px from the
/// sidebar's edges, with 10px corners. The current row has a faint blue fill
/// and blue icon and label; the others are grey and get a faint lightening
/// under the pointer.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.newBreaches,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int newBreaches;

  /// The gap between the sidebar's edge and its rows.
  static const double edgePadding = 10;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.sidebarWidth,
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The logo's left edge lines up with the icons below it: the
            // sidebar's padding plus the rows' own.
            const Padding(
              padding: EdgeInsets.fromLTRB(edgePadding + AppSpacing.md, 22, edgePadding, 18),
              child: Align(alignment: Alignment.centerLeft, child: BrandMark()),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: edgePadding),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'Main navigation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < appDestinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _SidebarRow(
                            destination: appDestinations[i],
                            selected: i == selectedIndex,
                            count: i == watchlistDestinationIndex ? newBreaches : 0,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.destination,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _navColor(selected);

    return Semantics(
      button: true,
      selected: selected,
      child: Tappable(
        onTap: onTap,
        borderRadius: AppRadii.rowAll,
        color: selected ? AppColors.navSelected : Colors.transparent,
        child: ConstrainedBox(
          // At least 46 tall; taller if the text size asks for it.
          constraints: const BoxConstraints(minHeight: AppSizes.navRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(destination.icon, size: navIconSize, color: color)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(destination.label, style: _sidebarLabel(context, color))),
                if (count > 0) _CountBadge(count),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation for mid-sized windows: the logo, then an icon over a short
/// label per tab, drawn in the same colours and corners as the sidebar.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.newBreaches,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int newBreaches;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.railWidth,
      child: ColoredBox(
        color: AppColors.surface,
        // The rail is narrow, so its labels grow only a little with the
        // system text size. Each item also has a tooltip with the full name.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSidebar.edgePadding,
            ),
            child: Column(
              children: [
                const BrandMark(showName: false, size: 30),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'Main navigation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < appDestinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _RailItem(
                            destination: appDestinations[i],
                            selected: i == selectedIndex,
                            count: i == watchlistDestinationIndex ? newBreaches : 0,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _navColor(selected);

    return Tooltip(
      message: destination.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        child: Tappable(
          onTap: onTap,
          borderRadius: AppRadii.rowAll,
          color: selected ? AppColors.navSelected : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.navRowHeight + AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ExcludeSemantics(
                        child: Icon(destination.icon, size: navIconSize, color: color),
                      ),
                      if (count > 0) Positioned(top: -6, right: -14, child: _CountBadge(count)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation for phones: Material's bottom bar, styled by the theme.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.newBreaches,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int newBreaches;

  @override
  Widget build(BuildContext context) {
    Widget icon(int index) {
      final drawing = Icon(appDestinations[index].icon);
      if (index != watchlistDestinationIndex) return drawing;
      return Badge(
        isLabelVisible: newBreaches > 0,
        label: Text('$newBreaches', semanticsLabel: _newBreachesLabel(newBreaches)),
        child: drawing,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (var i = 0; i < appDestinations.length; i++)
            NavigationDestination(icon: icon(i), label: appDestinations[i].label),
        ],
      ),
    );
  }
}

/// The count of unacknowledged new breaches, beside the Watchlist item.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _newBreachesLabel(count),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.danger, borderRadius: AppRadii.tagAll),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0,
                    color: AppColors.background,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
