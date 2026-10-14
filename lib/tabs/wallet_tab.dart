import 'package:flutter/material.dart';

import '../neon.dart';
import '../wallet.dart';
import '../widgets.dart';

class WalletTab extends StatelessWidget {
  final String? address;
  final VoidCallback onConnect;
  final VoidCallback onEnterManually;
  final VoidCallback onDisconnect;
  final VoidCallback onGetUsdc;
  final VoidCallback onSwap;
  final VoidCallback onOpenPayment;
  final ValueChanged<String> onMessage;

  const WalletTab({
    super.key,
    required this.address,
    required this.onConnect,
    required this.onEnterManually,
    required this.onDisconnect,
    required this.onGetUsdc,
    required this.onSwap,
    required this.onOpenPayment,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final linked = address;
    return TabPage(
      children: [
        const SectionHeading(
          title: 'Wallet',
          subtitle: 'Your live PaiFlow balance on Stellar Testnet',
        ),
        const SizedBox(height: 20),
        if (linked != null)
          LiveWalletCard(
            address: linked,
            onDisconnect: onDisconnect,
            onGetUsdc: onGetUsdc,
            onSwap: onSwap,
            onMessage: onMessage,
          )
        else
          _ConnectCard(onConnect: onConnect, onEnterManually: onEnterManually),
        const SizedBox(height: 18),
        _PayWithPaiFlowCard(onOpenPayment: onOpenPayment),
      ],
    );
  }
}

class _ConnectCard extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onEnterManually;

  const _ConnectCard({required this.onConnect, required this.onEnterManually});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: Neon.brandGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Neon.pink.withValues(alpha: 0.5 * c.glow),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect your Freighter wallet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'See how much USDC you have left for tipping, updated live from the '
            'Stellar network. JarJar only reads your public address — it can '
            'never move funds.',
            style: TextStyle(color: c.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          GlowButton(
            label: 'Connect with Freighter',
            icon: Icons.link_rounded,
            expand: true,
            onPressed: onConnect,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onEnterManually,
              child: const Text('Enter address manually'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayWithPaiFlowCard extends StatelessWidget {
  final VoidCallback onOpenPayment;

  const _PayWithPaiFlowCard({required this.onOpenPayment});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Neon.violet),
              const SizedBox(width: 10),
              Text(
                'Pay with PaiFlow',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tips are shown in US dollars and settled in USDC on Stellar. '
            'You approve every payment in Freighter.',
            style: TextStyle(height: 1.5, color: c.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onOpenPayment,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open payment page'),
          ),
        ],
      ),
    );
  }
}
