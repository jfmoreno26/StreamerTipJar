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
    creatorParam?.trim().slice(0, 100) || "your favorite creator"
  );

  const userIdParam = searchParams.get("userId");
  const userId = userIdParam && /^[A-Za-z0-9]{1,128}$/.test(userIdParam) ? userIdParam : null;

  const handleParam = searchParams.get("handle");
  const handle = handleParam && /^@?[A-Za-z0-9_.]{1,40}$/.test(handleParam) ? handleParam : null;
  const [avatarFailed, setAvatarFailed] = useState(false);

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
  const tip = useRef<{
    id: string;
    userId: string;
    creator: string;
    amountUsd: string;
  } | null>(null);

  useEffect(() => {
    const creatorFromUrl = searchParams.get("creator");
    const amountParam = searchParams.get("amount");

    if (creatorFromUrl?.trim()) {
      setCreator(creatorFromUrl.trim().slice(0, 100));
    } else {
      setCreator("your favorite creator");
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
    tip.current = userId
      ? { id: crypto.randomUUID(), userId, creator, amountUsd: usd.toFixed(2) }
      : null;

    await checkAgain();
  }

  async function checkAgain() {
    let result: ApiResult;

    if (txHash) {
      result = await post({
        action: "verify",
        txHash,
        tip: tip.current,
      });
    } else if (envelope.current) {
      result = await post({
        action: "submit",
        ...envelope.current,
        tip: tip.current,
      });
    } else {
      throw new Error("There is no transaction to check.");
    }

    if (result.txHash) setTxHash(result.txHash);

    if (result.status === "SUCCESS") {
      envelope.current = null;
      setPending(false);
      setPaymentStatus("success");
      setMsg(
        tip.current
          ? "Payment verified successfully. Your tip is now recorded in JarJar."
          : "Payment verified successfully."
      );
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
    tip.current = null;
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
        :root {
          color-scheme: dark;
          --pf-bg: #0b0718;
          --pf-bg-alt: #1b0f3d;
          --pf-panel: #140e2bdd;
          --pf-panel-raised: #1e1641;
          --pf-border: #342a60;
          --pf-purple: #9146ff;
          --pf-violet: #b98cff;
          --pf-pink: #ff4fd8;
          --pf-cyan: #3df2ff;
          --pf-gold: #ffd54f;
          --pf-live: #ff3b6b;
          --pf-text: #f4f0ff;
          --pf-muted: #a99dcf;
          --pf-gradient: linear-gradient(90deg, var(--pf-purple), var(--pf-pink));
        }

        * { box-sizing: border-box; }

        html {
          background: linear-gradient(var(--pf-bg), var(--pf-bg-alt)) fixed;
        }

        html body {
          margin: 0;
          min-height: 100%;
          background: transparent;
          color: var(--pf-text);
          font-family: "Segoe UI", system-ui, -apple-system, Roboto, sans-serif;
        }

        button, input { font: inherit; }

        button:focus-visible, input:focus-visible, a:focus-visible {
          outline: 2px solid var(--pf-gold);
          outline-offset: 3px;
        }

        .pf-space {
          position: fixed; inset: 0; z-index: -1; overflow: hidden; pointer-events: none;
          background:
            radial-gradient(ellipse 60% 50% at 10% 0%, #9146ff38, transparent 70%),
            radial-gradient(ellipse 50% 45% at 100% 80%, #ff4fd830, transparent 70%);
        }
        .pf-space::before, .pf-space::after {
          content: ""; position: absolute; inset: 0;
          background-image:
            radial-gradient(1.5px 1.5px at 12% 18%, #fff9, transparent),
            radial-gradient(1px 1px at 28% 72%, #fff8, transparent),
            radial-gradient(1.5px 1.5px at 45% 30%, #fffa, transparent),
            radial-gradient(1px 1px at 63% 12%, #fff7, transparent),
            radial-gradient(2px 2px at 78% 56%, #fff9, transparent),
            radial-gradient(1px 1px at 88% 24%, #fff8, transparent),
            radial-gradient(1.5px 1.5px at 35% 90%, #fff7, transparent),
            radial-gradient(1px 1px at 6% 60%, #fff8, transparent);
          background-size: 420px 420px;
        }
        .pf-space::after {
          background-size: 300px 300px; background-position: 120px 80px;
          animation: pf-twinkle 4s ease-in-out infinite alternate;
        }
        .pf-planet {
          position: absolute; right: -110px; bottom: -90px; width: min(460px, 70vw);
          filter: drop-shadow(0 0 40px #ff4fd860);
          animation: pf-float 9s ease-in-out infinite alternate;
        }
        @keyframes pf-twinkle { from { opacity: .25; } to { opacity: .9; } }
        @keyframes pf-float { to { transform: translateY(-14px) rotate(2deg); } }
        @keyframes pf-rise { from { opacity: 0; transform: translateY(14px); } }

        .payment-shell { min-height: 100vh; padding: 0 28px 36px; }

        .pf-topbar {
          max-width: 1160px; margin: 0 auto; min-height: 78px;
          display: flex; align-items: center; justify-content: space-between;
          gap: 20px; border-bottom: 1px solid #342a6099;
        }

        .pf-brand { display: flex; align-items: center; gap: 12px; min-width: 0; }

        .pf-logo {
          width: 44px; height: 44px; flex: 0 0 44px; border-radius: 13px;
          display: grid; place-items: center;
          background: linear-gradient(135deg, var(--pf-purple), var(--pf-pink));
          box-shadow: 0 0 24px #9146ff90;
        }
        .pf-logo svg { width: 28px; height: 28px; }

        .pf-brand-name {
          font-weight: 900; font-size: 24px; letter-spacing: -0.5px;
          background: linear-gradient(90deg, var(--pf-violet), var(--pf-pink));
          -webkit-background-clip: text; background-clip: text; color: transparent;
        }
        .pf-brand-sub { margin-top: 2px; color: var(--pf-muted); font-size: 10px; font-weight: 700; letter-spacing: 2px; }

        .pf-testnet {
          display: flex; align-items: center; gap: 9px; padding: 8px 13px;
          border: 1px solid #ffd54f66; border-radius: 30px; background: #ffd54f14;
          color: var(--pf-gold); font-size: 11px; font-weight: 800; letter-spacing: 1px; white-space: nowrap;
        }

        .pf-live-dot {
          width: 7px; height: 7px; border-radius: 50%;
          background: var(--pf-gold); box-shadow: 0 0 10px #ffd54f;
          animation: pf-twinkle 1.2s ease-in-out infinite alternate;
        }

        .pf-main { max-width: 1080px; margin: 44px auto 0; animation: pf-rise .45s cubic-bezier(.2, .8, .2, 1); }

        .pf-eyebrow {
          display: inline-flex; align-items: center; gap: 8px; padding: 6px 12px;
          border: 1px solid #ffffff30; border-radius: 30px; background: #ffffff12;
          color: #fff; font-size: 10px; font-weight: 900; letter-spacing: 1.6px; text-transform: uppercase;
        }
        .pf-eyebrow-line::before { content: "✦"; color: var(--pf-gold); }

        .pf-page-title {
          margin: 16px 0 10px; font-size: clamp(36px, 5.5vw, 56px); line-height: 1.04;
          font-weight: 900; letter-spacing: -1.5px;
          text-shadow: 0 0 30px #ff4fd855;
        }

        .pf-page-title span {
          background: linear-gradient(90deg, var(--pf-violet), var(--pf-pink));
          -webkit-background-clip: text; background-clip: text; color: transparent;
        }

        .pf-page-subtitle { margin: 0; max-width: 620px; color: var(--pf-muted); font-size: 15px; line-height: 1.65; }

        .pf-layout {
          display: grid; grid-template-columns: minmax(0, 1fr) minmax(330px, 410px);
          gap: 22px; align-items: start; margin-top: 30px;
        }

        .pf-panel {
          min-width: 0; border: 1px solid var(--pf-border); border-radius: 24px;
          background: var(--pf-panel); backdrop-filter: blur(10px);
          box-shadow: 0 0 36px -8px #9146ff66, 0 20px 55px #0006; overflow: hidden;
          transition: border-color .2s, box-shadow .2s;
        }
        .pf-panel:hover { border-color: #9146ffaa; box-shadow: 0 0 44px -6px #9146ff88, 0 20px 55px #0006; }

        .pf-panel-heading {
          display: flex; align-items: center; gap: 12px; padding: 19px 22px;
          border-bottom: 1px solid var(--pf-border);
        }

        .pf-step {
          width: 34px; height: 34px; flex: 0 0 34px; display: grid; place-items: center;
          border-radius: 11px; background: var(--pf-gradient); color: #fff;
          font-size: 13px; font-weight: 900; box-shadow: 0 0 16px #ff4fd860;
        }

        .pf-panel-title { font-size: 15px; font-weight: 800; }
        .pf-panel-subtitle { margin-top: 3px; color: var(--pf-muted); font-size: 12px; }
        .pf-panel-body { padding: 22px; }

        .pf-creator {
          position: relative; display: flex; align-items: center; gap: 16px; padding: 18px;
          border: 1px solid var(--pf-border); border-radius: 18px; overflow: hidden;
          background: linear-gradient(120deg, #2a1468, #5b21b6 60%, #ff4fd8);
        }
        .pf-creator::after {
          content: "✦"; position: absolute; right: 18px; top: 10px; color: #fff; opacity: .7;
          animation: pf-twinkle 2s ease-in-out infinite alternate;
        }

        .pf-avatar {
          width: 64px; height: 64px; flex: 0 0 64px; padding: 3px; border-radius: 50%;
          background: conic-gradient(var(--pf-purple), var(--pf-pink), var(--pf-cyan), var(--pf-purple));
          box-shadow: 0 0 20px #ff4fd880;
        }
        .pf-avatar-inner {
          width: 100%; height: 100%; border-radius: 50%; overflow: hidden; display: grid; place-items: center;
          background: #2a1468; color: #fff; font-size: 24px; font-weight: 900;
        }
        .pf-avatar-inner img { width: 100%; height: 100%; object-fit: cover; display: block; }

        .pf-small-label { color: var(--pf-muted); font-size: 10px; font-weight: 800; letter-spacing: 1.6px; text-transform: uppercase; }
        .pf-creator .pf-small-label { color: #ffffffbb; }
        .pf-creator-name { margin-top: 4px; overflow-wrap: anywhere; font-size: 20px; font-weight: 900; color: #fff; }
        .pf-creator-caption { margin-top: 3px; color: #ffffffcc; font-size: 12px; }
        .pf-field-label { display: block; margin-bottom: 10px; color: var(--pf-text); font-size: 12px; font-weight: 800; letter-spacing: .5px; }

        .pf-amount-wrap { position: relative; }

        .pf-currency {
          position: absolute; top: 50%; left: 18px; transform: translateY(-50%);
          color: var(--pf-violet); font-size: 24px; font-weight: 800;
        }

        .pf-amount-input {
          width: 100%; min-height: 70px; padding: 16px 15px 16px 44px;
          border: 1px solid var(--pf-border); border-radius: 16px; background: var(--pf-panel-raised);
          color: white; font-size: 32px; font-weight: 900; outline: none;
          transition: border-color 150ms, box-shadow 150ms;
        }

        .pf-amount-input:focus { border-color: var(--pf-purple); box-shadow: 0 0 0 3px #9146ff40, 0 0 24px #9146ff40; }
        .pf-amount-input:disabled { opacity: 0.55; cursor: not-allowed; }

        .pf-presets { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 9px; margin-top: 12px; }

        .pf-preset {
          min-height: 44px; border: 1px solid var(--pf-border); border-radius: 30px;
          background: var(--pf-panel-raised); color: var(--pf-text); font-size: 13px;
          font-weight: 800; cursor: pointer; transition: border-color 150ms, background 150ms, transform 150ms;
        }

        .pf-preset:hover:not(:disabled) { border-color: var(--pf-purple); transform: translateY(-1px); }
        .pf-preset.active { border-color: var(--pf-pink); background: #9146ff40; color: #fff; box-shadow: 0 0 16px #ff4fd860; }
        .pf-preset:disabled { cursor: not-allowed; opacity: 0.55; }

        .pf-rate-note { margin-top: 13px; color: var(--pf-muted); font-size: 12px; line-height: 1.7; }
        .pf-divider { height: 1px; margin: 24px 0; background: var(--pf-border); }
        .pf-summary-title { margin-bottom: 16px; font-size: 13px; font-weight: 800; }
        .pf-split-list { display: grid; gap: 14px; }

        .pf-split-row {
          display: grid; grid-template-columns: 10px minmax(0, 1fr) auto;
          align-items: center; gap: 10px; color: var(--pf-text); font-size: 13px;
        }

        .pf-split-dot { width: 10px; height: 10px; border-radius: 50%; background: var(--pf-purple); box-shadow: 0 0 10px var(--pf-purple); }
        .pf-split-row:nth-child(2) .pf-split-dot { background: var(--pf-pink); box-shadow: 0 0 10px var(--pf-pink); }
        .pf-split-row:nth-child(3) .pf-split-dot { background: var(--pf-cyan); box-shadow: 0 0 10px var(--pf-cyan); }
        .pf-split-value { font-weight: 800; white-space: nowrap; }

        .pf-total {
          display: flex; align-items: end; justify-content: space-between; gap: 12px;
          margin-top: 20px; padding: 17px; border: 1px solid #9146ff66;
          border-radius: 16px; background: #9146ff1a;
        }

        .pf-total-label { color: var(--pf-muted); font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; }
        .pf-total-value { margin-top: 6px; color: white; font-size: 32px; font-weight: 900; }
        .pf-total-unit { color: var(--pf-gold); font-size: 12px; font-weight: 900; }
        .pf-right-body { padding: 22px; }

        .pf-payment-amount {
          padding: 24px 18px; border: 1px solid #9146ff66; border-radius: 18px;
          background: radial-gradient(ellipse at 100% 0%, #ff4fd833, transparent 60%), #9146ff14;
          text-align: center;
        }

        .pf-big-amount { margin-top: 10px; font-size: clamp(42px, 5vw, 54px); font-weight: 900; letter-spacing: -1px; overflow-wrap: anywhere; text-shadow: 0 0 24px #9146ff99; }
        .pf-big-amount small { margin-left: 7px; color: var(--pf-gold); font-size: 13px; font-weight: 900; letter-spacing: 1px; text-shadow: none; }
        .pf-amount-caption { margin-top: 4px; color: var(--pf-muted); font-size: 12px; }

        .pf-network-row {
          display: flex; align-items: center; justify-content: space-between;
          gap: 12px; margin-top: 16px; padding: 12px 0;
          border-bottom: 1px solid var(--pf-border);
        }

        .pf-network-name { display: flex; align-items: center; gap: 10px; font-size: 13px; font-weight: 700; }
        .pf-network-icon { display: grid; width: 32px; height: 32px; place-items: center; border-radius: 10px; background: #9146ff2e; color: var(--pf-violet); font-weight: 900; }
        .pf-network-value { color: var(--pf-muted); font-size: 11px; text-align: right; }
        .pf-network-value strong { display: block; margin-bottom: 3px; color: var(--pf-text); font-size: 13px; }

        .pf-primary-button {
          width: 100%; min-height: 54px; display: flex; align-items: center;
          justify-content: center; gap: 10px; margin-top: 22px; padding: 14px 16px;
          border: 0; border-radius: 14px; background: var(--pf-gradient); color: #fff;
          font-size: 14px; font-weight: 900; letter-spacing: 0.4px;
          cursor: pointer; box-shadow: 0 4px 20px #9146ff80;
          transition: transform 150ms, box-shadow 150ms;
        }

        .pf-primary-button:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 6px 28px #ff4fd899; }
        .pf-primary-button:disabled { cursor: not-allowed; opacity: 0.45; transform: none; box-shadow: none; }
        .pf-arrow { font-size: 18px; }

        .pf-secondary-button {
          width: 100%; min-height: 46px; margin-top: 12px; padding: 11px 14px;
          border: 1.4px solid var(--pf-purple); border-radius: 14px; background: transparent;
          color: var(--pf-text); font-size: 13px; font-weight: 800; cursor: pointer;
          transition: background 150ms;
        }

        .pf-secondary-button:hover:not(:disabled) { background: #9146ff22; }
        .pf-secondary-button:disabled { cursor: not-allowed; opacity: 0.5; }

        .pf-security { display: flex; align-items: flex-start; gap: 10px; margin-top: 18px; color: var(--pf-muted); font-size: 11px; line-height: 1.7; }
        .pf-security-icon { flex: 0 0 auto; color: var(--pf-violet); font-size: 15px; }

        .pf-status {
          margin-top: 18px; padding: 14px; border: 1px solid var(--pf-border);
          border-radius: 14px; background: var(--pf-panel-raised); color: var(--pf-text);
          font-size: 13px; line-height: 1.7; overflow-wrap: anywhere;
        }

        .pf-status.success { border-color: #3df2ff88; background: #3df2ff14; color: #b8fbff; box-shadow: 0 0 20px #3df2ff30; }
        .pf-status.failed { border-color: #ff3b6b88; background: #ff3b6b14; color: #ffc0cf; }
        .pf-status.pending { border-color: #ffd54f88; background: #ffd54f12; color: #ffe7a0; }
        .pf-status-label { display: block; margin-bottom: 5px; font-size: 10px; font-weight: 900; letter-spacing: 1.4px; text-transform: uppercase; }

        .pf-hash { margin-top: 18px; padding: 14px; border: 1px solid var(--pf-border); border-radius: 14px; background: var(--pf-panel-raised); }
        .pf-hash a { display: block; margin-top: 9px; color: var(--pf-violet); font-size: 11px; line-height: 1.7; overflow-wrap: anywhere; text-decoration: none; }
        .pf-hash a:hover { text-decoration: underline; }

        .pf-footer {
          max-width: 1080px; display: flex; justify-content: space-between; gap: 18px;
          margin: 30px auto 0; padding-top: 18px; border-top: 1px solid #342a6099;
          color: var(--pf-muted); font-size: 11px; line-height: 1.7;
        }

        .pf-footer strong { color: var(--pf-text); }
        .pf-footer-right { text-align: right; }

        @media (max-width: 800px) {
          .payment-shell { padding: 0 18px 26px; }
          .pf-main { margin-top: 30px; }
          .pf-layout { grid-template-columns: minmax(0, 1fr); gap: 18px; margin-top: 24px; }
          .pf-right-column { order: -1; }
          .pf-footer { flex-direction: column; }
          .pf-footer-right { text-align: left; }
        }

        @media (max-width: 430px) {
          .payment-shell { padding-right: 12px; padding-left: 12px; }
          .pf-topbar { min-height: 66px; }
          .pf-brand-name { font-size: 20px; }
          .pf-brand-sub { font-size: 9px; letter-spacing: 1px; }
          .pf-logo { width: 38px; height: 38px; flex-basis: 38px; }
          .pf-testnet { gap: 6px; padding: 7px 9px; font-size: 9px; letter-spacing: 0.5px; }
          .pf-panel-heading { padding: 16px; }
          .pf-panel-body, .pf-right-body { padding: 16px; }
          .pf-presets { gap: 6px; }
          .pf-preset { font-size: 12px; }
        }

        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            scroll-behavior: auto !important;
            animation: none !important;
            transition: none !important;
          }
        }
      `}</style>

      <div className="pf-space" aria-hidden="true">
        <svg className="pf-planet" viewBox="0 0 200 200">
          <defs>
            <linearGradient id="pf-ring" x1="0" x2="1">
              <stop offset="0" stopColor="#B98CFF" />
              <stop offset=".5" stopColor="#FFC89A" />
              <stop offset="1" stopColor="#FF4FD8" />
            </linearGradient>
            <radialGradient id="pf-body" cx=".35" cy=".3" r=".8">
              <stop offset="0" stopColor="#FFE6D3" />
              <stop offset=".55" stopColor="#FFC89A" />
              <stop offset="1" stopColor="#FF4FD8" />
            </radialGradient>
          </defs>
          <g transform="rotate(-22 100 100)">
            <path d="M20 100a80 24 0 0 1 160 0" fill="none" stroke="url(#pf-ring)" strokeWidth="9" strokeLinecap="round" />
            <circle cx="100" cy="100" r="50" fill="url(#pf-body)" />
            <ellipse cx="100" cy="86" rx="60" ry="7" fill="#fff" opacity=".16" />
            <path d="M180 100a80 24 0 0 1-160 0" fill="none" stroke="url(#pf-ring)" strokeWidth="9" strokeLinecap="round" />
          </g>
        </svg>
      </div>

      <header className="pf-topbar">
        <div className="pf-brand">
          <div className="pf-logo" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <rect x="6.2" y="1" width="11.6" height="3.4" rx="1.2" fill="#fff" />
              <path d="M8.2 5.3h7.6v1.4c3.7 1.2 5.3 2.9 5.3 5.8v7.2c0 1.9-1.5 3.3-3.3 3.3H6.2c-1.8 0-3.3-1.4-3.3-3.3v-7.2c0-2.9 1.6-4.6 5.3-5.8z" fill="#fff" />
              <circle cx="12" cy="15.4" r="3.8" fill="#FFD54F" />
            </svg>
          </div>
          <div>
            <div className="pf-brand-name">JarJar</div>
            <div className="pf-brand-sub">PAYMENTS BY PAIFLOW</div>
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
          Support the community
        </div>

        <h1 className="pf-page-title">
          Fuel <span>{creator}</span>
        </h1>

        <p className="pf-page-subtitle">
          Every tip helps {creator} keep creating. Choose your amount, review
          the split, and approve the payment securely in your Freighter wallet.
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
                  <div className="pf-avatar-inner">
                    {handle && !avatarFailed ? (
                      <img
                        src={`https://api.dicebear.com/9.x/adventurer/png?seed=${encodeURIComponent(handle)}&size=160`}
                        alt=""
                        onError={() => setAvatarFailed(true)}
                      />
                    ) : (
                      creator.trim().slice(0, 1).toUpperCase() || "C"
                    )}
                  </div>
                </div>
                <div style={{ minWidth: 0 }}>
                  <div className="pf-small-label">You are supporting</div>
                  <div className="pf-creator-name">{creator}</div>
                  <div className="pf-creator-caption">{handle ?? "Creator community contribution"}</div>
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
          <strong>JarJar</strong> · Payments by PaiFlow
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
            background: "#0b0718",
            color: "#f4f0ff",
            fontFamily: "system-ui, sans-serif",
          }}
        >
          Loading JarJar payments...
        </main>
      }
    >
      <SendTipForm />
    </Suspense>
  );
}
