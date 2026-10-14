import 'package:flutter/material.dart';

import '../models.dart';
import '../neon.dart';
import '../widgets.dart';

class ActivityTab extends StatefulWidget {
  final List<TipActivity> activities;
  final bool loading;
  final bool failed;
  final double Function(String creatorName) tippedTo;
  final VoidCallback onFindCreator;
  final ValueChanged<Uri> onOpenLink;

  const ActivityTab({
    super.key,
    required this.activities,
    required this.loading,
    required this.failed,
    required this.tippedTo,
    required this.onFindCreator,
    required this.onOpenLink,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  static const _all = 'All';
  static const _filters = [_all, tipSuccess, tipPending, tipFailed];

  String _filter = _all;

  int _countFor(String filter) => filter == _all
      ? widget.activities.length
      : widget.activities.where((a) => a.status == filter).length;

  @override
  Widget build(BuildContext context) {
    final activities = widget.activities;
    final visible = activities.reversed
        .where((a) => _filter == _all || a.status == _filter)
        .toList();
    final byDay = <String, List<TipActivity>>{};
    for (final tip in visible) {
      byDay.putIfAbsent(dayLabel(tip.date), () => []).add(tip);
    }

    return TabPage(
      children: [
        const SectionHeading(
          title: 'Activity',
          subtitle: 'Your tips and the supporter ranks you earned',
        ),
        const SizedBox(height: 16),
        if (activities.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _filters)
                ChoiceChip(
                  label: Text('$filter (${_countFor(filter)})'),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        ..._body(visible, byDay),
      ],
    );
  }

  List<Widget> _body(
    List<TipActivity> visible,
    Map<String, List<TipActivity>> byDay,
  ) {
    if (widget.failed) {
      return const [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load your activity',
          description: 'Check your connection. Your tips will appear as soon as JarJar reconnects.',
        ),
      ];
    }
    if (widget.loading) return const [SkeletonList()];
    if (widget.activities.isEmpty) {
      return [
        EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'No activity yet',
          description: 'Tips you send through PaiFlow will appear here.',
          actionLabel: 'Find a creator',
          onAction: widget.onFindCreator,
        ),
      ];
    }
    if (visible.isEmpty) {
      return [
        EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'No ${_filter.toLowerCase()} tips',
          description: 'Try another filter.',
          actionLabel: 'Show all',
          onAction: () => setState(() => _filter = _all),
        ),
      ];
    }

    return [
      for (final MapEntry(key: day, value: tips) in byDay.entries) ...[
        _DayHeader(label: day),
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TipTile(
              tip: tip,
              rank: SupporterRank.getRankForAmount(
                widget.tippedTo(tip.creator),
              ),
              onTap: switch (tip.explorerUrl) {
                final Uri url => () => widget.onOpenLink(url),
                null => null,
              },
            ),
          ),
      ],
    ];
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: NeonColors.of(context).muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
