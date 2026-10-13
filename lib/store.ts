import { promises as fs } from "fs";
import path from "path";
import { randomUUID } from "crypto";
import type { Bill } from "./bills";

const file = () => process.env.BILLS_FILE ?? path.join(process.cwd(), "data", "bills.json");

// Serialize all read-modify-write cycles within this process.
let queue: Promise<unknown> = Promise.resolve();

async function load(): Promise<Bill[]> {
  try {
    return JSON.parse(await fs.readFile(file(), "utf8")) as Bill[];
  } catch (e: any) {
    if (e.code === "ENOENT") return [];
    throw e;
  }
}

async function save(bills: Bill[]): Promise<void> {
  await fs.mkdir(path.dirname(file()), { recursive: true });
  const tmp = `${file()}.${randomUUID()}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(bills, null, 2));
  await fs.rename(tmp, file()); // atomic replace
}

export function withBills<T>(fn: (bills: Bill[]) => T | Promise<T>): Promise<T> {
  const run = queue.then(async () => {
    const bills = await load();
    const result = await fn(bills);
    await save(bills);
    return result;
  });
  queue = run.catch(() => undefined);
  return run;
}

export async function listBills(): Promise<Bill[]> {
  return withBills((b) => b);
}

export async function getBill(id: string): Promise<Bill | undefined> {
  return (await listBills()).find((b) => b.id === id);
}

export async function createBill(input: { title: string; payer: string; amountStroops: string; dueDate: string }): Promise<Bill> {
  const bill: Bill = { id: randomUUID(), createdAt: new Date().toISOString(), payments: [], ...input };
  await withBills((b) => void b.push(bill));
  return bill;
}
