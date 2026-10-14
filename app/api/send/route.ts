import { NextResponse } from "next/server";
import { PaiflowError, createPaiflowClient, mapStatus } from "@/lib/billing-paiflow";
import { toStroops } from "@/lib/money";
import { parseTip, recordTip } from "@/lib/tip-records";

const STELLAR_ADDRESS = /^G[A-Z2-7]{55}$/;
const UUID = /^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

class SendError extends Error {
  constructor(message: string, public code: number) {
    super(message);
  }
}

// POST { action: "prepare", from, amountUsdc } | { action: "submit", signedXdr, preparationRequestId, tip? } | { action: "verify", txHash, tip? }
// With tip info (opened from the JarJar app), the payment is recorded in that user's tip history.
// Prepare -> sign in Freighter -> submit. The fan picks the tip amount.
// The Paiflow deployment decides the split: over 50 USDC goes three ways (streamer, staff, charity),
// 50 USDC or less goes two ways (streamer, staff).
export async function POST(req: Request) {
  try {
    const b = await req.json().catch(() => null);
    if (!b || typeof b !== "object") throw new SendError("Invalid request", 422);
    const paiflow = createPaiflowClient();

    if (b.action === "prepare") {
      if (!STELLAR_ADDRESS.test(String(b.from ?? ""))) throw new SendError("Invalid wallet address", 400);
      let amount: string;
      try {
        amount = toStroops(String(b.amountUsdc ?? ""));
      } catch (e: any) {
        throw new SendError(e.message, 400);
      }
      return NextResponse.json(await paiflow.prepare(b.from, amount));
    }
    if (b.action === "submit") {
      if (typeof b.signedXdr !== "string" || b.signedXdr.length < 10 || b.signedXdr.length > 200000) throw new SendError("Invalid signed transaction", 400);
      const prepId = b.preparationRequestId ?? null;
      if (prepId != null && !UUID.test(prepId)) throw new SendError("Invalid preparation id", 400);
      const r = await paiflow.submit(b.signedXdr, prepId);
      const status = mapStatus(r.status);
      const tip = parseTip(b.tip);
      if (tip) await recordTip(tip, status, r.txHash);
      return NextResponse.json({ status, txHash: r.txHash });
    }
    if (b.action === "verify") {
      const r = await paiflow.lookup(String(b.txHash ?? ""));
      const status = mapStatus(r.status);
      const tip = parseTip(b.tip);
      if (tip) await recordTip(tip, status, String(b.txHash));
      return NextResponse.json({ status, txHash: b.txHash });
    }
    throw new SendError("Unknown action", 422);
  } catch (e: any) {
    const code = e instanceof SendError ? e.code : e instanceof PaiflowError ? 502 : 500;
    const res = NextResponse.json({ error: e.message }, { status: code });
    if (e.retryAfter) res.headers.set("Retry-After", e.retryAfter);
    return res;
  }
}