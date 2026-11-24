import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../ui/breakpoints.dart';
import '../campus/campus_page.dart';
import '../focus/focus_page.dart';
import '../home/home_page.dart';
import '../more/more_page.dart';
import '../schedule/schedule_page.dart';

/// 唯一外壳：窄屏底部导航，宽屏侧边导航；`IndexedStack` 保留各 Tab 状态。
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _index = 0;

  static const _destinations = [
    _Destination(S.tabHome, Icons.today_outlined, Icons.today_rounded),
    _Destination(S.tabSchedule, Icons.calendar_month_outlined,
        Icons.calendar_month_rounded),
    _Destination(S.tabFocus, Icons.timer_outlined, Icons.timer_rounded),
    _Destination(S.tabCampus, Icons.school_outlined, Icons.school_rounded),
    _Destination(S.tabMore, Icons.more_horiz_outlined, Icons.more_horiz_rounded),
  ];

  void _goToTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final pages = <Widget>[
      HomePage(onOpenTab: _goToTab),
      const SchedulePage(),
      const FocusPage(),
      const CampusPage(),
      MorePage(onOpenTab: _goToTab),
    ];

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _goToTab,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.8,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon, size: 22),
                    selectedIcon: Icon(d.selectedIcon, size: 22),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 0.6),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
