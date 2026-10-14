export const ASSET = "USDC";

export const THRESHOLD_USDC = 50;

export interface Share {
  name: string;
  pct: number;
}

export const BIG_TIP_SPLIT: Share[] = [
  { name: "Streamer's Wallet", pct: 60 },
  { name: "Staff Salary", pct: 25 },
  { name: "Charity Fund", pct: 15 },
];

export const SMALL_TIP_SPLIT: Share[] = [
  { name: "Streamer's Wallet", pct: 60 },
  { name: "Staff Salary", pct: 40 },
];

export function splitFor(amountUsdc: number): Share[] {
  return amountUsdc > THRESHOLD_USDC ? BIG_TIP_SPLIT : SMALL_TIP_SPLIT;
}
