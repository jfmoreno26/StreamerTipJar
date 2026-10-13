import { NextResponse } from "next/server";
import { PayError, prepareBill, submitBill, verifyBill } from "@/lib/pay";
import { PaiflowError, createPaiflowClient } from "@/lib/billing-paiflow";
import { billStatus } from "@/lib/bills";

// POST { action: "prepare", from } | { action: "submit", attemptId, signedXdr, preparationRequestId } | { action: "verify", attemptId }
// The amount is never read from the request. It comes from the stored bill.
export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  try {
    const b = await req.json().catch(() => null);
    if (!b || typeof b !== "object") throw new PayError("Invalid request", 422);
    const paiflow = createPaiflowClient();
    if (b.action === "prepare") return NextResponse.json(await prepareBill(id, b.from, paiflow));
    if (b.action === "submit") {
      const bill = await submitBill(id, b.attemptId, b.signedXdr, b.preparationRequestId ?? null, paiflow);
      return NextResponse.json({ ...bill, status: billStatus(bill) });
    }
    if (b.action === "verify") {
      const bill = await verifyBill(id, b.attemptId, paiflow);
      return NextResponse.json({ ...bill, status: billStatus(bill) });
    }
    throw new PayError("Unknown action", 422);
  } catch (e: any) {
    const code = e instanceof PayError ? e.code : e instanceof PaiflowError ? 502 : 500;
    const res = NextResponse.json({ error: e.message }, { status: code });
    const retry = e.retryAfter;
    if (retry) res.headers.set("Retry-After", retry);
    return res;
  }
}
