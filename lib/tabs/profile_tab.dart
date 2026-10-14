import 'package:flutter/material.dart';

import '../models.dart';
import '../neon.dart';
import '../widgets.dart';

class ProfileTab extends StatelessWidget {
  final CurrentUser me;
  final bool isDarkMode;
  final bool uploadingPhoto;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onChangeUsername;
  final VoidCallback onEditDetails;
  final ValueChanged<Uri> onOpenLink;
  final VoidCallback onSignOut;

  const ProfileTab({
    super.key,
    required this.me,
    required this.isDarkMode,
    required this.uploadingPhoto,
    required this.onThemeChanged,
    required this.onChangePhoto,
    required this.onRemovePhoto,
    required this.onChangeUsername,
    required this.onEditDetails,
    required this.onOpenLink,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return TabPage(
      children: [
        const SectionHeading(
          title: 'Profile',
          subtitle: 'Your account, picture and preferences',
        ),
        const SizedBox(height: 20),
        _IdentityCard(
          me: me,
          uploadingPhoto: uploadingPhoto,
          onChangePhoto: onChangePhoto,
          onRemovePhoto: onRemovePhoto,
          onChangeUsername: onChangeUsername,
        ),
        const SizedBox(height: 14),
        _AboutCard(
          details: me.details,
          onEdit: onEditDetails,
          onOpenLink: onOpenLink,
        ),
        const SizedBox(height: 14),
        const _TierCard(),
        const SizedBox(height: 14),
        NeonCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            secondary: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: Neon.violet,
            ),
            title: const Text(
              'Dark mode',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Neon night or soft lavender'),
            value: isDarkMode,
            onChanged: onThemeChanged,
          ),
        ),
        const SizedBox(height: 14),
        NeonCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          accent: Neon.live,
          onTap: onSignOut,
          child: const ListTile(
            leading: Icon(Icons.logout_rounded, color: Neon.live),
            title: Text(
              'Log out',
              style: TextStyle(color: Neon.live, fontWeight: FontWeight.w800),
            ),
            subtitle: Text('Sign out of JarJar'),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  static const _bannerHeight = 110.0;
  static const _avatarSize = 92.0;

  final CurrentUser me;
  final bool uploadingPhoto;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onChangeUsername;

  const _IdentityCard({
    required this.me,
    required this.uploadingPhoto,
    required this.onChangePhoto,
    required this.onRemovePhoto,
    required this.onChangeUsername,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final changePhoto = uploadingPhoto ? null : onChangePhoto;

    return NeonCard(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _bannerHeight + _avatarSize / 2 - 6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _bannerHeight,
                  child: _ProfileBanner(),
                ),
                Positioned(
                  left: 20,
                  top: _bannerHeight - _avatarSize / 2 - 6,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      NeonAvatar(
                        initials: initialsOf(me.name),
                        color: Neon.purple,
                        imageBytes: me.photo,
                        size: _avatarSize,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: _CameraButton(
                          busy: uploadingPhoto,
                          onPressed: changePhoto,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        me.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: c.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Change username',
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: Neon.violet,
                      ),
                      onPressed: onChangeUsername,
                    ),
                  ],
                ),
                Text(me.email, style: TextStyle(color: c.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const NeonPill(
                      label: 'Creator Support Account',
                      icon: Icons.favorite_rounded,
                      color: Neon.pink,
                    ),
                    NeonPill(
                      label: 'Following ${me.following.length}',
                      icon: Icons.group_rounded,
                      color: Neon.cyan,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: changePhoto,
                      icon: const Icon(Icons.image_rounded, size: 18),
                      label: Text(
                        me.photo == null ? 'Add photo' : 'Change photo',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onChangeUsername,
                      icon: const Icon(Icons.alternate_email_rounded, size: 18),
                      label: const Text('Change username'),
                    ),
                    if (me.photo != null)
                      TextButton.icon(
                        onPressed: onRemovePhoto,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Remove photo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A1468), Neon.purple, Neon.pink],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 20,
            top: -30,
            width: 170,
            height: 170,
            child: CustomPaint(painter: PlanetPainter()),
          ),
          Positioned.fill(
            child: TwinkleField(
              points: [Offset(0.1, 0.3), Offset(0.35, 0.65), Offset(0.6, 0.25)],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const _CameraButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Change photo',
      child: Material(
        color: Neon.pink,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final ProfileDetails details;
  final VoidCallback onEdit;
  final ValueChanged<Uri> onOpenLink;

  const _AboutCard({
    required this.details,
    required this.onEdit,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final d = details;
    final facts = [
      if (d.pronouns.isNotEmpty)
        (Icons.badge_outlined, d.pronouns, Neon.violet),
      if (d.location.isNotEmpty) (Icons.place_outlined, d.location, Neon.cyan),
      if (d.favoriteCategory.isNotEmpty)
        (Icons.favorite_rounded, 'Loves ${d.favoriteCategory}', Neon.pink),
    ];

    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'About you',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: c.text,
                  ),
                ),
              ),
              NeonPill(label: 'Optional', color: c.muted),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: Neon.violet,
                ),
                onPressed: onEdit,
              ),
            ],
          ),
          if (d.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Add a bio, pronouns, location, your favorite category and your '
              'socials so creators and the community know who\'s cheering them on.',
              style: TextStyle(color: c.muted, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add details'),
            ),
          ] else ...[
            if (d.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(d.bio, style: TextStyle(color: c.text, height: 1.5)),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (icon, label, color) in facts)
                    NeonPill(label: label, icon: icon, color: color),
                ],
              ),
            ],
            if (d.socialLinks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, icon, uri) in d.socialLinks)
                    ActionChip(
                      avatar: Icon(icon, size: 16, color: Neon.violet),
                      label: Text(label),
                      tooltip: uri.toString(),
                      onPressed: () => onOpenLink(uri),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  static const _tiers = [
    (SupporterRank.supporter, '\$1.00 – \$19.99'),
    (SupporterRank.activeSupporter, '\$20.00 – \$49.99'),
    (SupporterRank.topSupporter, '\$50.00+'),
  ];

  const _TierCard();

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supporter Tier Thresholds',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _tiers.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              children: [
                Icon(_tiers[i].$1.icon, color: _tiers[i].$1.color, size: 20),
                const SizedBox(width: 10),
                Text(
                  _tiers[i].$1.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _tiers[i].$1.color,
                  ),
                ),
                const Spacer(),
                Text(
                  _tiers[i].$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
