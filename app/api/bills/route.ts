import { NextResponse } from "next/server";
import { createBill, listBills } from "@/lib/store";
import { billStatus } from "@/lib/bills";
import { toStroops } from "@/lib/money";

// GET: all bills with their derived status (used by /bills and /admin).
export async function GET() {
  const bills = await listBills();
  return NextResponse.json(bills.map((b) => ({ ...b, status: billStatus(b) })));
}

// POST { title, payer, amountXlm, dueDate }: create a bill. The price is fixed here, server side.
export async function POST(req: Request) {
  const b = await req.json().catch(() => null);
  if (!b || typeof b !== "object") return NextResponse.json({ error: "Invalid request" }, { status: 422 });

  const title = String(b.title ?? "").trim();
  const payer = String(b.payer ?? "").trim();
  const due = Date.parse(String(b.dueDate ?? ""));
  if (!title || title.length > 200) return NextResponse.json({ error: "Title is required" }, { status: 400 });
  if (!payer || payer.length > 200) return NextResponse.json({ error: "Payer is required" }, { status: 400 });
  if (!Number.isFinite(due)) return NextResponse.json({ error: "Invalid due date" }, { status: 400 });

  let amountStroops: string;
  try {
    amountStroops = toStroops(String(b.amountXlm ?? ""));
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }

  const bill = await createBill({ title, payer, amountStroops, dueDate: new Date(due).toISOString() });
  return NextResponse.json({ ...bill, status: billStatus(bill) }, { status: 201 });
}
