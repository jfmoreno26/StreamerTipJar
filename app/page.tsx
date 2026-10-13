import Link from "next/link";
import { ASSET, BIG_TIP_SPLIT, SMALL_TIP_SPLIT, THRESHOLD_USDC } from "@/lib/tipjar";

const list = (shares: { name: string; pct: number }[]) => shares.map((s) => `${s.name} ${s.pct}%`).join(" · ");

export default function Home() {
  return (
    <main style={{ maxWidth: 560, margin: "3rem auto", fontFamily: "system-ui", padding: "0 1rem" }}>
      <h1 style={{ fontSize: 36, marginBottom: 8 }}>Streamer Tip Jar</h1>
      <p style={{ fontSize: 18 }}>
        Fans tip once in {ASSET}. The tip is automatically shared with the streamer, their team and a charity. No manual splitting.
      </p>

      <div style={{ border: "1px solid #888", borderRadius: 8, padding: 16, margin: "24px 0" }}>
        <strong>How your tip is shared</strong>
        <p style={{ marginBottom: 4 }}>Over {THRESHOLD_USDC} {ASSET}:</p>
        <div>{list(BIG_TIP_SPLIT)}</div>
        <p style={{ marginBottom: 4 }}>{THRESHOLD_USDC} {ASSET} or less:</p>
        <div>{list(SMALL_TIP_SPLIT)}</div>
        <p style={{ fontSize: 12, color: "#666" }}>Runs on Stellar testnet through a Paiflow deployment.</p>
      </div>

      <Link
        href="/send"
        style={{ display: "inline-block", padding: "12px 20px", borderRadius: 8, background: "#111", color: "#fff", textDecoration: "none" }}
      >
        Tip the streamer
      </Link>
    </main>
  );
}
