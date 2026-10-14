import 'package:flutter/material.dart';

import '../models.dart';
import '../neon.dart';
import '../widgets.dart';

class HomeTab extends StatelessWidget {
  final CurrentUser me;
  final List<TipActivity> activities;
  final CreatorActions actions;
  final VoidCallback onExplore;

  const HomeTab({
    super.key,
    required this.me,
    required this.activities,
    required this.actions,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final live = creators.where((c) => c.isLive).toList();
    final successful = activities.where((a) => a.status == tipSuccess);
    final totalGiven = successful.fold(0.0, (sum, tip) => sum + tip.amount);

    return TabPage(
      children: [
        HeroBanner(userName: me.name, onExplore: onExplore),
        const SizedBox(height: 28),
        LiveNowSection(creators: live, actions: actions, onSeeAll: onExplore),
        const SizedBox(height: 28),
        const SectionHeading(
          title: 'Your overview',
          subtitle: 'Your support activity at a glance',
        ),
        const SizedBox(height: 14),
        StatGrid(
          cards: [
            StatCard(
              label: 'Tips recorded',
              value: '${activities.length}',
              detail: 'Tips processed by PaiFlow',
              icon: Icons.receipt_long_rounded,
              accent: Neon.purple,
            ),
            StatCard(
              label: 'Successful tips',
              value: '${successful.length}',
              detail: 'Verified payments',
              icon: Icons.verified_rounded,
              accent: Neon.cyan,
            ),
            StatCard(
              label: 'Total given',
              value: dollars(totalGiven),
              detail: 'Across all creators',
              icon: Icons.savings_rounded,
              accent: Neon.pink,
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeading(
          title: 'Featured creators',
          subtitle: 'Find someone whose content you enjoy',
          actionLabel: 'View all',
          onAction: onExplore,
        ),
        const SizedBox(height: 14),
        CreatorGrid(creators: creators.take(3).toList(), actions: actions),
      ],
    );
  }
}
