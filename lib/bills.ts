export type PaymentStatus = "PREPARED" | "PENDING" | "SUCCESS" | "FAILED";
export type BillStatus = "UNPAID" | "PENDING" | "PAID" | "OVERDUE";

/** Paiflow preparations last about 180s. Block new attempts a little longer, in case the wallet was left open. */
export const PREPARATION_HOLD_MS = 200_000;

export interface Payment {
  attemptId: string;
  txHash?: string; // known once Paiflow accepted the submission
  status: PaymentStatus;
  createdAt: string;
  updatedAt: string;
  note?: string;
}

export interface Bill {
  id: string;
  title: string;
  payer: string;
  amountStroops: string; // server-set price, never taken from the client
  dueDate: string;
  createdAt: string;
  payments: Payment[];
}

const ALLOWED: Record<PaymentStatus, PaymentStatus[]> = {
  PREPARED: ["PREPARED", "PENDING", "SUCCESS", "FAILED"],
  PENDING: ["PENDING", "SUCCESS", "FAILED"],
  SUCCESS: ["SUCCESS"], // terminal
  FAILED: ["FAILED"], // terminal; a retry is a brand-new attempt
};

export function canTransition(from: PaymentStatus, to: PaymentStatus): boolean {
  return ALLOWED[from].includes(to);
}

/** Does this attempt block a new payment? PENDING always does; PREPARED only while its preparation could still be signed. */
export function blocksNewAttempt(p: Payment, now: Date = new Date()): boolean {
  if (p.status === "PENDING") return true;
  if (p.status === "PREPARED") return now.getTime() - Date.parse(p.createdAt) < PREPARATION_HOLD_MS;
  return false;
}

export function billStatus(bill: Bill, now: Date = new Date()): BillStatus {
  if (bill.payments.some((p) => p.status === "SUCCESS")) return "PAID";
  if (bill.payments.some((p) => blocksNewAttempt(p, now))) return "PENDING";
  if (Date.parse(bill.dueDate) < now.getTime()) return "OVERDUE";
  return "UNPAID";
}
