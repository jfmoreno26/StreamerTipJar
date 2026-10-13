// Stroop math. 1 USDC (or 1 XLM) on Stellar = 10_000_000 stroops. All values are bigint strings.
const SCALE = 7;

export function toStroops(input: string): string {
  const s = input.trim();
  if (!/^\d+(\.\d{1,7})?$/.test(s)) throw new Error(`Invalid amount: "${input}"`);
  const [whole, frac = ""] = s.split(".");
  const v = BigInt(whole) * 10n ** BigInt(SCALE) + BigInt(frac.padEnd(SCALE, "0"));
  if (v <= 0n) throw new Error("Amount must be greater than zero");
  return v.toString();
}

export function fromStroops(stroops: string): string {
  const v = BigInt(stroops);
  const whole = v / 10n ** BigInt(SCALE);
  const frac = (v % 10n ** BigInt(SCALE)).toString().padStart(SCALE, "0").replace(/0+$/, "");
  return frac ? `${whole}.${frac}` : whole.toString();
}

/** Split a total across basis-point shares; remainder goes to the first recipient so the sum is exact. */
export function splitByBps(totalStroops: string, bps: number[]): string[] {
  if (bps.reduce((a, b) => a + b, 0) !== 10000) throw new Error("Shares must total 10000 bps");
  const total = BigInt(totalStroops);
  const parts = bps.map((b) => (total * BigInt(b)) / 10000n);
  const rem = total - parts.reduce((a, b) => a + b, 0n);
  parts[0] += rem;
  return parts.map(String);
}
