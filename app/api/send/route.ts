import { NextResponse } from "next/server";
import { PaiflowError, createPaiflowClient } from "@/lib/billing-paiflow";
import { mapStatus } from "@/lib/pay";
import { toStroops } from "@/lib/money";

const STELLAR_ADDRESS = /^G[A-Z2-7]{55}$/;
const UUID = /^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

class SendError extends Error {
  constructor(message: string, public code: number) {
    super(message);
  }
}

// POST { action: "prepare", from, amountXlm } | { action: "submit", signedXdr, preparationRequestId } | { action: "verify", txHash }
// Same prepare -> sign in Freighter -> submit flow as /api/bills/[id]/pay, but the sender picks the amount.
// The deployment's condition node decides the split (> 50 XLM) or return to owner.
export async function POST(req: Request) {
  try {
    const b = await req.json().catch(() => null);
    if (!b || typeof b !== "object") throw new SendError("Invalid request", 422);
    const paiflow = createPaiflowClient();

    if (b.action === "prepare") {
      if (!STELLAR_ADDRESS.test(String(b.from ?? ""))) throw new SendError("Invalid wallet address", 400);
      let amount: string;
      try {
        amount = toStroops(String(b.amountXlm ?? ""));
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
      return NextResponse.json({ status: mapStatus(r.status), txHash: r.txHash });
    }
    if (b.action === "verify") {
      const r = await paiflow.lookup(String(b.txHash ?? ""));
      return NextResponse.json({ status: mapStatus(r.status), txHash: b.txHash });
    }
    throw new SendError("Unknown action", 422);
  } catch (e: any) {
    const code = e instanceof SendError ? e.code : e instanceof PaiflowError ? 502 : 500;
    const res = NextResponse.json({ error: e.message }, { status: code });
    if (e.retryAfter) res.headers.set("Retry-After", e.retryAfter);
    return res;
  }
}
