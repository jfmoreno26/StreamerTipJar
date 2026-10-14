import 'package:flutter/material.dart';

import '../models.dart';
import '../neon.dart';
import '../widgets.dart';

class DiscoverTab extends StatefulWidget {
  final CreatorActions actions;
  final int followingCount;

  const DiscoverTab({
    super.key,
    required this.actions,
    required this.followingCount,
  });

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  static const _all = 'All';
  static const _following = 'Following';

  final _search = TextEditingController();
  String _query = '';
  String _category = _all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = _all;
    });
  }

  bool _matches(Creator creator) {
    final query = _query.toLowerCase();
    final matchesSearch = [
      creator.name,
      creator.username,
      creator.category,
    ].any((field) => field.toLowerCase().contains(query));

    final matchesCategory = switch (_category) {
      _all => true,
      _following => widget.actions.isFollowing(creator),
      final category => creator.category == category,
    };

    return matchesSearch && matchesCategory;
  }

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final categories = [
      _all,
      _following,
      ...{for (final creator in creators) creator.category},
    ];
    final results = creators.where(_matches).toList()
      ..sort((a, b) => (b.isLive ? 1 : 0) - (a.isLive ? 1 : 0));
    final followingNobody =
        _category == _following && widget.followingCount == 0;

    return TabPage(
      children: [
        const SectionHeading(
          title: 'Discover creators',
          subtitle: 'Explore creators and support their work',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by creator, @handle or category',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              ChoiceChip(
                label: Text(
                  category == _following
                      ? '$_following (${widget.followingCount})'
                      : category,
                ),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          results.length == 1
              ? '1 creator found'
              : '${results.length} creators found',
          style: TextStyle(fontWeight: FontWeight.w700, color: c.muted),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          EmptyState(
            icon: followingNobody
                ? Icons.group_add_rounded
                : Icons.search_off_rounded,
            title: followingNobody
                ? 'You\'re not following anyone yet'
                : 'No creators found',
            description: followingNobody
                ? 'Tap Follow on a creator to keep them here.'
                : 'Try another name or category.',
            actionLabel: 'Clear filters',
            onAction: _clearFilters,
          )
        else
          CreatorGrid(creators: results, actions: widget.actions),
      ],
    );
  }
}
