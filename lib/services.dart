import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'wallet.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

class ProfileService {
  final User user;

  ProfileService(this.user);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(user.uid);

  Stream<Map<String, dynamic>?> watch() =>
      _doc.snapshots().map((snapshot) => snapshot.data());

  Future<void> _merge(Map<String, Object?> data) =>
      _doc.set(data, SetOptions(merge: true));

  Future<void> setPhoto(Uint8List png) => _merge({'photo': base64Encode(png)});

  Future<void> removePhoto() => _merge({'photo': FieldValue.delete()});

  Future<void> saveDetails(ProfileDetails details) =>
      _merge({'about': details.toMap()});

  Future<void> saveWallet(String address) => _merge({'wallet': address});

  Future<void> removeWallet() => _merge({'wallet': FieldValue.delete()});

  Future<void> changeUsername(String oldName, String newName) async {
    final usernames = _db.collection('usernames');
    final newRef = usernames.doc(newName.toLowerCase());
    final oldRef = usernamePattern.hasMatch(oldName)
        ? usernames.doc(oldName.toLowerCase())
        : null;

    await _db.runTransaction((tx) async {
      final taken = await tx.get(newRef);
      if (taken.exists && taken.data()?['uid'] != user.uid) {
        throw const UsernameTakenException();
      }
      final old = oldRef == null ? null : await tx.get(oldRef);
      final releaseOld =
          old != null &&
          old.exists &&
          old.reference.id != newRef.id &&
          old.data()?['uid'] == user.uid;

      if (releaseOld) tx.delete(oldRef!);
      if (!taken.exists) tx.set(newRef, {'uid': user.uid});
      tx.set(_doc, {'username': newName}, SetOptions(merge: true));
    });

    await user.updateDisplayName(newName);
  }
}

class FollowService {
  final String uid;

  FollowService(this.uid);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<Map<String, int>> watchFollowerCounts() => _db
      .collection('creators')
      .snapshots()
      .map(
        (snapshot) => {
          for (final doc in snapshot.docs)
            doc.id: max(0, (doc.data()['followers'] as num?)?.toInt() ?? 0),
        },
      );

  Future<void> setFollowing(Creator creator, {required bool follow}) {
    final creatorRef = _db.collection('creators').doc(creator.id);
    final followerRef = creatorRef.collection('followers').doc(uid);
    final userRef = _db.collection('users').doc(uid);
    final merge = SetOptions(merge: true);
    final batch = _db.batch();

    if (follow) {
      batch.set(followerRef, {'at': FieldValue.serverTimestamp()});
    } else {
      batch.delete(followerRef);
    }
    batch.set(creatorRef, {
      'followers': FieldValue.increment(follow ? 1 : -1),
    }, merge);
    batch.set(userRef, {
      'following': follow
          ? FieldValue.arrayUnion([creator.id])
          : FieldValue.arrayRemove([creator.id]),
    }, merge);

    return batch.commit();
  }
}

class TipsService {
  final String uid;

  TipsService(this.uid);

  Stream<List<TipActivity>> watch() => FirebaseFirestore.instance
      .collection('tips')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            TipActivity.fromFirestore(doc.data()),
        ]..sort((a, b) => a.date.compareTo(b.date)),
      );
}

class PaiFlowLinks {
  const PaiFlowLinks._();

  static Uri payment({Creator? creator, String? creatorName, String? userId}) {
    final name = creator?.name ?? creatorName;
    return Uri.http(paiflowHost, '/send', {
      if (name != null) ...{
        'creator': name,
        'userId': ?userId,
        'handle': ?(creator ?? creatorNamed(name))?.username,
      },
    });
  }

  static Uri connect(String code) =>
      Uri.http(paiflowHost, '/connect', {'code': code});

  static Uri swap() => Uri.http(paiflowHost, '/swap');

  static Uri get usdcFaucet => Uri.https('faucet.circle.com', '/');

  static String newLinkCode() {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<String?> waitForWalletLink(
    String code, {
    required bool Function() keepWaiting,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (keepWaiting() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final res = await http
            .get(Uri.http(paiflowHost, '/api/wallet-link', {'code': code}))
            .timeout(const Duration(seconds: 10));
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final address = body['address'];
        if (body['status'] == 'linked' &&
            address is String &&
            stellarAddressPattern.hasMatch(address)) {
          return address;
        }
      } catch (_) {}
    }
    return null;
  }
}

Future<Uint8List> shrinkToPng(Uint8List bytes, {int width = 192}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  return data!.buffer.asUint8List();
}
