import { NextResponse } from "next/server";

const CODE = /^[A-Za-z0-9]{24,64}$/;
const STELLAR_ADDRESS = /^G[A-Z2-7]{55}$/;
const TTL_MS = 10 * 60 * 1000;

type Link = { address: string; expires: number };
const links: Map<string, Link> = ((globalThis as any).__walletLinks ??= new Map());

function prune() {
  const now = Date.now();
  for (const [code, link] of links) if (link.expires < now) links.delete(code);
}

export async function POST(req: Request) {
  const b = await req.json().catch(() => null);
  if (!b || !CODE.test(String(b.code ?? "")) || !STELLAR_ADDRESS.test(String(b.address ?? ""))) {
    return NextResponse.json({ error: "Invalid code or wallet address" }, { status: 400 });
  }
  prune();
  links.set(b.code, { address: b.address, expires: Date.now() + TTL_MS });
  return NextResponse.json({ ok: true });
}

export async function GET(req: Request) {
  const code = new URL(req.url).searchParams.get("code") ?? "";
  if (!CODE.test(code)) return NextResponse.json({ error: "Invalid code" }, { status: 400 });
  prune();
  const link = links.get(code);
  if (!link) return NextResponse.json({ status: "waiting" });
  links.delete(code);
  return NextResponse.json({ status: "linked", address: link.address });
}
