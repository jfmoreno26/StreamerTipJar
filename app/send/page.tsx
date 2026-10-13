"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  requestAccess,
  getAddress,
  getNetworkDetails,
  signTransaction,
} from "@stellar/freighter-api";
import { ASSET, THRESHOLD_USDC, splitFor } from "@/lib/tipjar";

const TESTNET = "Test SDF Network ; September 2015";
const USD_TO_USDC_TEST_RATE = 1;

type ApiResult = {
  status: string;
  txHash?: string;
  error?: string;
};

async function post(body: object): Promise<any> {
  const res = await fetch("/api/send", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

  const result = await res.json();

  if (!res.ok || result.error) {
    throw new Error(result.error || `HTTP ${res.status}`);
  }

  return result;
}

function SendTipForm() {
  const searchParams = useSearchParams();

  const creatorParam = searchParams.get("creator");
  const [creator, setCreator] = useState(
    creatorParam?.trim().slice(0, 100) || "Unknown Creator"
  );

  const [amount, setAmount] = useState("");
  const [msg, setMsg] = useState("");
  const [txHash, setTxHash] = useState("");
  const [pending, setPending] = useState(false);
  const [busy, setBusy] = useState(false);
  const [paymentStatus, setPaymentStatus] = useState<
    "idle" | "success" | "failed" | "pending"
  >("idle");

  const working = useRef(false);
  const envelope = useRef<{
    signedXdr: string;
    preparationRequestId: string | null;
  } | null>(null);

  useEffect(() => {
    const creatorFromUrl = searchParams.get("creator");
    const amountParam = searchParams.get("amount");

    if (creatorFromUrl?.trim()) {
      setCreator(creatorFromUrl.trim().slice(0, 100));
    } else {
      setCreator("Unknown Creator");
    }

    if (amountParam) {
      const parsed = Number(amountParam);

      if (
        Number.isFinite(parsed) &&
        parsed > 0 &&
        parsed <= 1000000 &&
        /^\d+(\.\d{1,2})?$/.test(amountParam)
      ) {
        setAmount(amountParam);
      }
    }
  }, [searchParams]);

  const usd = Number(amount);
  const usdc = usd * USD_TO_USDC_TEST_RATE;

  const valid =
    /^\d+(\.\d{1,2})?$/.test(amount.trim()) &&
    Number.isFinite(usd) &&
    usd > 0 &&
    usd <= 1000000;

  const bigTip = valid && usdc > THRESHOLD_USDC;

  async function run(fn: () => Promise<void>) {
    if (working.current) return;

    working.current = true;
    setBusy(true);
    setMsg("");

    try {
      await fn();
    } catch (error) {
      setMsg(
        error instanceof Error
          ? error.message
          : "An unexpected payment error occurred."
      );
    } finally {
      working.current = false;
      setBusy(false);
    }
  }

  async function send() {
    if (envelope.current || pending) {
      throw new Error("A signed tip is waiting. Use Check payment status.");
    }

    setTxHash("");
    setPaymentStatus("idle");

    const access: any = await requestAccess();

    if (access.error || !access.address) {
      throw new Error("Allow wallet access in Freighter.");
    }

    const network: any = await getNetworkDetails();

    if (network.error || network.networkPassphrase !== TESTNET) {
      throw new Error("Switch Freighter to Stellar Testnet.");
    }

    const prepared = await post({
      action: "prepare",
      from: access.address,
      amountUsdc: usdc.toFixed(2),
    });

    if (
      prepared.network !== "testnet" ||
      prepared.networkPassphrase !== TESTNET ||
      !prepared.expiresAt ||
      !(Date.parse(prepared.expiresAt) > Date.now()) ||
      typeof prepared.xdr !== "string" ||
      !prepared.xdr
    ) {
      throw new Error(
        "The prepared transaction has an invalid network, expiry, or XDR."
      );
    }

    const current: any = await getAddress();

    if (current.error || current.address !== access.address) {
      throw new Error("The connected wallet changed. Start again.");
    }

    const signed: any = await signTransaction(prepared.xdr, {
      networkPassphrase: TESTNET,
      address: access.address,
    });

    if (
      signed.error ||
      !signed.signedTxXdr ||
      signed.signerAddress !== access.address
    ) {
      throw new Error("Freighter did not sign the transaction.");
    }

    envelope.current = {
      signedXdr: signed.signedTxXdr,
      preparationRequestId: prepared.preparationRequestId ?? null,
    };

    await checkAgain();
  }

  async function checkAgain() {
    let result: ApiResult;

    if (txHash) {
      result = await post({
        action: "verify",
        txHash,
      });
    } else if (envelope.current) {
      result = await post({
        action: "submit",
        ...envelope.current,
      });
    } else {
      throw new Error("There is no transaction to check.");
    }

    if (result.txHash) setTxHash(result.txHash);

    if (result.status === "SUCCESS") {
      envelope.current = null;
      setPending(false);
      setPaymentStatus("success");
      setMsg("Payment verified successfully.");
    } else if (result.status === "FAILED") {
      envelope.current = null;
      setPending(false);
      setPaymentStatus("failed");
      setMsg("The transaction failed. Check its details before retrying.");
    } else {
      setPending(true);
      setPaymentStatus("pending");
      setMsg(
        "The transaction is still pending. Check again shortly; do not start another tip yet."
      );
    }
  }

  function reset() {
    envelope.current = null;
    setTxHash("");
    setPending(false);
    setMsg("");
    setPaymentStatus("idle");
  }

  const splits = valid ? splitFor(usdc) : [];
  const amountLabel = valid ? usd.toFixed(2) : "0.00";

  return (
    <main className="payment-shell">
      <style jsx global>{`
        @import url('https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700;800;900&family=Inter:wght@400;500;600;700;800&display=swap');

        :root {
          color-scheme: dark;
          --pf-bg: #080d18;
          --pf-panel: #101929;
          --pf-panel-raised: #141f32;
          --pf-border: #26354b;
          --pf-blue: #3978ff;
          --pf-yellow: #ffd54f;
          --pf-text: #f3f6ff;
          --pf-muted: #94a3b8;
        }

        * { box-sizing: border-box; }

        html, body {
          margin: 0;
          min-height: 100%;
          background: var(--pf-bg);
          color: var(--pf-text);
          font-family: 'Inter', system-ui, sans-serif;
        }

        body {
          background-image:
            radial-gradient(ellipse at 12% 0%, #17336b55, transparent 36%),
            radial-gradient(ellipse at 100% 60%, #10234b33, transparent 35%);
        }

        button, input { font: inherit; }

        button:focus-visible, input:focus-visible, a:focus-visible {
          outline: 2px solid var(--pf-yellow);
          outline-offset: 3px;
        }

        .payment-shell { min-height: 100vh; padding: 0 28px 36px; }

        .pf-topbar {
          max-width: 1160px; margin: 0 auto; min-height: 82px;
          display: flex; align-items: center; justify-content: space-between;
          gap: 20px; border-bottom: 1px solid #263247;
        }

        .pf-brand { display: flex; align-items: center; gap: 12px; min-width: 0; }

        .pf-logo {
          width: 43px; height: 43px; border-radius: 12px;
          display: grid; place-items: center; background: var(--pf-yellow);
          color: #111827; font-family: 'Barlow Condensed', sans-serif;
          font-size: 25px; font-weight: 900; box-shadow: 0 0 26px #ffd54f1a;
        }

        .pf-brand-name { font-weight: 800; letter-spacing: 1.3px; font-size: 14px; }
        .pf-brand-sub { margin-top: 4px; color: var(--pf-muted); font-size: 10px; letter-spacing: 2px; }

        .pf-testnet {
          display: flex; align-items: center; gap: 9px; padding: 9px 13px;
          border: 1px solid #34445b; border-radius: 8px; color: #c5d2e5;
          font-size: 11px; font-weight: 700; letter-spacing: 1px; white-space: nowrap;
        }

        .pf-live-dot {
          width: 7px; height: 7px; border-radius: 50%;
          background: var(--pf-yellow); box-shadow: 0 0 10px #ffd54f99;
        }

        .pf-main { max-width: 1080px; margin: 48px auto 0; }

        .pf-eyebrow {
          display: flex; align-items: center; gap: 10px; color: var(--pf-yellow);
          font-size: 11px; font-weight: 800; letter-spacing: 2.5px; text-transform: uppercase;
        }

        .pf-eyebrow-line { width: 26px; height: 2px; background: var(--pf-yellow); }

        .pf-page-title {
          margin: 12px 0 10px; font-family: 'Barlow Condensed', Impact, sans-serif;
          font-size: clamp(40px, 6vw, 62px); line-height: 0.98;
          letter-spacing: 0.3px; text-transform: uppercase;
        }

        .pf-page-title span { color: var(--pf-blue); }

        .pf-page-subtitle {
          margin: 0; max-width: 620px; color: var(--pf-muted);
          font-size: 14px; line-height: 1.7;
        }

        .pf-layout {
          display: grid; grid-template-columns: minmax(0, 1fr) minmax(330px, 410px);
          gap: 24px; align-items: start; margin-top: 32px;
        }

        .pf-panel {
          min-width: 0; border: 1px solid var(--pf-border); border-radius: 15px;
          background: linear-gradient(150deg, #111c2e, #0d1523);
          box-shadow: 0 20px 55px #00000024; overflow: hidden;
        }

        .pf-panel-heading {
          display: flex; align-items: center; gap: 12px; padding: 21px 23px;
          border-bottom: 1px solid var(--pf-border);
        }

        .pf-step {
          width: 32px; height: 32px; flex: 0 0 32px; display: grid;
          place-items: center; border-radius: 8px; background: #1d3768;
          color: #91b4ff; font-size: 13px; font-weight: 800;
        }

        .pf-panel-title { font-size: 14px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; }
        .pf-panel-subtitle { margin-top: 4px; color: var(--pf-muted); font-size: 11px; }
        .pf-panel-body { padding: 24px; }

        .pf-creator {
          display: flex; align-items: center; gap: 14px; padding: 17px;
          border: 1px solid #2b3c54; border-radius: 12px; background: #0b1321;
        }

        .pf-avatar {
          width: 48px; height: 48px; flex: 0 0 48px; display: grid;
          place-items: center; border-radius: 12px;
          background: linear-gradient(135deg, #316dff, #193b88);
          color: white; font-family: 'Barlow Condensed', sans-serif;
          font-size: 24px; font-weight: 800;
        }

        .pf-small-label { color: var(--pf-muted); font-size: 10px; font-weight: 700; letter-spacing: 1.7px; text-transform: uppercase; }
        .pf-creator-name { margin-top: 5px; overflow-wrap: anywhere; font-size: 17px; font-weight: 800; }
        .pf-creator-caption { margin-top: 5px; color: var(--pf-muted); font-size: 11px; }
        .pf-field-label { display: block; margin-bottom: 10px; color: #dce5f5; font-size: 12px; font-weight: 700; }

        .pf-amount-wrap { position: relative; }

        .pf-currency {
          position: absolute; top: 50%; left: 17px; transform: translateY(-50%);
          color: #8fa1bb; font-size: 20px; font-weight: 700;
        }

        .pf-amount-input {
          width: 100%; min-height: 69px; padding: 16px 15px 16px 43px;
          border: 1px solid #344660; border-radius: 10px; background: #0a1220;
          color: white; font-family: 'Barlow Condensed', sans-serif;
          font-size: 31px; font-weight: 700; outline: none;
          transition: border-color 150ms, box-shadow 150ms;
        }

        .pf-amount-input:focus { border-color: var(--pf-blue); box-shadow: 0 0 0 3px #3978ff22; }
        .pf-amount-input:disabled { opacity: 0.55; cursor: not-allowed; }

        .pf-presets { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 9px; margin-top: 12px; }

        .pf-preset {
          min-height: 42px; border: 1px solid #34445a; border-radius: 8px;
          background: #141f30; color: #d7e2f4; font-size: 12px;
          font-weight: 700; cursor: pointer; transition: border-color 150ms, background 150ms;
        }

        .pf-preset:hover:not(:disabled) { border-color: var(--pf-blue); }
        .pf-preset.active { border-color: var(--pf-yellow); background: #ffd54f12; color: var(--pf-yellow); }
        .pf-preset:disabled { cursor: not-allowed; opacity: 0.55; }

        .pf-rate-note { margin-top: 13px; color: #8495ad; font-size: 11px; line-height: 1.7; }
        .pf-divider { height: 1px; margin: 24px 0; background: var(--pf-border); }
        .pf-summary-title { margin-bottom: 16px; font-size: 12px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; }
        .pf-split-list { display: grid; gap: 15px; }

        .pf-split-row {
          display: grid; grid-template-columns: 9px minmax(0, 1fr) auto;
          align-items: center; gap: 10px; color: #c6d2e4; font-size: 12px;
        }

        .pf-split-dot { width: 8px; height: 8px; border-radius: 3px; background: var(--pf-blue); }
        .pf-split-row:nth-child(2) .pf-split-dot { background: var(--pf-yellow); }
        .pf-split-row:nth-child(3) .pf-split-dot { background: #55c9a6; }
        .pf-split-value { color: #f3f6ff; font-weight: 700; white-space: nowrap; }

        .pf-total {
          display: flex; align-items: end; justify-content: space-between; gap: 12px;
          margin-top: 21px; padding: 17px; border: 1px solid #2b3e5b;
          border-radius: 10px; background: #14233a;
        }

        .pf-total-label { color: #a6b7d0; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
        .pf-total-value { margin-top: 6px; color: white; font-family: 'Barlow Condensed', sans-serif; font-size: 34px; font-weight: 800; }
        .pf-total-unit { color: var(--pf-yellow); font-size: 12px; font-weight: 800; }
        .pf-right-body { padding: 23px; }

        .pf-payment-amount {
          padding: 23px 18px; border: 1px solid #2b4166; border-radius: 12px;
          background: radial-gradient(ellipse at 100% 0%, #2752a044, transparent 55%), #0b1423;
          text-align: center;
        }

        .pf-big-amount { margin-top: 12px; font-family: 'Barlow Condensed', sans-serif; font-size: clamp(42px, 5vw, 54px); font-weight: 800; letter-spacing: -0.5px; overflow-wrap: anywhere; }
        .pf-big-amount small { margin-left: 7px; color: var(--pf-yellow); font-family: 'Inter', sans-serif; font-size: 13px; font-weight: 800; letter-spacing: 1px; }
        .pf-amount-caption { margin-top: 5px; color: var(--pf-muted); font-size: 11px; }

        .pf-network-row {
          display: flex; align-items: center; justify-content: space-between;
          gap: 12px; margin-top: 18px; padding: 13px 0;
          border-bottom: 1px solid var(--pf-border);
        }

        .pf-network-name { display: flex; align-items: center; gap: 10px; font-size: 12px; font-weight: 700; }
        .pf-network-icon { display: grid; width: 31px; height: 31px; place-items: center; border-radius: 9px; background: #172d53; color: #8eb2ff; font-weight: 900; }
        .pf-network-value { color: #c1cfe3; font-size: 11px; text-align: right; }
        .pf-network-value strong { display: block; margin-bottom: 4px; color: #f0f5ff; font-size: 12px; }

        .pf-primary-button {
          width: 100%; min-height: 52px; display: flex; align-items: center;
          justify-content: center; gap: 10px; margin-top: 22px; padding: 14px 16px;
          border: 0; border-radius: 9px; background: var(--pf-yellow); color: #101827;
          font-size: 12px; font-weight: 900; letter-spacing: 0.8px;
          text-transform: uppercase; cursor: pointer; transition: transform 150ms, filter 150ms;
        }

        .pf-primary-button:hover:not(:disabled) { filter: brightness(1.05); transform: translateY(-1px); }
        .pf-primary-button:disabled { cursor: not-allowed; opacity: 0.45; transform: none; }
        .pf-arrow { font-size: 18px; }

        .pf-secondary-button {
          width: 100%; min-height: 44px; margin-top: 12px; padding: 11px 14px;
          border: 1px solid #3b4e69; border-radius: 9px; background: #172338;
          color: #e6edfa; font-size: 12px; font-weight: 700; cursor: pointer;
        }

        .pf-secondary-button:disabled { cursor: not-allowed; opacity: 0.5; }

        .pf-security { display: flex; align-items: flex-start; gap: 10px; margin-top: 19px; color: #8496af; font-size: 10px; line-height: 1.7; }
        .pf-security-icon { flex: 0 0 auto; color: #6e91d9; font-size: 15px; }

        .pf-status {
          margin-top: 18px; padding: 14px; border: 1px solid #35445b;
          border-radius: 10px; background: #111c2c; color: #dbe6f8;
          font-size: 12px; line-height: 1.7; overflow-wrap: anywhere;
        }

        .pf-status.success { border-color: #247b61; background: #102a26; color: #a5f0d5; }
        .pf-status.failed { border-color: #9b4a4a; background: #301b24; color: #ffc0c0; }
        .pf-status.pending { border-color: #826a2c; background: #292517; color: #ffe7a0; }
        .pf-status-label { display: block; margin-bottom: 5px; font-size: 10px; font-weight: 900; letter-spacing: 1.4px; text-transform: uppercase; }

        .pf-hash { margin-top: 19px; padding: 14px; border: 1px solid var(--pf-border); border-radius: 10px; background: #0b1321; }
        .pf-hash a { display: block; margin-top: 9px; color: #8eb2ff; font-size: 11px; line-height: 1.7; overflow-wrap: anywhere; text-decoration: none; }
        .pf-hash a:hover { text-decoration: underline; }

        .pf-footer {
          max-width: 1080px; display: flex; justify-content: space-between; gap: 18px;
          margin: 30px auto 0; padding-top: 19px; border-top: 1px solid #263247;
          color: #64758e; font-size: 10px; line-height: 1.7;
        }

        .pf-footer strong { color: #a8b7ce; }
        .pf-footer-right { text-align: right; }

        @media (max-width: 800px) {
          .payment-shell { padding: 0 18px 26px; }
          .pf-main { margin-top: 34px; }
          .pf-layout { grid-template-columns: minmax(0, 1fr); gap: 18px; margin-top: 25px; }
          .pf-right-column { order: -1; }
          .pf-page-title { font-size: 48px; }
          .pf-footer { flex-direction: column; }
          .pf-footer-right { text-align: left; }
        }

        @media (max-width: 430px) {
          .payment-shell { padding-right: 12px; padding-left: 12px; }
          .pf-topbar { min-height: 70px; }
          .pf-brand-name { font-size: 12px; }
          .pf-brand-sub { font-size: 9px; letter-spacing: 1px; }
          .pf-logo { width: 38px; height: 38px; }
          .pf-testnet { gap: 6px; padding: 8px; font-size: 9px; letter-spacing: 0.5px; }
          .pf-panel-heading { padding: 17px; }
          .pf-panel-body, .pf-right-body { padding: 17px; }
          .pf-page-title { font-size: 41px; }
          .pf-presets { gap: 6px; }
          .pf-preset { font-size: 11px; }
        }

        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            scroll-behavior: auto !important;
            transition: none !important;
          }
        }
      `}</style>

      <header className="pf-topbar">
        <div className="pf-brand">
          <div className="pf-logo">P</div>
          <div>
            <div className="pf-brand-name">PAIFLOW</div>
            <div className="pf-brand-sub">CREATOR PAYMENTS</div>
          </div>
        </div>
        <div className="pf-testnet">
          <span className="pf-live-dot" />
          TESTNET MODE
        </div>
      </header>

      <div className="pf-main">
        <div className="pf-eyebrow">
          <span className="pf-eyebrow-line" />
          SUPPORT THE COMMUNITY
        </div>

        <h1 className="pf-page-title">
          BACK <span>{creator.toUpperCase()}.</span>
        </h1>

        <p className="pf-page-subtitle">
          Every tip helps {creator} keep building. Review your contribution
          and confirm the transaction securely through your wallet.
        </p>

        <div className="pf-layout">
          <section className="pf-panel">
            <div className="pf-panel-heading">
              <div className="pf-step">01</div>
              <div>
                <div className="pf-panel-title">Contribution details</div>
                <div className="pf-panel-subtitle">Choose the amount you want to send</div>
              </div>
            </div>

            <div className="pf-panel-body">
              <div className="pf-creator">
                <div className="pf-avatar">
                  {creator.trim().slice(0, 1).toUpperCase() || "C"}
                </div>
                <div style={{ minWidth: 0 }}>
                  <div className="pf-small-label">You are supporting</div>
                  <div className="pf-creator-name">{creator}</div>
                  <div className="pf-creator-caption">Creator community contribution</div>
                </div>
              </div>

              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  void run(send);
                }}
              >
                <div style={{ marginTop: 25 }}>
                  <label className="pf-field-label" htmlFor="tip-amount">
                    CONTRIBUTION AMOUNT · USD
                  </label>
                  <div className="pf-amount-wrap">
                    <span className="pf-currency">$</span>
                    <input
                      id="tip-amount"
                      className="pf-amount-input"
                      value={amount}
                      onChange={(event) => setAmount(event.target.value)}
                      inputMode="decimal"
                      placeholder="5.00"
                      autoComplete="off"
                      required
                      disabled={busy || pending}
                      aria-describedby="rate-note"
                    />
                  </div>

                  <div className="pf-presets">
                    {[1, 5, 10, 25].map((value) => (
                      <button
                        key={value}
                        type="button"
                        disabled={busy || pending}
                        className={`pf-preset ${amount === value.toFixed(2) ? "active" : ""}`}
                        onClick={() => setAmount(value.toFixed(2))}
                      >
                        ${value}
                      </button>
                    ))}
                  </div>

                  <div className="pf-rate-note" id="rate-note">
                    Demo conversion: 1 USD = 1 USDC. This is a test integration assumption, not a live exchange rate.
                  </div>
                </div>

                <div className="pf-divider" />
                <div className="pf-summary-title">Contribution allocation</div>

                {valid ? (
                  <>
                    <div className="pf-split-list">
                      {splits.map((split) => (
                        <div className="pf-split-row" key={split.name}>
                          <span className="pf-split-dot" />
                          <span>{split.name} · {split.pct}%</span>
                          <span className="pf-split-value">
                            ${(usd * split.pct / 100).toFixed(2)}
                          </span>
                        </div>
                      ))}
                    </div>

                    <div className="pf-total">
                      <div>
                        <div className="pf-total-label">Total contribution</div>
                        <div className="pf-total-value">${amountLabel}</div>
                      </div>
                      <div className="pf-total-unit">{ASSET}</div>
                    </div>

                    <div className="pf-rate-note">
                      {bigTip
                        ? "This amount qualifies for the three-way allocation."
                        : `Tips over ${THRESHOLD_USDC} USDC also support the Charity Fund.`}
                    </div>
                  </>
                ) : (
                  <div className="pf-rate-note">
                    Enter a valid amount greater than zero and up to $1,000,000 to preview your contribution allocation.
                  </div>
                )}
              </form>
            </div>
          </section>

          <aside className="pf-panel pf-right-column">
            <div className="pf-panel-heading">
              <div className="pf-step">02</div>
              <div>
                <div className="pf-panel-title">Payment terminal</div>
                <div className="pf-panel-subtitle">Review before wallet approval</div>
              </div>
            </div>

            <div className="pf-right-body">
              <div className="pf-payment-amount">
                <div className="pf-small-label">Supporting {creator}</div>
                <div className="pf-big-amount">
                  ${amountLabel}<small>{ASSET}</small>
                </div>
                <div className="pf-amount-caption">Stellar network · Test environment</div>
              </div>

              <div className="pf-network-row">
                <div className="pf-network-name">
                  <span className="pf-network-icon">S</span>
                  Network
                </div>
                <div className="pf-network-value">
                  <strong>Stellar Testnet</strong>
                  Development only
                </div>
              </div>

              <div className="pf-network-row">
                <div className="pf-network-name">
                  <span className="pf-network-icon">W</span>
                  Wallet
                </div>
                <div className="pf-network-value">
                  <strong>Freighter</strong>
                  Approval required
                </div>
              </div>

              <button
                type="button"
                className="pf-primary-button"
                disabled={busy || !valid || pending || paymentStatus === "success"}
                onClick={() => void run(send)}
              >
                {busy
                  ? "PROCESSING..."
                  : paymentStatus === "success"
                    ? "PAYMENT VERIFIED"
                    : pending
                      ? "PAYMENT PENDING"
                      : <>Continue with Freighter <span className="pf-arrow">↗</span></>}
              </button>

              {busy && (
                <div className="pf-status pending" role="status" aria-live="polite">
                  <span className="pf-status-label">Processing</span>
                  Waiting for wallet approval or network confirmation. Follow the prompts in Freighter and keep this page open.
                </div>
              )}

              {msg && (
                <div
                  className={`pf-status ${paymentStatus === "success" ? "success" : paymentStatus === "failed" ? "failed" : paymentStatus === "pending" ? "pending" : ""}`}
                  role="status"
                  aria-live="polite"
                >
                  <span className="pf-status-label">
                    {paymentStatus === "success"
                      ? "✓ Payment confirmed"
                      : paymentStatus === "failed"
                        ? "Transaction failed"
                        : paymentStatus === "pending"
                          ? "Confirmation pending"
                          : "Payment notice"}
                  </span>
                  {msg}
                </div>
              )}

              {pending && (
                <button
                  type="button"
                  className="pf-secondary-button"
                  disabled={busy}
                  onClick={() => void run(checkAgain)}
                >
                  Check payment status
                </button>
              )}

              {txHash && (
                <div className="pf-hash">
                  <div className="pf-small-label">Transaction reference</div>
                  <a
                    href={`https://stellar.expert/explorer/testnet/tx/${encodeURIComponent(txHash)}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    View transaction on Stellar Expert ↗
                    <br />
                    {txHash}
                  </a>

                  {!pending && (
                    <button
                      type="button"
                      className="pf-secondary-button"
                      onClick={reset}
                    >
                      Start another tip
                    </button>
                  )}
                </div>
              )}

              <div className="pf-security">
                <span className="pf-security-icon">◆</span>
                <span>
                  <strong>Wallet-controlled approval.</strong> Review the transaction details in Freighter before signing. Never share your recovery phrase or private key.
                </span>
              </div>
            </div>
          </aside>
        </div>
      </div>

      <footer className="pf-footer">
        <div>
          <strong>PAIFLOW</strong> · Creator support infrastructure
          <br />
          Educational testnet integration
        </div>
        <div className="pf-footer-right">
          NO REAL-MONEY PAYMENT IN THIS DEMO
          <br />
          Stellar Testnet · Verify before approving
        </div>
      </footer>
    </main>
  );
}

export default function SendTip() {
  return (
    <Suspense
      fallback={
        <main
          style={{
            minHeight: "100vh",
            display: "grid",
            placeItems: "center",
            background: "#080d18",
            color: "#f3f6ff",
            fontFamily: "system-ui, sans-serif",
          }}
        >
          Loading PaiFlow payment terminal...
        </main>
      }
    >
      <SendTipForm />
    </Suspense>
  );
}