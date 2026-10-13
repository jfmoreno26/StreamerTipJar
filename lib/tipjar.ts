// Tip jar rules. These mirror the Paiflow flow you deployed, so the preview in the UI matches what
// the deployment does. The deployment itself is what actually moves the money; changing numbers
// here only changes the preview text, so keep them in sync with the Paiflow nodes.
//
//   On Receive (USDC) -> Condition (amount > 50 USDC)
//     TRUE  -> Split: Streamer 60% / Staff 25% / Charity 15%
//     FALSE -> Split: Streamer 60% / Staff 40%

export const ASSET = "USDC";

/** Condition node: strictly greater than this splits three ways, otherwise the two-way split applies. */
export const THRESHOLD_USDC = 50;

export interface Share {
  name: string;
  pct: number;
}

/** Tips over the threshold. */
export const BIG_TIP_SPLIT: Share[] = [
  { name: "Streamer's Wallet", pct: 60 },
  { name: "Staff Salary", pct: 25 },
  { name: "Charity Fund", pct: 15 },
];

/** Tips at or below the threshold. */
export const SMALL_TIP_SPLIT: Share[] = [
  { name: "Streamer's Wallet", pct: 60 },
  { name: "Staff Salary", pct: 40 },
];

export function splitFor(amountUsdc: number): Share[] {
  return amountUsdc > THRESHOLD_USDC ? BIG_TIP_SPLIT : SMALL_TIP_SPLIT;
}
