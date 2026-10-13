# Streamer Tip Jar

Fans tip a streamer in USDC on Stellar testnet. A Paiflow deployment splits each tip automatically.

```
On Receive (USDC) -> Condition (amount > 50 USDC)
  TRUE  (over 50)        -> Split: Streamer's Wallet 60% / Staff Salary 25% / Charity Fund 15%
  FALSE (50 or less)     -> Split: Streamer's Wallet 60% / Staff Salary 40%
```

The flow lives in Paiflow, not in this repo. This app prepares the payment, the fan signs it in
Freighter, and the app submits it to the deployment. `lib/tipjar.ts` only drives the preview text,
so keep it in sync with the Paiflow nodes if you change the threshold or percentages.

## Pages

- `/` landing page that explains how tips are shared
- `/send` tip form (Freighter wallet on Testnet)

## Setup

Create `.env.local` (never commit it):

```
PAIFLOW_API_TOKEN=pfk_...
PAIFLOW_DEPLOYMENT_ID=<deployment uuid>
PAIFLOW_BASE_URL=https://<paiflow host>
```

```bash
pnpm install
pnpm dev
```

## Before demoing

- Streamer's Wallet, Staff Salary and Charity Fund each need a USDC trustline and a little testnet XLM.
- The fan wallet needs testnet USDC and a USDC trustline.
- Test one tip over 50 USDC (three-way split) and one at or below 50 USDC (two-way split).
