import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String dollars(num amount) => '\$${amount.toStringAsFixed(2)}';

final usernamePattern = RegExp(r'^[A-Za-z0-9_.]{3,20}$');

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

const paiflowHost = 'localhost:3000';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? 'J' : letters;
}

enum SupporterRank {
  none('New', Colors.grey, Icons.star_border),
  supporter('Supporter', Color(0xFFCD7F32), Icons.star_half_rounded),
  activeSupporter('Active Supporter', Color(0xFFC0C0C0), Icons.star_rounded),
  topSupporter(
    'Top Supporter',
    Color(0xFFFFD700),
    Icons.workspace_premium_rounded,
  );

  final String label;
  final Color color;
  final IconData icon;

  const SupporterRank(this.label, this.color, this.icon);

  static SupporterRank getRankForAmount(double totalAmount) {
    if (totalAmount >= 50.0) {
      return SupporterRank.topSupporter;
    } else if (totalAmount >= 20.0) {
      return SupporterRank.activeSupporter;
    } else if (totalAmount > 0.0) {
      return SupporterRank.supporter;
    }
    return SupporterRank.none;
  }
}

class Creator {
  final String name;
  final String username;
  final String category;
  final String description;
  final Color color;
  final String initials;
  final int supporters;
  final double totalTips;
  final bool isLive;
  final int viewers;
  final String streamTitle;
  final bool verified;

  const Creator({
    required this.name,
    required this.username,
    required this.category,
    required this.description,
    required this.color,
    required this.initials,
    required this.supporters,
    required this.totalTips,
    required this.isLive,
    required this.viewers,
    required this.streamTitle,
    this.verified = true,
  });

  String get id => username.replaceFirst('@', '').toLowerCase();

  String get avatarUrl {
    final background = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2);
    return 'https://api.dicebear.com/9.x/adventurer/png'
        '?seed=${Uri.encodeComponent(username)}&size=160&backgroundColor=$background';
  }
}

const List<Creator> creators = [
  Creator(
    name: 'Yhatch Junio',
    username: '@yhatchjunio',
    category: 'Gaming',
    description: 'Gaming streams, community challenges, and fun.',
    color: Color(0xFF6A4CFF),
    initials: 'YJ',
    supporters: 128,
    totalTips: 1240,
    isLive: true,
    viewers: 1284,
    streamTitle: 'Ranked grind until we hit Diamond 💎',
  ),
  Creator(
    name: 'Andre Arenas',
    username: '@sanera',
    category: 'Creative',
    description: 'Digital art, creative projects, and tutorials.',
    color: Color(0xFFB04CFF),
    initials: 'AR',
    supporters: 96,
    totalTips: 865,
    isLive: true,
    viewers: 642,
    streamTitle: 'Painting a space station from scratch',
  ),
  Creator(
    name: 'Gabee Morales',
    username: '@GabeePlayztzy',
    category: 'Gaming',
    description: 'Casual gaming and live community sessions.',
    color: Color(0xFF1BB3A0),
    initials: 'GM',
    supporters: 74,
    totalTips: 620,
    isLive: false,
    viewers: 0,
    streamTitle: 'Cozy co-op night with chat',
  ),
  Creator(
    name: 'Jomira Moreno',
    username: '@jomirafionnaTV',
    category: 'Music',
    description: 'Music sessions, covers, and creative experiments.',
    color: Color(0xFFFF5FA2),
    initials: 'JM',
    supporters: 63,
    totalTips: 510,
    isLive: true,
    viewers: 389,
    streamTitle: 'Acoustic requests — you pick the songs 🎶',
  ),
];

Creator? creatorNamed(String name) {
  for (final creator in creators) {
    if (creator.name == name) return creator;
  }
  return null;
}

const String tipPending = 'Pending';
const String tipSuccess = 'Success';
const String tipFailed = 'Failed';

class TipActivity {
  final String creator;
  final double amount;
  final DateTime date;
  final String status;
  final String? txHash;

  const TipActivity({
    required this.creator,
    required this.amount,
    required this.date,
    required this.status,
    this.txHash,
  });

  Uri? get explorerUrl => txHash == null
      ? null
      : Uri.https('stellar.expert', '/explorer/testnet/tx/$txHash');

  factory TipActivity.fromFirestore(Map<String, dynamic> data) {
    return TipActivity(
      creator: data['creator'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? tipPending,
      txHash: switch (data['txHash']) {
        final String hash when RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) =>
          hash,
        _ => null,
      },
    );
  }
}

