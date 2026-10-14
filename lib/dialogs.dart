import 'package:flutter/material.dart';

import 'models.dart';
import 'services.dart';
import 'widgets.dart';
import 'neon.dart';
import 'wallet.dart';

class WalletAddressDialog extends StatefulWidget {
  const WalletAddressDialog({super.key});

  @override
  State<WalletAddressDialog> createState() => _WalletAddressDialogState();
}

class _WalletAddressDialogState extends State<WalletAddressDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final address = _controller.text.trim().toUpperCase();
    if (!stellarAddressPattern.hasMatch(address)) {
      setState(
        () => _error =
            'Stellar addresses start with G and are 56 characters long.',
      );
      return;
    }
    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter wallet address'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Stellar public address',
            hintText: 'G…',
            helperText: 'Copy it from Freighter. Never paste your secret key.',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        GlowButton(
          label: 'Connect',
          icon: Icons.link_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class UsernameDialog extends StatefulWidget {
  final String current;
  final Future<void> Function(String name) onSave;

  const UsernameDialog({
    super.key,
    required this.current,
    required this.onSave,
  });

  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (!usernamePattern.hasMatch(name)) {
      setState(() => _error = 'Use 3–20 characters: letters, numbers, _ or .');
      return;
    }
    if (name == widget.current) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name);
      if (mounted) Navigator.pop(context, name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is UsernameTakenException
            ? '"$name" is already taken.'
            : 'Could not change your username. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change username'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_saving,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'New username',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            helperText: '3–20 characters: letters, numbers, _ or .',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        GlowButton(
          label: _saving ? 'Saving…' : 'Save',
          icon: Icons.check_rounded,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class ProfileDetailsDialog extends StatefulWidget {
  final ProfileDetails initial;
  final Future<void> Function(ProfileDetails details) onSave;

  const ProfileDetailsDialog({
    super.key,
    required this.initial,
    required this.onSave,
  });

  @override
  State<ProfileDetailsDialog> createState() => _ProfileDetailsDialogState();
}

class _ProfileDetailsDialogState extends State<ProfileDetailsDialog> {
  static final _handlePattern = RegExp(r'^[A-Za-z0-9_.\-]{1,40}$');

  final _formKey = GlobalKey<FormState>();
  late final _bio = TextEditingController(text: widget.initial.bio);
  late final _pronouns = TextEditingController(text: widget.initial.pronouns);
  late final _location = TextEditingController(text: widget.initial.location);
  late final _twitch = TextEditingController(text: widget.initial.twitch);
  late final _youtube = TextEditingController(text: widget.initial.youtube);
  late final _x = TextEditingController(text: widget.initial.x);
  late String _favorite = widget.initial.favoriteCategory;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_bio, _pronouns, _location, _twitch, _youtube, _x]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _cleanHandle(String value) {
    var v = value.trim();
    if (v.contains('/')) v = v.split('/').where((p) => p.isNotEmpty).last;
    return v.replaceFirst(RegExp(r'^@'), '');
  }

  String? _validateHandle(String? value) {
    final v = _cleanHandle(value ?? '');
    if (v.isEmpty || _handlePattern.hasMatch(v)) return null;
    return 'Use letters, numbers, _ . or - only';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        ProfileDetails(
          bio: _bio.text.trim(),
          pronouns: _pronouns.text.trim(),
          location: _location.text.trim(),
          favoriteCategory: _favorite,
          twitch: _cleanHandle(_twitch.text),
          youtube: _cleanHandle(_youtube.text),
          x: _cleanHandle(_x.text),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your details. Please try again.';
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLength = 40,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final categories = {for (final creator in creators) creator.category}
        .toList();

    return AlertDialog(
      title: const Text('About you'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything here is optional and shown on your profile.',
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 16),
                _field(
                  _bio,
                  'Bio',
                  Icons.notes_rounded,
                  maxLength: 160,
                  maxLines: 3,
                  hint: 'A line or two about you',
                ),
                _field(
                  _pronouns,
                  'Pronouns',
                  Icons.badge_outlined,
                  maxLength: 30,
                  hint: 'e.g. she/her, they/them',
                ),
                _field(
                  _location,
                  'Location',
                  Icons.place_outlined,
                  hint: 'City or country',
                ),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(_favorite) ? _favorite : '',
                  decoration: const InputDecoration(
                    labelText: 'Favorite category',
                    prefixIcon: Icon(Icons.favorite_border_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No preference'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _favorite = v ?? ''),
                ),
                const SizedBox(height: 20),
                Text(
                  'Socials',
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 10),
                _field(
                  _twitch,
                  'Twitch username',
                  Icons.videogame_asset_rounded,
                  validator: _validateHandle,
                ),
                _field(
                  _youtube,
                  'YouTube handle',
                  Icons.smart_display_rounded,
                  validator: _validateHandle,
                ),
                _field(
                  _x,
                  'X (Twitter) handle',
                  Icons.alternate_email_rounded,
                  validator: _validateHandle,
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Neon.live)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        GlowButton(
          label: _saving ? 'Saving…' : 'Save',
          icon: Icons.check_rounded,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class TipConfirmDialog extends StatelessWidget {
  final Creator creator;
  final SupporterRank rank;

  const TipConfirmDialog({
    super.key,
    required this.creator,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return AlertDialog(
      title: Row(
        children: [
          NeonAvatar(
            initials: creator.initials,
            color: creator.color,
            imageUrl: creator.avatarUrl,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text('Support ${creator.name}?'),
                if (creator.verified) const VerifiedBadge(size: 20),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Current rank: ', style: TextStyle(color: c.muted)),
                RankBadge(rank: rank),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'You will be taken to the PaiFlow payment page to choose your '
              'tip amount and approve the payment in Freighter. Your tip '
              'appears here once PaiFlow processes it.',
              style: TextStyle(height: 1.5, color: c.text),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        GlowButton(
          label: 'Continue to PaiFlow',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

class NotificationsSheet extends StatelessWidget {
  final List<TipActivity> recent;
  final VoidCallback onSeeAll;

  const NotificationsSheet({
    super.key,
    required this.recent,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: c.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your latest tip updates from PaiFlow',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 16),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'You\'re all caught up. Updates about your tips will show here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
              )
            else ...[
              for (final tip in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TipTile(tip: tip),
                ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all activity'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
