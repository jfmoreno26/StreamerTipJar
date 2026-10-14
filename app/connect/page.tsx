"use client";

import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { getNetworkDetails, requestAccess } from "@stellar/freighter-api";

const TESTNET = "Test SDF Network ; September 2015";

function ConnectWallet() {
  const code = useSearchParams().get("code") ?? "";
  const validCode = /^[A-Za-z0-9]{24,64}$/.test(code);
  const [state, setState] = useState<"idle" | "busy" | "done" | "error">("idle");
  const [message, setMessage] = useState("");
  const [address, setAddress] = useState("");

  async function connect() {
    setState("busy");
    setMessage("");
    try {
      const access: any = await requestAccess();
      if (access.error || !access.address) throw new Error("Allow wallet access in Freighter to continue.");

      const network: any = await getNetworkDetails();
      if (network.error || network.networkPassphrase !== TESTNET) {
        throw new Error("Switch Freighter to Stellar Testnet, then try again.");
      }

      const res = await fetch("/api/wallet-link", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code, address: access.address }),
      });
      if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error ?? `HTTP ${res.status}`);

      setAddress(access.address);
      setState("done");
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not connect your wallet.");
      setState("error");
    }
  }

  return (
    <main className="cw-shell">
      <style jsx global>{`
        :root { color-scheme: dark; }
        html { background: linear-gradient(#0b0718, #1b0f3d) fixed; }
        html body {
          background: transparent; color: #f4f0ff;
          font-family: "Segoe UI", system-ui, -apple-system, Roboto, sans-serif;
        }
        .cw-shell {
          min-height: 100vh; display: flex; flex-direction: column; align-items: center;
          justify-content: center; gap: 20px; padding: 32px 16px;
          background:
            radial-gradient(ellipse 60% 50% at 10% 0%, #9146ff38, transparent 70%),
            radial-gradient(ellipse 50% 45% at 100% 80%, #ff4fd830, transparent 70%);
        }
        .cw-brand { display: flex; align-items: center; gap: 12px; font-size: 26px; font-weight: 900; }
        .cw-brand span {
          background: linear-gradient(90deg, #b98cff, #ff4fd8);
          -webkit-background-clip: text; background-clip: text; color: transparent;
        }
        .cw-logo {
          width: 46px; height: 46px; border-radius: 14px; display: grid; place-items: center;
          background: linear-gradient(135deg, #9146ff, #ff4fd8); box-shadow: 0 0 26px #9146ff90;
        }
        .cw-card {
          width: 100%; max-width: 440px; padding: 30px; text-align: center;
          border: 1px solid #342a60; border-radius: 28px; background: #140e2be0;
          box-shadow: 0 0 40px -6px #9146ff55, 0 24px 60px #0007;
        }
        .cw-card h1 { margin: 10px 0 8px; font-size: 24px; font-weight: 900; }
        .cw-card p { margin: 0; color: #a99dcf; line-height: 1.6; font-size: 14px; }
        .cw-icon {
          width: 64px; height: 64px; margin: 0 auto; display: grid; place-items: center;
          border-radius: 50%; font-size: 28px; background: linear-gradient(135deg, #9146ff, #ff4fd8);
          box-shadow: 0 0 28px #ff4fd880;
        }
        .cw-button {
          width: 100%; margin-top: 22px; padding: 15px; border: 0; border-radius: 14px;
          background: linear-gradient(90deg, #9146ff, #ff4fd8); color: #fff;
          font: inherit; font-weight: 800; cursor: pointer; box-shadow: 0 4px 18px #9146ff70;
        }
        .cw-button:disabled { opacity: .55; cursor: progress; }
        .cw-address {
          margin-top: 16px; padding: 12px; border-radius: 12px; background: #1e1641;
          border: 1px solid #342a60; font-family: Consolas, monospace; font-size: 12px;
          overflow-wrap: anywhere; color: #f4f0ff;
        }
        .cw-error {
          margin-top: 16px; padding: 11px 13px; border-radius: 12px; font-size: 13px;
          border: 1px solid #ff3b6b80; background: #ff3b6b18; color: #ffc0cf;
        }
      `}</style>

      <div className="cw-brand">
        <div className="cw-logo" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="30" height="30">
            <rect x="6.2" y="1" width="11.6" height="3.4" rx="1.2" fill="#fff" />
            <path d="M8.2 5.3h7.6v1.4c3.7 1.2 5.3 2.9 5.3 5.8v7.2c0 1.9-1.5 3.3-3.3 3.3H6.2c-1.8 0-3.3-1.4-3.3-3.3v-7.2c0-2.9 1.6-4.6 5.3-5.8z" fill="#fff" />
            <circle cx="12" cy="15.4" r="3.8" fill="#FFD54F" />
          </svg>
        </div>
        <span>JarJar</span>
      </div>

      <section className="cw-card" aria-live="polite">
        {!validCode ? (
          <>
            <div className="cw-icon">!</div>
            <h1>Link not recognised</h1>
            <p>Start again from the Wallet tab in the JarJar app.</p>
          </>
        ) : state === "done" ? (
          <>
            <div className="cw-icon">✓</div>
            <h1>Wallet connected</h1>
            <p>You can close this tab and return to JarJar. Your balance will appear in the Wallet tab.</p>
            <div className="cw-address">{address}</div>
          </>
        ) : (
          <>
            <div className="cw-icon">👛</div>
            <h1>Connect your wallet</h1>
            <p>
              Share your Freighter wallet address with JarJar so the app can show your live balance.
              This only reads your public address — it can't move any funds.
            </p>
            <button className="cw-button" disabled={state === "busy"} onClick={() => void connect()}>
              {state === "busy" ? "Waiting for Freighter…" : "Connect Freighter"}
            </button>
            {state === "error" && <div className="cw-error" role="alert">{message}</div>}
          </>
        )}
      </section>
    </main>
  );
}

export default function ConnectPage() {
  return (
    <Suspense fallback={null}>
      <ConnectWallet />
    </Suspense>
  );
}
