import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dialogs.dart';
import 'models.dart';
import 'neon.dart';
import 'services.dart';
import 'tabs/activity_tab.dart';
import 'tabs/discover_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/wallet_tab.dart';
import 'wallet.dart';
import 'widgets.dart';

enum AppTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  discover('Discover', Icons.explore_outlined, Icons.explore_rounded),
  wallet(
    'Wallet',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
  ),
  activity('Activity', Icons.history_outlined, Icons.history_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AppTab(this.label, this.icon, this.selectedIcon);
}

class HomeScreen extends StatefulWidget {
  final User user;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _navRevealDistance = 120.0;

  late final _profileService = ProfileService(widget.user);
  late final _followService = FollowService(widget.user.uid);
  late final _profileStream = _profileService.watch();
  late final _tipsStream = TipsService(widget.user.uid).watch();
  StreamSubscription<Map<String, int>>? _followerCountsSub;
  final _mouseTracker = RendererBinding.instance.mouseTracker;

  AppTab _tab = AppTab.home;
  Map<String, int> _followerCounts = {};
  final Set<String> _followBusy = {};
  int _seenTipCount = 0;
  bool _uploadingPhoto = false;
  bool _pointerNearBottom = false;
  String? _photoBase64;
  Uint8List? _photoBytes;

  bool get _showNav => !_mouseTracker.mouseIsConnected || _pointerNearBottom;