class ProfileDetails {
  final String bio;
  final String pronouns;
  final String location;
  final String favoriteCategory;
  final String twitch;
  final String youtube;
  final String x;

  const ProfileDetails({
    this.bio = '',
    this.pronouns = '',
    this.location = '',
    this.favoriteCategory = '',
    this.twitch = '',
    this.youtube = '',
    this.x = '',
  });

  factory ProfileDetails.fromMap(Object? data) {
    final map = data is Map ? data : const {};
    String read(String key) => (map[key] as String?)?.trim() ?? '';
    return ProfileDetails(
      bio: read('bio'),
      pronouns: read('pronouns'),
      location: read('location'),
      favoriteCategory: read('favoriteCategory'),
      twitch: read('twitch'),
      youtube: read('youtube'),
      x: read('x'),
    );
  }

  Map<String, String> toMap() => {
    'bio': bio,
    'pronouns': pronouns,
    'location': location,
    'favoriteCategory': favoriteCategory,
    'twitch': twitch,
    'youtube': youtube,
    'x': x,
  };

  bool get isEmpty => toMap().values.every((v) => v.isEmpty);

  List<(String, IconData, Uri)> get socialLinks => [
    if (twitch.isNotEmpty)
      (
        'Twitch',
        Icons.videogame_asset_rounded,
        Uri.https('twitch.tv', '/$twitch'),
      ),
    if (youtube.isNotEmpty)
      (
        'YouTube',
        Icons.smart_display_rounded,
        Uri.https('youtube.com', '/@$youtube'),
      ),
    if (x.isNotEmpty)
      ('X', Icons.alternate_email_rounded, Uri.https('x.com', '/$x')),
  ];
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String timeAgo(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(date);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && current.day == date.day) {
    return '${diff.inHours} h ago';
  }
  final local = date.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (dayLabel(date, now: current) == 'Yesterday') return 'Yesterday, $time';
  return '${local.day} ${_months[local.month - 1]}, $time';
}

String dayLabel(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return 'This week';
  return '${_months[date.month - 1]} ${date.year}';
}

Color tipStatusColor(String status) => switch (status) {
  tipSuccess => const Color(0xFF3DF2FF),
  tipFailed => const Color(0xFFFF3B6B),
  _ => const Color(0xFFFFD54F),
};

class PasswordRule {
  final String label;
  final bool Function(String password) test;

  const PasswordRule(this.label, this.test);
}

final passwordRules = [
  PasswordRule('At least 8 characters', (p) => p.length >= 8),
  PasswordRule('One uppercase letter', (p) => p.contains(RegExp(r'[A-Z]'))),
  PasswordRule(
    'One symbol (e.g. ! @ # \$)',
    (p) => p.contains(RegExp(r'[^A-Za-z0-9\s]')),
  ),
];

bool passwordMeetsRules(String password) =>
    passwordRules.every((rule) => rule.test(password));

int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = passwordRules.where((rule) => rule.test(password)).length;
  if (password.contains(RegExp(r'[0-9]')) &&
      password.contains(RegExp(r'[a-z]'))) {
    score++;
  }
  if (password.length >= 12) score++;
  return score.clamp(1, 5);
}

String compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  final m = n / 1000000;
  return '${m >= 10 ? m.toStringAsFixed(0) : m.toStringAsFixed(1).replaceAll('.0', '')}M';
}

String followersLabel(int n) =>
    n == 1 ? '1 follower' : '${compactCount(n)} followers';

class CurrentUser {
  final String name;
  final String email;
  final Uint8List? photo;
  final ProfileDetails details;
  final String? wallet;
  final Set<String> following;

  const CurrentUser({
    required this.name,
    required this.email,
    required this.photo,
    required this.details,
    required this.wallet,
    required this.following,
  });

  factory CurrentUser.fromProfile({
    required String? authName,
    required String? email,
    required Map<String, dynamic>? profile,
    required Uint8List? photo,
  }) {
    final candidates = [
      authName?.trim(),
      (profile?['username'] as String?)?.trim(),
      (email ?? '').split('@').first,
    ];
    final wallet = profile?['wallet'];
    return CurrentUser(
      name: candidates.firstWhere(
        (n) => n != null && n.isNotEmpty,
        orElse: () => 'JarJar User',
      )!,
      email: email ?? '',
      photo: photo,
      details: ProfileDetails.fromMap(profile?['about']),
      wallet: wallet is String && RegExp(r'^G[A-Z2-7]{55}$').hasMatch(wallet)
          ? wallet
          : null,
      following: {
        for (final id in (profile?['following'] as List?) ?? const [])
          if (id is String) id,
      },
    );
  }
}
