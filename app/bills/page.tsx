"use client";
import { useEffect, useRef, useState } from "react";
import { requestAccess, getAddress, getNetworkDetails, signTransaction } from "@stellar/freighter-api";

const TESTNET = "Test SDF Network ; September 2015";

type Row = {
  id: string; title: string; payer: string; amountStroops: string; dueDate: string; status: string;
  payments: { attemptId: string; txHash?: string; status: string }[];
};
const xlm = (s: string) => (Number(s) / 1e7).toString();

async function post(id: string, body: object) {
  const res = await fetch(`/api/bills/${id}/pay`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  const out = await res.json();
  if (!res.ok || out.error) throw new Error(out.error || `HTTP ${res.status}`);
  return out;
}

export default function Bills() {
  const [rows, setRows] = useState<Row[]>([]);
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);
  const working = useRef(false);
  // Signed envelopes live only in tab memory (as in the quickstart). Reloading loses them; the server still holds the attempt.
  const envelopes = useRef<Record<string, { attemptId: string; signedXdr: string; preparationRequestId: string | null }>>({});

  const load = async () => setRows(await (await fetch("/api/bills")).json());
  useEffect(() => { load(); }, []);

  async function run(fn: () => Promise<void>) {
    if (working.current) return;
    working.current = true; setBusy(true); setMsg("");
    try { await fn(); } catch (e: any) { setMsg(e.message); } finally { working.current = false; setBusy(false); load(); }
  }

  const pay = (id: string) => run(async () => {
    if (envelopes.current[id]) throw new Error("A signed payment is waiting. Use Check again.");
    const access: any = await requestAccess();
    if (access.error || !access.address) throw new Error("Allow Freighter access.");
    const net: any = await getNetworkDetails();
    if (net.error || net.networkPassphrase !== TESTNET) throw new Error("Switch Freighter to Testnet.");
    const prepared = await post(id, { action: "prepare", from: access.address });
    if (prepared.network !== "testnet" || prepared.networkPassphrase !== TESTNET || !(Date.parse(prepared.expiresAt) > Date.now()))
      throw new Error("Check the preparation network and expiry.");
    const cur: any = await getAddress();
    if (cur.error || cur.address !== access.address) throw new Error("Wallet changed. Start again.");
    const signed: any = await signTransaction(prepared.xdr, { networkPassphrase: TESTNET, address: access.address });
    if (signed.error || !signed.signedTxXdr || signed.signerAddress !== access.address) throw new Error("Payment was not signed by the expected customer.");
    envelopes.current[id] = { attemptId: prepared.attemptId, signedXdr: signed.signedTxXdr, preparationRequestId: prepared.preparationRequestId };
    await checkAgain(id);
  });

  async function checkAgain(id: string) {
    const env = envelopes.current[id];
    const bill = env
      ? await post(id, { action: "submit", ...env })
      : await post(id, { action: "verify", attemptId: rows.find((r) => r.id === id)?.payments.find((p) => p.status === "PENDING")?.attemptId });
    if (bill.status === "PAID" || bill.status === "UNPAID" || bill.status === "OVERDUE") delete envelopes.current[id];
    setMsg(bill.status === "PAID" ? "Payment confirmed." : bill.status === "PENDING" ? "Still pending. Check again shortly. You will not be charged twice." : "Payment failed. You can try again.");
  }

  return (
    <main style={{ maxWidth: 720, margin: "2rem auto", fontFamily: "system-ui", padding: "0 1rem" }}>
      <h1>My bills</h1>
      <p style={{ color: "#666" }}>Amounts are testnet XLM, fixed for the demo. A real version would use a stable asset like USDC.</p>
      {msg && <p role="alert">{msg}</p>}
      {busy && <p>Waiting for the wallet or network…</p>}
      {rows.map((r) => (
        <section key={r.id} style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12, margin: "12px 0" }}>
          <strong>{r.title}</strong> for {r.payer}: {xlm(r.amountStroops)} XLM, due {r.dueDate.slice(0, 10)} <em>[{r.status}]</em>
          <div>
            {(r.status === "UNPAID" || r.status === "OVERDUE") && <button disabled={busy} onClick={() => pay(r.id)}>Pay {xlm(r.amountStroops)} XLM</button>}
            {r.status === "PENDING" && <button disabled={busy} onClick={() => run(() => checkAgain(r.id))}>Check again</button>}
          </div>
          {r.payments.filter((p) => p.txHash).map((p) => (
            <div key={p.attemptId} style={{ fontSize: 12 }}>
              <a href={`https://stellar.expert/explorer/testnet/tx/${p.txHash}`} target="_blank" rel="noreferrer">{p.txHash!.slice(0, 12)}…</a> {p.status}
            </div>
          ))}
        </section>
      ))}
    </main>
  );
}