  @override
  void initState() {
    super.initState();
    _mouseTracker.addListener(_onMouseConnectionChanged);
    _followerCountsSub = _followService.watchFollowerCounts().listen((counts) {
      if (mounted) setState(() => _followerCounts = counts);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _mouseTracker.removeListener(_onMouseConnectionChanged);
    _followerCountsSub?.cancel();
    super.dispose();
  }

  void _onMouseConnectionChanged() => setState(() {});

  void _onPointerMove(PointerHoverEvent event) {
    final height = MediaQuery.sizeOf(context).height;
    final near = event.position.dy >= height - _navRevealDistance;
    if (near != _pointerNearBottom) setState(() => _pointerNearBottom = near);
  }

  void _goTo(AppTab tab) => setState(() => _tab = tab);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _openExternal(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
    _showMessage(
      'Could not open $uri. Make sure the PaiFlow server is running.',
    );
    return false;
  }

  Uint8List? _decodePhoto(String? base64Photo) {
    if (base64Photo != _photoBase64) {
      _photoBase64 = base64Photo;
      try {
        _photoBytes = base64Photo == null ? null : base64Decode(base64Photo);
      } on FormatException {
        _photoBytes = null;
      }
    }
    return _photoBytes;
  }

  CreatorActions _creatorActions(
    CurrentUser me,
    Map<String, double> tippedByCreator,
  ) {
    return CreatorActions(
      followersOf: (creator) => _followerCounts[creator.id] ?? 0,
      isFollowing: (creator) => me.following.contains(creator.id),
      isFollowBusy: (creator) => _followBusy.contains(creator.id),
      tippedTo: (creator) => tippedByCreator[creator.name] ?? 0,
      onToggleFollow: (creator) =>
          _toggleFollow(creator, follow: !me.following.contains(creator.id)),
      onSupport: (creator) => _confirmTip(creator, tippedByCreator),
    );
  }

  Future<void> _toggleFollow(Creator creator, {required bool follow}) async {
    if (!_followBusy.add(creator.id)) return;
    setState(() {});
    try {
      await _followService.setFollowing(creator, follow: follow);
      _showMessage(
        follow
            ? 'You\'re now following ${creator.name}.'
            : 'You unfollowed ${creator.name}.',
      );
    } catch (_) {
      _showMessage('Could not update your follow. Please try again.');
    } finally {
      if (mounted) setState(() => _followBusy.remove(creator.id));
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final png = await shrinkToPng(await picked.readAsBytes());
      if (png.lengthInBytes > 600 * 1024) {
        _showMessage('That picture is too large. Try a smaller one.');
        return;
      }
      await _profileService.setPhoto(png);
      _showMessage('Profile picture updated.');
    } catch (_) {
      _showMessage('Could not update your picture. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    try {
      await _profileService.removePhoto();
    } catch (_) {
      _showMessage('Could not remove your picture. Please try again.');
    }
  }

  Future<void> _editDetails(ProfileDetails current) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProfileDetailsDialog(
        initial: current,
        onSave: _profileService.saveDetails,
      ),
    );
    if (saved == true) _showMessage('Profile details saved.');
  }

  Future<void> _changeUsername(String current) async {
    final changed = await showDialog<String>(
      context: context,
      builder: (_) => UsernameDialog(
        current: current,
        onSave: (name) => _profileService.changeUsername(current, name),
      ),
    );
    if (changed != null) _showMessage('Your username is now $changed.');
  }

  Future<void> _connectWallet() async {
    final code = PaiFlowLinks.newLinkCode();
    if (!await _openExternal(PaiFlowLinks.connect(code)) || !mounted) return;

    var waiting = true;
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve in Freighter'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'Finish connecting on the PaiFlow page that just opened in your browser.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).whenComplete(() => waiting = false);

    final address = await PaiFlowLinks.waitForWalletLink(
      code,
      keepWaiting: () => waiting && mounted,
    );

    if (waiting && mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    if (address != null) await _saveWallet(address);
  }

  Future<void> _enterWalletAddress() async {
    final address = await showDialog<String>(
      context: context,
      builder: (_) => const WalletAddressDialog(),
    );
    if (address != null) await _saveWallet(address);
  }

  Future<void> _saveWallet(String address) async {
    try {
      await _profileService.saveWallet(address);
      _showMessage('Wallet ${shortAddress(address)} connected.');
    } catch (_) {
      _showMessage('Could not save your wallet. Please try again.');
    }
  }

  Future<void> _disconnectWallet() async {
    final confirmed = await _confirm(
      title: 'Disconnect wallet?',
      message: 'JarJar will stop showing this wallet\'s balance. Your funds are not affected.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed) return;
    try {
      await _profileService.removeWallet();
    } catch (_) {
      _showMessage('Could not disconnect your wallet. Please try again.');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      title: 'Log out of JarJar?',
      message: 'You can sign back in any time with your email and password.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (confirmed) await FirebaseAuth.instance.signOut();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Neon.live)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _confirmTip(
    Creator creator,
    Map<String, double> tippedByCreator,
  ) async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (_) => TipConfirmDialog(
        creator: creator,
        rank: SupporterRank.getRankForAmount(
          tippedByCreator[creator.name] ?? 0,
        ),
      ),
    );
    if (!mounted || shouldContinue != true) return;

    final opened = await _openExternal(
      PaiFlowLinks.payment(creator: creator, userId: widget.user.uid),
    );
    if (opened) {
      _showMessage(
        'Continue on the PaiFlow page to choose your amount and pay.',
      );
    }
  }

  Future<void> _showNotifications(List<TipActivity> activities) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: NeonColors.of(context).surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => NotificationsSheet(
        recent: activities.reversed.take(5).toList(),
        onSeeAll: () {
          Navigator.pop(sheetContext);
          _goTo(AppTab.activity);
        },
      ),
    );
    if (mounted) setState(() => _seenTipCount = activities.length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final me = CurrentUser.fromProfile(
          authName: widget.user.displayName,
          email: widget.user.email,
          profile: profile,
          photo: _decodePhoto(profile?['photo'] as String?),
        );

        return StreamBuilder<List<TipActivity>>(
          stream: _tipsStream,
          builder: (context, tipsSnapshot) {
            final activities = tipsSnapshot.data ?? const <TipActivity>[];
            final tippedByCreator = <String, double>{};
            for (final tip in activities.where((t) => t.status == tipSuccess)) {
              tippedByCreator.update(
                tip.creator,
                (sum) => sum + tip.amount,
                ifAbsent: () => tip.amount,
              );
            }
            final actions = _creatorActions(me, tippedByCreator);

            return _buildShell(
              me: me,
              activities: activities,
              pages: [
                HomeTab(
                  me: me,
                  activities: activities,
                  actions: actions,
                  onExplore: () => _goTo(AppTab.discover),
                ),
                DiscoverTab(
                  actions: actions,
                  followingCount: me.following.length,
                ),
                WalletTab(
                  address: me.wallet,
                  onConnect: _connectWallet,
                  onEnterManually: _enterWalletAddress,
                  onDisconnect: _disconnectWallet,
                  onGetUsdc: () => _openExternal(PaiFlowLinks.usdcFaucet),
                  onSwap: () => _openExternal(PaiFlowLinks.swap()),
                  onOpenPayment: () => _openExternal(PaiFlowLinks.payment()),
                  onMessage: _showMessage,
                ),
                ActivityTab(
                  activities: activities,
                  loading: !tipsSnapshot.hasData && !tipsSnapshot.hasError,
                  failed: tipsSnapshot.hasError,
                  tippedTo: (name) => tippedByCreator[name] ?? 0,
                  onFindCreator: () => _goTo(AppTab.discover),
                  onOpenLink: _openExternal,
                ),
                ProfileTab(
                  me: me,
                  isDarkMode: widget.isDarkMode,
                  uploadingPhoto: _uploadingPhoto,
                  onThemeChanged: widget.onThemeChanged,
                  onChangePhoto: _changePhoto,
                  onRemovePhoto: _removePhoto,
                  onChangeUsername: () => _changeUsername(me.name),
                  onEditDetails: () => _editDetails(me.details),
                  onOpenLink: _openExternal,
                  onSignOut: _signOut,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShell({
    required CurrentUser me,
    required List<TipActivity> activities,
    required List<Widget> pages,
  }) {
    final showNav = _showNav;
    final unread = activities.length - _seenTipCount;

    return MouseRegion(
      onHover: _onPointerMove,
      onExit: (_) => setState(() => _pointerNearBottom = false),
      child: Scaffold(
        extendBody: true,
        body: NeonBackground(
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _TopBar(
                      me: me,
                      unread: unread,
                      isDarkMode: widget.isDarkMode,
                      onThemeChanged: widget.onThemeChanged,
                      onLogoTap: () => _goTo(AppTab.home),
                      onProfileTap: () => _goTo(AppTab.profile),
                      onNotificationsTap: () => _showNotifications(activities),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: FadeIndexedStack(
                            index: _tab.index,
                            children: pages,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: _NavHandle(visible: !showNav),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AnimatedSlide(
          offset: showNav ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: showNav ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: _BottomBar(selected: _tab, onSelected: _goTo),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CurrentUser me;
  final int unread;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogoTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  const _TopBar({
    required this.me,
    required this.unread,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLogoTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onLogoTap,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JarJarLogo(),
                  SizedBox(width: 10),
                  GradientText(
                    'JarJar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ThemeToggleButton(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Neon.pink,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onProfileTap,
              child: NeonAvatar(
                initials: initialsOf(me.name),
                color: Neon.purple,
                imageBytes: me.photo,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final AppTab selected;
  final ValueChanged<AppTab> onSelected;

  const _BottomBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Neon.purple.withValues(alpha: 0.18 * c.glow),
            blurRadius: 24,
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (i) => onSelected(AppTab.values[i]),
        animationDuration: const Duration(milliseconds: 400),
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _NavHandle extends StatelessWidget {
  final bool visible;

  const _NavHandle({required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Center(
          child: Container(
            width: 64,
            height: 5,
            decoration: BoxDecoration(
              gradient: Neon.brandGradient,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Neon.pink.withValues(alpha: 0.7),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
