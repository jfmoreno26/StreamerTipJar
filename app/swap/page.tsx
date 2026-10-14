"use client";

import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { getAddress, getNetworkDetails, requestAccess, signTransaction } from "@stellar/freighter-api";
import { Asset, BASE_FEE, Horizon, Networks, Operation, TransactionBuilder } from "@stellar/stellar-sdk";

const HORIZON = "https://horizon-testnet.stellar.org";
const USDC = new Asset("USDC", "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");
const XLM = Asset.native();
const SLIPPAGE = 0.01;
const server = new Horizon.Server(HORIZON);

type Direction = "XLM_TO_USDC" | "USDC_TO_XLM";
type Quote = { destAmount: string; path: Asset[] };
type Balances = { xlm: number; xlmSpendable: number; usdc: number | null };

const toAsset = (r: any) => (r.asset_type === "native" ? XLM : new Asset(r.asset_code, r.asset_issuer));
const queryAsset = (a: Asset) => (a.isNative() ? "native" : `${a.getCode()}:${a.getIssuer()}`);
const fmt = (n: number, d = 4) => n.toLocaleString(undefined, { maximumFractionDigits: d });

async function loadBalances(address: string): Promise<Balances> {
  const account = await server.loadAccount(address);
  const native = account.balances.find((b: any) => b.asset_type === "native") as any;
  const usdc = account.balances.find(
    (b: any) => b.asset_code === USDC.getCode() && b.asset_issuer === USDC.getIssuer(),
  ) as any;
  const xlm = Number(native?.balance ?? 0);
  const reserve = (2 + account.subentry_count) * 0.5 + Number(native?.selling_liabilities ?? 0);
  return { xlm, xlmSpendable: Math.max(0, xlm - reserve - 0.01), usdc: usdc ? Number(usdc.balance) : null };
}

async function fetchQuote(send: Asset, receive: Asset, amount: string): Promise<Quote | null> {
  const params = new URLSearchParams({ source_amount: amount, destination_assets: queryAsset(receive) });
  if (send.isNative()) params.set("source_asset_type", "native");
  else {
    params.set("source_asset_type", "credit_alphanum4");
    params.set("source_asset_code", send.getCode());
    params.set("source_asset_issuer", send.getIssuer() ?? "");
  }
  const res = await fetch(`${HORIZON}/paths/strict-send?${params}`);
  if (!res.ok) throw new Error("Could not get a price right now.");
  const records: any[] = (await res.json())._embedded?.records ?? [];
  if (!records.length) return null;
  const best = records.reduce((a, b) => (Number(b.destination_amount) > Number(a.destination_amount) ? b : a));
  return { destAmount: best.destination_amount, path: best.path.map(toAsset) };
}

