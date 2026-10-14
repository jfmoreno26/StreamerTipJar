import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'neon.dart';

const horizonTestnet = 'https://horizon-testnet.stellar.org';

const circleUsdcIssuer =
    'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

final stellarAddressPattern = RegExp(r'^G[A-Z2-7]{55}$');

String shortAddress(String address) =>
    '${address.substring(0, 6)}…${address.substring(address.length - 6)}';

class WalletBalance {
  final double xlm;

  final double? usdc;

  const WalletBalance({required this.xlm, required this.usdc});
}

Future<WalletBalance?> fetchWalletBalance(String address) async {
  final res = await http
      .get(Uri.parse('$horizonTestnet/accounts/$address'))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) throw Exception('Horizon HTTP ${res.statusCode}');

  final balances = (jsonDecode(res.body)['balances'] as List)
      .cast<Map<String, dynamic>>();
  double amount(Map<String, dynamic> b) =>
      double.tryParse('${b['balance']}') ?? 0;

  final native = balances.where((b) => b['asset_type'] == 'native');
  final usdc = balances.where((b) => b['asset_code'] == 'USDC').toList()
    ..sort(
      (a, b) =>
          (b['asset_issuer'] == circleUsdcIssuer ? 1 : 0) -
          (a['asset_issuer'] == circleUsdcIssuer ? 1 : 0),
    );

  return WalletBalance(
    xlm: native.isEmpty ? 0 : amount(native.first),
    usdc: usdc.isEmpty ? null : amount(usdc.first),
  );
}

Future<void> fundWithFriendbot(String address) async {
  final res = await http
      .get(Uri.https('friendbot.stellar.org', '/', {'addr': address}))
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    final detail = res.body.contains('createAccountAlreadyExist')
        ? 'This wallet is already activated — Friendbot only funds new wallets.'
        : 'Friendbot could not fund this wallet (HTTP ${res.statusCode}).';
    throw Exception(detail);
  }
}

class LiveWalletCard extends StatefulWidget {
  final String address;
  final VoidCallback onDisconnect;
  final VoidCallback onGetUsdc;
  final VoidCallback onSwap;
  final ValueChanged<String> onMessage;

  const LiveWalletCard({
    super.key,
    required this.address,
    required this.onDisconnect,
    required this.onGetUsdc,
    required this.onSwap,
    required this.onMessage,
  });

  @override
  State<LiveWalletCard> createState() => _LiveWalletCardState();
}

class _LiveWalletCardState extends State<LiveWalletCard> {
  static const _pollEvery = Duration(seconds: 8);

  Timer? _timer;
  WalletBalance? _balance;
  bool _activated = true;
  bool _loading = true;
  bool _funding = false;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_pollEvery, (_) => _refresh());
  }

  @override
  void didUpdateWidget(LiveWalletCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      setState(() {
        _balance = null;
        _loading = true;
      });
      _refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final balance = await fetchWalletBalance(widget.address);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _activated = balance != null;
        _error = null;
        _loading = false;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Can\'t reach the Stellar network right now. Retrying…';
        _loading = false;
      });
    }
  }

  Future<void> _getXlm() async {
    setState(() => _funding = true);
    try {
      await fundWithFriendbot(widget.address);
      widget.onMessage('10,000 test XLM added to your wallet.');
      await _refresh();
    } catch (e) {
      widget.onMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _funding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final usdc = _balance?.usdc;
    final time = _updatedAt == null
        ? ''
        : TimeOfDay.fromDateTime(_updatedAt!).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2A1468), Neon.purple, Neon.pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: -40,
                  top: -30,
                  width: 220,
                  height: 220,
                  child: CustomPaint(painter: PlanetPainter()),
                ),
                const Positioned.fill(
                  child: TwinkleField(
                    points: [
                      Offset(0.08, 0.2),
                      Offset(0.45, 0.12),
                      Offset(0.3, 0.75),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _LiveDot(active: _error == null && !_loading),
                          const SizedBox(width: 8),
                          Text(
                            _loading
                                ? 'CONNECTING…'
                                : _error != null
                                ? 'RECONNECTING'
                                : 'LIVE BALANCE · $time',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1.6,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const SizedBox(
                          height: 52,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (!_activated)
                        const Text(
                          'Not activated yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        _AnimatedAmount(value: usdc ?? 0, suffix: 'USDC'),
                      const SizedBox(height: 6),
                      if (!_loading && _activated)
                        Text(
                          usdc == null
                              ? 'No USDC yet · ${_balance!.xlm.toStringAsFixed(2)} XLM for fees'
                              : '${_balance!.xlm.toStringAsFixed(2)} XLM for network fees',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      if (!_loading && !_activated)
                        Text(
                          'Get free test XLM below to activate this wallet on Stellar Testnet.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _AddressChip(
                            address: widget.address,
                            onCopied: widget.onMessage,
                          ),
                          IconButton(
                            tooltip: 'Refresh now',
                            onPressed: _refresh,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Neon.gold)),
        ],
        const SizedBox(height: 16),
        NeonCard(
          accent: Neon.cyan,
          onTap: _activated ? widget.onSwap : null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Neon.cyan, Neon.purple],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Neon.cyan.withValues(alpha: 0.4 * c.glow),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swap XLM ⇄ USDC',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activated
                          ? 'Exchange between your XLM and USDC with Freighter. '
                                'Your balance here updates once it\'s done.'
                          : 'Activate your wallet with test XLM first.',
                      style: TextStyle(color: c.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GlowButton(
                label: 'Swap',
                icon: Icons.swap_horiz_rounded,
                gradient: const LinearGradient(
                  colors: [Neon.cyan, Neon.purple],
                ),
                onPressed: _activated ? widget.onSwap : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NeonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add funds',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Testnet only — these are free test tokens, not real money. '
                'To receive USDC, first add USDC to your assets in Freighter.',
                style: TextStyle(color: c.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GlowButton(
                    label: 'Get test USDC',
                    icon: Icons.attach_money_rounded,
                    onPressed: widget.onGetUsdc,
                  ),
                  OutlinedButton.icon(
                    onPressed: _funding ? null : _getXlm,
                    icon: _funding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      _activated ? 'Get test XLM' : 'Activate with test XLM',
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              TextButton.icon(
                onPressed: widget.onDisconnect,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect wallet'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedAmount extends StatelessWidget {
  final double value;
  final String suffix;

  const _AnimatedAmount({required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: v.toStringAsFixed(2)),
            TextSpan(
              text: '  $suffix',
              style: const TextStyle(
                fontSize: 16,
                color: Neon.gold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Neon.cyan : Neon.gold;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 8)],
        ),
      ),
    );
  }
}

class _AddressChip extends StatelessWidget {
  final String address;
  final ValueChanged<String> onCopied;

  const _AddressChip({required this.address, required this.onCopied});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: address));
          onCopied('Wallet address copied.');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                shortAddress(address),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.copy_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
