"use client";
import { useRef, useState } from "react";
import { requestAccess, getAddress, getNetworkDetails, signTransaction } from "@stellar/freighter-api";
import { ASSET, THRESHOLD_USDC, splitFor } from "@/lib/tipjar";

const TESTNET = "Test SDF Network ; September 2015";

async function post(body: object) {
  const res = await fetch("/api/send", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  const out = await res.json();
  if (!res.ok || out.error) throw new Error(out.error || `HTTP ${res.status}`);
  return out;
}

export default function SendTip() {
  const [amount, setAmount] = useState("");
  const [msg, setMsg] = useState("");
  const [txHash, setTxHash] = useState("");
  const [pending, setPending] = useState(false);
  const [busy, setBusy] = useState(false);
  const working = useRef(false);
  // Signed envelope lives only in tab memory, so "Check again" resubmits the same one instead of tipping twice.
  const envelope = useRef<{ signedXdr: string; preparationRequestId: string | null } | null>(null);

  const usdc = Number(amount);
  const valid = /^\d+(\.\d{1,7})?$/.test(amount.trim()) && usdc > 0;
  const bigTip = valid && usdc > THRESHOLD_USDC;

  async function run(fn: () => Promise<void>) {
    if (working.current) return;
    working.current = true; setBusy(true); setMsg("");
    try { await fn(); } catch (e: any) { setMsg(e.message); } finally { working.current = false; setBusy(false); }
  }

  const send = (e: React.FormEvent) => {
    e.preventDefault();
    run(async () => {
      if (envelope.current || pending) throw new Error("A signed tip is waiting. Use Check again.");
      const access: any = await requestAccess();
      if (access.error || !access.address) throw new Error("Allow Freighter access.");
      const net: any = await getNetworkDetails();
      if (net.error || net.networkPassphrase !== TESTNET) throw new Error("Switch Freighter to Testnet.");
      const prepared = await post({ action: "prepare", from: access.address, amountUsdc: amount.trim() });
      if (prepared.network !== "testnet" || prepared.networkPassphrase !== TESTNET || !(Date.parse(prepared.expiresAt) > Date.now()))
        throw new Error("Check the preparation network and expiry.");
      const cur: any = await getAddress();
      if (cur.error || cur.address !== access.address) throw new Error("Wallet changed. Start again.");
      const signed: any = await signTransaction(prepared.xdr, { networkPassphrase: TESTNET, address: access.address });
      if (signed.error || !signed.signedTxXdr || signed.signerAddress !== access.address) throw new Error("Tip was not signed by your wallet.");
      envelope.current = { signedXdr: signed.signedTxXdr, preparationRequestId: prepared.preparationRequestId };
      await checkAgain();
    });
  };

  async function checkAgain() {
    let r: { status: string; txHash?: string };
    if (txHash) r = await post({ action: "verify", txHash });
    else if (envelope.current) r = await post({ action: "submit", ...envelope.current });
    else throw new Error("Nothing to check.");
    if (r.txHash) setTxHash(r.txHash);
    if (r.status === "SUCCESS" || r.status === "FAILED") { envelope.current = null; setPending(false); }
    else setPending(true);
    setMsg(r.status === "SUCCESS" ? "Tip sent. Thank you!" : r.status === "PENDING" ? "Still pending. Check again shortly. You will not be charged twice." : "Tip failed. You can try again.");
  }

  function reset() { envelope.current = null; setTxHash(""); setPending(false); setMsg(""); setAmount(""); }

  return (
    <main style={{ maxWidth: 480, margin: "2rem auto", fontFamily: "system-ui", padding: "0 1rem" }}>
      <h1>Tip the streamer</h1>
      <p style={{ color: "#666" }}>
        Tips go straight to the streamer and their team. Over {THRESHOLD_USDC} {ASSET}, part of your tip also funds the community charity.
      </p>
      <form onSubmit={send} style={{ display: "grid", gap: 12 }}>
        <label>
          Tip amount (testnet {ASSET})
          <input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" required style={{ width: "100%", padding: 8 }} />
        </label>
        {valid && (
          <div style={{ padding: 8, border: "1px solid #888", borderRadius: 6 }}>
            <strong>{bigTip ? "Big tip! Your tip will be split three ways:" : "Your tip will be split:"}</strong>
            <ul>
              {splitFor(usdc).map((s) => (
                <li key={s.name}>{s.name} {s.pct}% — {((usdc * s.pct) / 100).toFixed(2)} {ASSET}</li>
              ))}
            </ul>
            {!bigTip && <small>Tip more than {THRESHOLD_USDC} {ASSET} to also support the Charity Fund.</small>}
          </div>
        )}
        <button type="submit" disabled={busy || !valid || pending}>Send tip with Freighter</button>
      </form>
      {busy && <p>Waiting for the wallet or network…</p>}
      {msg && <p role="alert">{msg}</p>}
      {pending && <button disabled={busy} onClick={() => run(checkAgain)}>Check again</button>}
      {txHash && (
        <p style={{ fontSize: 12 }}>
          <a href={`https://stellar.expert/explorer/testnet/tx/${txHash}`} target="_blank" rel="noreferrer">{txHash.slice(0, 12)}…</a>
          {!pending && <> · <button onClick={reset}>Send another tip</button></>}
        </p>
      )}
    </main>
  );
}