function SwapForm() {
  const [address, setAddress] = useState("");
  const [balances, setBalances] = useState<Balances | null>(null);
  const [direction, setDirection] = useState<Direction>("XLM_TO_USDC");
  const [amount, setAmount] = useState("");
  const [quote, setQuote] = useState<Quote | null>(null);
  const [quoting, setQuoting] = useState(false);
  const [noRoute, setNoRoute] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [txHash, setTxHash] = useState("");
  const quoteId = useRef(0);

  const send = direction === "XLM_TO_USDC" ? XLM : USDC;
  const receive = direction === "XLM_TO_USDC" ? USDC : XLM;
  const sendCode = send.isNative() ? "XLM" : "USDC";
  const receiveCode = receive.isNative() ? "XLM" : "USDC";
  const available = !balances ? 0 : send.isNative() ? balances.xlmSpendable : balances.usdc ?? 0;
  const value = Number(amount);
  const validAmount = /^\d+(\.\d{1,7})?$/.test(amount) && value > 0;
  const tooMuch = validAmount && balances !== null && value > available;
  const minReceived = quote ? (Number(quote.destAmount) * (1 - SLIPPAGE)).toFixed(7) : "";

  const refreshBalances = useCallback(async (addr: string) => {
    try {
      setBalances(await loadBalances(addr));
    } catch {
      setError("This wallet isn't activated on Stellar Testnet yet. Get test XLM in the JarJar Wallet tab first.");
    }
  }, []);

  async function connect() {
    setError("");
    const access: any = await requestAccess();
    if (access.error || !access.address) {
      setError("Allow wallet access in Freighter to continue.");
      return;
    }
    const network: any = await getNetworkDetails();
    if (network.error || network.networkPassphrase !== Networks.TESTNET) {
      setError("Switch Freighter to Stellar Testnet, then try again.");
      return;
    }
    setAddress(access.address);
    await refreshBalances(access.address);
  }

  useEffect(() => {
    setQuote(null);
    setNoRoute(false);
    if (!/^\d+(\.\d{1,7})?$/.test(amount) || Number(amount) <= 0) {
      setQuoting(false);
      return;
    }
    const id = ++quoteId.current;
    setQuoting(true);
    const [from, to] = direction === "XLM_TO_USDC" ? [XLM, USDC] : [USDC, XLM];
    const timer = setTimeout(async () => {
      try {
        const q = await fetchQuote(from, to, amount);
        if (id !== quoteId.current) return;
        setQuote(q);
        setNoRoute(q === null);
      } catch (e) {
        if (id === quoteId.current) setError(e instanceof Error ? e.message : "Could not get a price.");
      } finally {
        if (id === quoteId.current) setQuoting(false);
      }
    }, 400);
    return () => clearTimeout(timer);
  }, [amount, direction]);

  async function swap() {
    if (!quote || !balances) return;
    setBusy(true);
    setError("");
    setTxHash("");
    try {
      const current: any = await getAddress();
      if (current.error || current.address !== address) throw new Error("The connected wallet changed. Reconnect and try again.");

      const account = await server.loadAccount(address);
      const builder = new TransactionBuilder(account, { fee: BASE_FEE, networkPassphrase: Networks.TESTNET });
      if (balances.usdc === null) builder.addOperation(Operation.changeTrust({ asset: USDC }));
      builder
        .addOperation(
          Operation.pathPaymentStrictSend({
            sendAsset: send,
            sendAmount: Number(amount).toFixed(7),
            destination: address,
            destAsset: receive,
            destMin: minReceived,
            path: quote.path,
          }),
        )
        .setTimeout(120);

      const signed: any = await signTransaction(builder.build().toXDR(), {
        networkPassphrase: Networks.TESTNET,
        address,
      });
      if (signed.error || !signed.signedTxXdr) throw new Error("Freighter did not sign the swap.");

      const result: any = await server.submitTransaction(
        TransactionBuilder.fromXDR(signed.signedTxXdr, Networks.TESTNET),
      );
      setTxHash(result.hash);
      setAmount("");
      await refreshBalances(address);
    } catch (e: any) {
      const codes = e?.response?.data?.extras?.result_codes;
      const op = codes?.operations?.find((c: string) => c !== "op_success");
      setError(
        op === "op_under_dest_min" || op === "op_too_few_offers"
          ? "The price moved before your swap went through. Get a fresh quote and try again."
          : op === "op_underfunded"
            ? `Not enough ${sendCode} for this swap.`
            : e instanceof Error && !codes
              ? e.message
              : "The swap failed. Nothing was exchanged — please try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="sw-shell">
      <style jsx global>{`
        :root { color-scheme: dark; }
        html { background: linear-gradient(#0b0718, #1b0f3d) fixed; }
        html body { background: transparent; color: #f4f0ff; font-family: "Segoe UI", system-ui, -apple-system, Roboto, sans-serif; }
        .sw-shell {
          min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center;
          gap: 20px; padding: 32px 16px;
          background: radial-gradient(ellipse 60% 50% at 10% 0%, #9146ff38, transparent 70%),
            radial-gradient(ellipse 50% 45% at 100% 80%, #ff4fd830, transparent 70%);
        }
        .sw-brand { display: flex; align-items: center; gap: 12px; font-size: 26px; font-weight: 900; }
        .sw-brand span { background: linear-gradient(90deg, #b98cff, #ff4fd8); -webkit-background-clip: text; background-clip: text; color: transparent; }
        .sw-logo { width: 46px; height: 46px; border-radius: 14px; display: grid; place-items: center; background: linear-gradient(135deg, #9146ff, #ff4fd8); box-shadow: 0 0 26px #9146ff90; }
        .sw-card { width: 100%; max-width: 460px; padding: 26px; border: 1px solid #342a60; border-radius: 28px; background: #140e2be0; box-shadow: 0 0 40px -6px #9146ff55, 0 24px 60px #0007; }
        .sw-card h1 { margin: 0 0 4px; font-size: 24px; font-weight: 900; }
        .sw-muted { color: #a99dcf; font-size: 13px; line-height: 1.6; margin: 0; }
        .sw-box { margin-top: 14px; padding: 16px; border: 1px solid #342a60; border-radius: 18px; background: #1e1641; }
        .sw-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
        .sw-label { font-size: 11px; font-weight: 800; letter-spacing: 1.4px; text-transform: uppercase; color: #a99dcf; }
        .sw-max { border: 0; background: #9146ff33; color: #d8c6ff; font: inherit; font-size: 11px; font-weight: 800; padding: 4px 10px; border-radius: 20px; cursor: pointer; }
        .sw-input { width: 100%; margin-top: 8px; border: 0; outline: none; background: transparent; color: #fff; font: inherit; font-size: 32px; font-weight: 900; }
        .sw-asset { padding: 6px 12px; border-radius: 20px; background: #0b0718; font-weight: 800; font-size: 14px; white-space: nowrap; }
        .sw-out { margin-top: 8px; font-size: 32px; font-weight: 900; color: #fff; min-height: 40px; }
        .sw-flip { display: grid; place-items: center; margin: -8px auto; position: relative; z-index: 1; width: 42px; height: 42px; border-radius: 50%; border: 3px solid #140e2b; background: linear-gradient(135deg, #9146ff, #ff4fd8); color: #fff; font-size: 18px; cursor: pointer; transition: transform .25s; }
        .sw-flip:hover { transform: rotate(180deg); }
        .sw-details { margin-top: 14px; font-size: 12px; color: #a99dcf; display: grid; gap: 6px; }
        .sw-button { width: 100%; margin-top: 18px; padding: 15px; border: 0; border-radius: 14px; background: linear-gradient(90deg, #9146ff, #ff4fd8); color: #fff; font: inherit; font-weight: 800; cursor: pointer; box-shadow: 0 4px 18px #9146ff70; }
        .sw-button:disabled { opacity: .5; cursor: not-allowed; box-shadow: none; }
        .sw-error { margin-top: 14px; padding: 11px 13px; border-radius: 12px; font-size: 13px; border: 1px solid #ff3b6b80; background: #ff3b6b18; color: #ffc0cf; }
        .sw-success { margin-top: 14px; padding: 11px 13px; border-radius: 12px; font-size: 13px; border: 1px solid #3df2ff80; background: #3df2ff14; color: #b8fbff; }
        .sw-success a { color: #b98cff; }
        .sw-warn { color: #ffd54f; }
      `}</style>

      <div className="sw-brand">
        <div className="sw-logo" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="30" height="30">
            <rect x="6.2" y="1" width="11.6" height="3.4" rx="1.2" fill="#fff" />
            <path d="M8.2 5.3h7.6v1.4c3.7 1.2 5.3 2.9 5.3 5.8v7.2c0 1.9-1.5 3.3-3.3 3.3H6.2c-1.8 0-3.3-1.4-3.3-3.3v-7.2c0-2.9 1.6-4.6 5.3-5.8z" fill="#fff" />
            <circle cx="12" cy="15.4" r="3.8" fill="#FFD54F" />
          </svg>
        </div>
        <span>JarJar Swap</span>
      </div>

      <section className="sw-card" aria-live="polite">
        <h1>Swap XLM ⇄ USDC</h1>
        <p className="sw-muted">Exchange between XLM and USDC in your Freighter wallet on Stellar Testnet.</p>

        {!address ? (
          <button className="sw-button" onClick={() => void connect()}>Connect Freighter</button>
        ) : (
          <>
            <div className="sw-box">
              <div className="sw-row">
                <span className="sw-label">You pay</span>
                <button
                  className="sw-max"
                  type="button"
                  disabled={!balances || available <= 0}
                  onClick={() => setAmount((Math.floor(available * 1e7) / 1e7).toString())}
                >
                  Max {balances ? fmt(available) : "…"}
                </button>
              </div>
              <div className="sw-row">
                <input
                  className="sw-input"
                  inputMode="decimal"
                  placeholder="0.00"
                  value={amount}
                  aria-label={`Amount of ${sendCode} to swap`}
                  onChange={(e) => setAmount(e.target.value.replace(",", ".").trim())}
                />
                <span className="sw-asset">{sendCode}</span>
              </div>
            </div>

            <button
              className="sw-flip"
              type="button"
              aria-label="Switch direction"
              onClick={() => {
                setDirection((d) => (d === "XLM_TO_USDC" ? "USDC_TO_XLM" : "XLM_TO_USDC"));
                setAmount("");
              }}
            >
              ⇅
            </button>

            <div className="sw-box">
              <span className="sw-label">You receive (estimated)</span>
              <div className="sw-row">
                <div className="sw-out">{quoting ? "…" : quote ? fmt(Number(quote.destAmount), 4) : "0.00"}</div>
                <span className="sw-asset">{receiveCode}</span>
              </div>
            </div>

            <div className="sw-details">
              <div className="sw-row"><span>Balance</span><span>{balances ? `${fmt(balances.xlm)} XLM · ${balances.usdc === null ? "no USDC yet" : `${fmt(balances.usdc)} USDC`}` : "…"}</span></div>
              {quote && validAmount && (
                <div className="sw-row"><span>Rate</span><span>1 {sendCode} ≈ {fmt(Number(quote.destAmount) / value, 6)} {receiveCode}</span></div>
              )}
              {quote && <div className="sw-row"><span>Minimum received (1% slippage)</span><span>{fmt(Number(minReceived), 4)} {receiveCode}</span></div>}
              {balances?.usdc === null && direction === "XLM_TO_USDC" && (
                <div className="sw-warn">USDC will be added to your Freighter assets as part of this swap.</div>
              )}
              {tooMuch && <div className="sw-warn">That&apos;s more {sendCode} than you can spend.</div>}
              {noRoute && <div className="sw-warn">No exchange route is available for this amount right now.</div>}
            </div>

            <button
              className="sw-button"
              disabled={busy || !quote || !validAmount || tooMuch || quoting}
              onClick={() => void swap()}
            >
              {busy ? "Waiting for Freighter…" : `Swap ${sendCode} for ${receiveCode}`}
            </button>
          </>
        )}

        {error && <div className="sw-error" role="alert">{error}</div>}
        {txHash && (
          <div className="sw-success">
            Swap complete! Your JarJar wallet balance will update in a few seconds.{" "}
            <a href={`https://stellar.expert/explorer/testnet/tx/${txHash}`} target="_blank" rel="noreferrer">View transaction ↗</a>
          </div>
        )}
      </section>
    </main>
  );
}

export default function SwapPage() {
  return (
    <Suspense fallback={null}>
      <SwapForm />
    </Suspense>
  );
}
