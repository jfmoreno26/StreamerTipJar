import 'package:flutter/material.dart';

import 'models.dart';
import 'neon.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const ThemeToggleButton({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => onThemeChanged(!isDarkMode),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(isDarkMode),
        ),
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  final String userName;
  final VoidCallback onExplore;

  const HeroBanner({
    super.key,
    required this.userName,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final glow = NeonColors.of(context).glow;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Neon.purple.withValues(alpha: 0.4 * glow),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final planetSize = narrow ? 200.0 : 320.0;
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C0B4A), Color(0xFF5B21B6), Neon.pink],
                  stops: [0, 0.55, 1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: narrow ? -70 : -30,
                    bottom: narrow ? -80 : -90,
                    width: planetSize,
                    height: planetSize,
                    child: const CustomPaint(painter: PlanetPainter()),
                  ),
                  const Positioned.fill(
                    child: TwinkleField(
                      points: [
                        Offset(0.06, 0.16),
                        Offset(0.42, 0.1),
                        Offset(0.62, 0.32),
                        Offset(0.88, 0.14),
                        Offset(0.5, 0.88),
                        Offset(0.28, 0.72),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(26, 26, narrow ? 26 : 260, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '✦  WELCOME BACK, ${userName.toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Fuel the streams\nyou love.',
                          style: TextStyle(
                            fontSize: narrow ? 30 : 40,
                            height: 1.08,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: Neon.pink.withValues(alpha: 0.8),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Discover creators, send tips through PaiFlow, '
                          'and unlock supporter rank badges.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 22),
                        GlowButton(
                          label: 'Explore creators',
                          icon: Icons.explore_rounded,
                          gradient: const LinearGradient(
                            colors: [Neon.gold, Neon.peach],
                          ),
                          foreground: const Color(0xFF2A1468),
                          onPressed: onExplore,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class StreamCard extends StatelessWidget {
  static const width = 280.0;

  final Creator creator;
  final CreatorActions actions;

  const StreamCard({super.key, required this.creator, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final followers = actions.followersOf(creator);
    final isFollowing = actions.isFollowing(creator);
    final onToggleFollow = actions.followActionFor(creator);
    void onTap() => actions.onSupport(creator);
    return SizedBox(
      width: width,
      child: NeonCard(
        padding: EdgeInsets.zero,
        accent: creator.color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF140A33),
                      creator.color,
                      Color.lerp(creator.color, Neon.pink, 0.6)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -36,
                      width: 140,
                      height: 140,
                      child: CustomPaint(
                        painter: PlanetPainter(
                          body: Color.lerp(creator.color, Neon.peach, 0.7)!,
                          bodyShade: creator.color,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: TwinkleField(
                        points: [
                          Offset(0.12, 0.25),
                          Offset(0.4, 0.6),
                          Offset(0.7, 0.18),
                        ],
                      ),
                    ),
                    const Positioned(top: 10, left: 10, child: LiveBadge()),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '● ${creator.viewers} viewers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 44,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeonAvatar(
                    initials: creator.initials,
                    color: creator.color,
                    imageUrl: creator.avatarUrl,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator.streamTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        CreatorName(
                          name: creator.name,
                          verified: creator.verified,
                          badgeSize: 13,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            NeonPill(
                              label: creator.category,
                              color: creator.color,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                followersLabel(followers),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: c.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FollowButton(
                    following: isFollowing,
                    onPressed: onToggleFollow,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatorName extends StatelessWidget {
  final String name;
  final bool verified;
  final TextStyle style;
  final double badgeSize;

  const CreatorName({
    super.key,
    required this.name,
    required this.verified,
    required this.style,
    this.badgeSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (verified) ...[
          const SizedBox(width: 5),
          VerifiedBadge(size: badgeSize),
        ],
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      accent: accent,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35 * c.glow),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  key: ValueKey(value),
                  builder: (context, t, child) => Transform.scale(
                    scale: t,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: c.text,
                    ),
                  ),
                ),
                Text(detail, style: TextStyle(color: c.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RankBadge extends StatelessWidget {
  final SupporterRank rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    return NeonPill(label: rank.label, color: rank.color, icon: rank.icon);
  }
}

class CreatorCard extends StatelessWidget {
  final Creator creator;
  final CreatorActions actions;

  const CreatorCard({super.key, required this.creator, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final rank = SupporterRank.getRankForAmount(actions.tippedTo(creator));
    final followers = actions.followersOf(creator);
    final isFollowing = actions.isFollowing(creator);
    final onToggleFollow = actions.followActionFor(creator);
    void onSupport() => actions.onSupport(creator);

    return NeonCard(
      padding: EdgeInsets.zero,
      accent: creator.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 76,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          creator.color,
                          Color.lerp(creator.color, Neon.pink, 0.55)!,
                        ],
                      ),
                    ),
                    child: const TwinkleField(
                      points: [
                        Offset(0.55, 0.3),
                        Offset(0.75, 0.7),
                        Offset(0.92, 0.25),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 34,
                  child: NeonAvatar(
                    initials: creator.initials,
                    color: creator.color,
                    imageUrl: creator.avatarUrl,
                    size: 72,
                    live: creator.isLive,
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FollowButton(
                    following: isFollowing,
                    onPressed: onToggleFollow,
                    compact: true,
                  ),
                ),
                if (rank != SupporterRank.none)
                  Positioned(right: 14, top: 86, child: RankBadge(rank: rank)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreatorName(
                  name: creator.name,
                  verified: creator.verified,
                  badgeSize: 19,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  creator.username,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    NeonPill(label: creator.category, color: creator.color),
                    if (creator.isLive)
                      NeonPill(
                        label: '${creator.viewers} watching',
                        color: Neon.live,
                        icon: Icons.sensors_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  creator.description,
                  style: TextStyle(height: 1.5, color: c.text),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(followers),
                        child: _stat(
                          Icons.group_add_rounded,
                          followersLabel(followers),
                          c,
                          highlight: isFollowing,
                        ),
                      ),
                    ),
                    _stat(
                      Icons.people_alt_rounded,
                      '${creator.supporters} supporters',
                      c,
                    ),
                    _stat(
                      Icons.toll_rounded,
                      '${dollars(creator.totalTips)} tipped',
                      c,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlowButton(
                  label: 'Support Creator',
                  icon: Icons.favorite_rounded,
                  expand: true,
                  onPressed: onSupport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String text,
    NeonColors c, {
    bool highlight = false,
  }) {
    final color = highlight ? Neon.cyan : c.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: Neon.violet),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: c.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              GlowButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatefulWidget {
  final int count;
  const SkeletonList({super.key, this.count = 3});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
        child: Column(
          children: [
            for (var i = 0; i < widget.count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeonCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: c.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(140, 12),
                            const SizedBox(height: 8),
                            bar(90, 10),
                          ],
                        ),
                      ),
                      bar(56, 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TipTile extends StatelessWidget {
  final TipActivity tip;
  final SupporterRank? rank;
  final VoidCallback? onTap;

  const TipTile({super.key, required this.tip, this.rank, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final creator = creatorNamed(tip.creator);
    final statusColor = tipStatusColor(tip.status);

    return NeonCard(
      padding: const EdgeInsets.all(14),
      accent: statusColor,
      onTap: onTap,
      child: Row(
        children: [
          NeonAvatar(
            initials: creator?.initials ?? initialsOf(tip.creator),
            color: creator?.color ?? Neon.purple,
            imageUrl: creator?.avatarUrl,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreatorName(
                  name: tip.creator,
                  verified: creator?.verified ?? false,
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NeonPill(label: tip.status, color: statusColor),
                    Tooltip(
                      message: tip.date.toLocal().toString().split('.').first,
                      child: Text(
                        timeAgo(tip.date),
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dollars(tip.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: c.text,
                ),
              ),
              if (rank != null) ...[
                const SizedBox(height: 6),
                RankBadge(rank: rank!),
              ],
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, size: 16, color: c.muted),
          ],
        ],
      ),
    );
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;

  const PasswordStrengthMeter({super.key, required this.controller});

  static const _levels = [
    ('Too weak', Neon.live),
    ('Weak', Neon.live),
    ('Fair', Neon.gold),
    ('Good', Neon.gold),
    ('Strong', Neon.cyan),
    ('Very strong', Neon.cyan),
  ];

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        final score = passwordStrength(password);
        final (label, color) = _levels[score];

        return Padding(
          padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    if (i > 1) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= score ? color : c.border,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: i <= score
                              ? [
                                  BoxShadow(
                                    color: color.withValues(
                                      alpha: 0.5 * c.glow,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (password.isNotEmpty)
                Text(
                  'Password strength: $label',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              const SizedBox(height: 6),
              for (final rule in passwordRules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          rule.test(password)
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(rule.test(password)),
                          size: 15,
                          color: rule.test(password) ? Neon.cyan : c.muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rule.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: rule.test(password) ? c.text : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class FollowButton extends StatefulWidget {
  final bool following;
  final VoidCallback? onPressed;
  final bool compact;

  const FollowButton({
    super.key,
    required this.following,
    required this.onPressed,
    this.compact = false,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final unfollowHint = widget.following && _hovered;
    final (label, icon, color) = !widget.following
        ? ('Follow', Icons.person_add_alt_1_rounded, Neon.purple)
        : unfollowHint
        ? ('Unfollow', Icons.person_remove_alt_1_rounded, Neon.live)
        : ('Following', Icons.check_rounded, Neon.cyan);

    return Semantics(
      button: true,
      toggled: widget.following,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: widget.following ? null : Neon.brandGradient,
            color: widget.following ? c.surface.withValues(alpha: 0.9) : null,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.8), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35 * c.glow),
                blurRadius: 12,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: widget.onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 12 : 16,
                  vertical: widget.compact ? 6 : 9,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Row(
                    key: ValueKey(label),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: widget.compact ? 14 : 16,
                        color: widget.following ? color : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: widget.compact ? 12 : 13,
                          fontWeight: FontWeight.w800,
                          color: widget.following ? color : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreatorActions {
  final int Function(Creator creator) followersOf;
  final bool Function(Creator creator) isFollowing;
  final bool Function(Creator creator) isFollowBusy;
  final double Function(Creator creator) tippedTo;
  final ValueChanged<Creator> onToggleFollow;
  final ValueChanged<Creator> onSupport;

  const CreatorActions({
    required this.followersOf,
    required this.isFollowing,
    required this.isFollowBusy,
    required this.tippedTo,
    required this.onToggleFollow,
    required this.onSupport,
  });

  VoidCallback? followActionFor(Creator creator) =>
      isFollowBusy(creator) ? null : () => onToggleFollow(creator);
}

class TabPage extends StatelessWidget {
  static const padding = EdgeInsets.fromLTRB(20, 20, 20, 110);

  final List<Widget> children;

  const TabPage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: padding, children: children);
  }
}

class CreatorGrid extends StatelessWidget {
  static const spacing = 16.0;
  static const twoColumnWidth = 720.0;

  final List<Creator> creators;
  final CreatorActions actions;

  const CreatorGrid({super.key, required this.creators, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= twoColumnWidth ? 2 : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final creator in creators)
              SizedBox(
                width: width,
                child: CreatorCard(creator: creator, actions: actions),
              ),
          ],
        );
      },
    );
  }
}

class LiveNowSection extends StatelessWidget {
  static const cardHeight = 292.0;
  static const gap = 16.0;

  final List<Creator> creators;
  final CreatorActions actions;
  final VoidCallback onSeeAll;

  const LiveNowSection({
    super.key,
    required this.creators,
    required this.actions,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: 'Live now',
          subtitle: creators.isEmpty
              ? 'Nobody is streaming right now'
              : '${creators.length} ${creators.length == 1 ? 'creator' : 'creators'} streaming',
          actionLabel: 'See all',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 14),
        if (creators.isEmpty)
          EmptyState(
            icon: Icons.videocam_off_rounded,
            title: 'No live streams',
            description: 'Check back soon or browse all creators.',
            actionLabel: 'Browse creators',
            onAction: onSeeAll,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  creators.length * StreamCard.width +
                  (creators.length - 1) * gap;
              final fits = contentWidth <= constraints.maxWidth;
              final cards = [
                for (var i = 0; i < creators.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  StreamCard(creator: creators[i], actions: actions),
                ],
              ];

              return SizedBox(
                height: cardHeight,
                child: fits
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: cards,
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: cards,
                      ),
              );
            },
          ),
      ],
    );
  }
}

class StatGrid extends StatelessWidget {
  static const breakpoint = 620.0;

  final List<StatCard> cards;

  const StatGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}
