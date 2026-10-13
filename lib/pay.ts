import { randomUUID } from "crypto";
import { billStatus, blocksNewAttempt, canTransition, type Bill, type Payment, type PaymentStatus } from "./bills";
import { withBills } from "./store";
import type { PaiflowClient, Prepared } from "./billing-paiflow";

export class PayError extends Error {
  constructor(message: string, public code: number, public retryAfter?: string | null) {
    super(message);
  }
}

const STELLAR_ADDRESS = /^G[A-Z2-7]{55}$/;
const UUID = /^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

/** Paiflow SUCCESS and FAILED are final. REJECTED means the submission was refused (never on-chain). Everything else is uncertain. */
export function mapStatus(s: string): PaymentStatus {
  const v = s.toUpperCase();
  if (v === "SUCCESS") return "SUCCESS";
  if (v === "FAILED" || v === "REJECTED") return "FAILED";
  return "PENDING"; // PENDING, UNKNOWN, anything unexpected: keep checking the same transaction
}

function applyStatus(p: Payment, next: PaymentStatus, note?: string) {
  if (!canTransition(p.status, next)) return;
  p.status = next;
  p.updatedAt = new Date().toISOString();
  if (note) p.note = note;
}

/** Step 1: server prepares an unsigned payment at the bill's own price. */
export async function prepareBill(billId: string, from: string, paiflow: PaiflowClient): Promise<Prepared & { attemptId: string }> {
  if (!STELLAR_ADDRESS.test(from)) throw new PayError("Invalid wallet address", 400);
  const attemptId = randomUUID();

  const amount = await withBills((bills) => {
    const bill = bills.find((b) => b.id === billId);
    if (!bill) throw new PayError("Bill not found", 404);
    const status = billStatus(bill);
    if (status === "PAID") throw new PayError("Bill is already paid", 409);
    if (status === "PENDING") throw new PayError("A payment is already in progress. Check it instead of paying again.", 409);
    const now = new Date().toISOString();
    bill.payments.push({ attemptId, status: "PREPARED", createdAt: now, updatedAt: now });
    return bill.amountStroops;
  });

  try {
    const prepared = await paiflow.prepare(from, amount);
    return { ...prepared, attemptId };
  } catch (e) {
    // Nothing signable was returned, so the attempt can be dropped safely.
    await withBills((bills) => {
      const bill = bills.find((b) => b.id === billId)!;
      bill.payments = bill.payments.filter((p) => p.attemptId !== attemptId);
    });
    throw e;
  }
}

/** Step 2: submit the wallet-signed envelope. Safe to call again with the same envelope after an uncertain result. */
export async function submitBill(
  billId: string, attemptId: string, signedXdr: string, preparationRequestId: string | null, paiflow: PaiflowClient,
): Promise<Bill> {
  if (!UUID.test(attemptId)) throw new PayError("Invalid attempt", 400);
  if (typeof signedXdr !== "string" || signedXdr.length < 10 || signedXdr.length > 200000) throw new PayError("Invalid signed transaction", 400);
  if (preparationRequestId != null && !UUID.test(preparationRequestId)) throw new PayError("Invalid preparation id", 400);

  await withBills((bills) => {
    const p = bills.find((b) => b.id === billId)?.payments.find((x) => x.attemptId === attemptId);
    if (!p) throw new PayError("Payment attempt not found", 404);
    if (p.status === "SUCCESS" || p.status === "FAILED") throw new PayError(`Attempt already ${p.status}`, 409);
    applyStatus(p, "PENDING"); // saved BEFORE submitting so a crash cannot lose it
  });

  let next: PaymentStatus = "PENDING";
  let txHash: string | undefined;
  let note: string | undefined;
  try {
    const r = await paiflow.submit(signedXdr, preparationRequestId);
    next = mapStatus(r.status);
    txHash = r.txHash;
  } catch (e: any) {
    note = `submit uncertain: ${e.message}`; // stays PENDING; the client retries the same envelope
  }

  return withBills((bills) => {
    const bill = bills.find((b) => b.id === billId)!;
    const p = bill.payments.find((x) => x.attemptId === attemptId)!;
    if (txHash && /^[a-f0-9]{64}$/i.test(txHash)) p.txHash = txHash;
    applyStatus(p, next, note);
    return bill;
  });
}

/** Look up the ORIGINAL transaction. Never creates a payment. UNKNOWN/404/timeouts leave it PENDING. */
export async function verifyBill(billId: string, attemptId: string, paiflow: PaiflowClient): Promise<Bill> {
  const txHash = await withBills((bills) => {
    const p = bills.find((b) => b.id === billId)?.payments.find((x) => x.attemptId === attemptId);
    if (!p) throw new PayError("Payment attempt not found", 404);
    return p.txHash;
  });
  if (!txHash) throw new PayError("No transaction hash yet. Retry submitting the same signed payment.", 409);

  let next: PaymentStatus = "PENDING";
  let note: string | undefined;
  try {
    next = mapStatus((await paiflow.lookup(txHash)).status);
  } catch (e: any) {
    note = `lookup uncertain: ${e.message}`;
  }

  return withBills((bills) => {
    const bill = bills.find((b) => b.id === billId)!;
    applyStatus(bill.payments.find((x) => x.attemptId === attemptId)!, next, note);
    return bill;
  });
}

export { blocksNewAttempt };
