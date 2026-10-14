import "server-only";

export function mapStatus(s: string): "SUCCESS" | "FAILED" | "PENDING" {
  const v = s.toUpperCase();
  if (v === "SUCCESS") return "SUCCESS";
  if (v === "FAILED" || v === "REJECTED") return "FAILED";
  return "PENDING";
}

export interface Prepared {
  xdr: string;
  expiresAt: string;
  network: string;
  networkPassphrase: string;
  preparationRequestId: string | null;
}

export interface PaiflowClient {
  prepare(from: string, amountStroops: string): Promise<Prepared>;
  submit(signedXdr: string, preparationRequestId: string | null): Promise<{ status: string; txHash?: string }>;
  lookup(txHash: string): Promise<{ status: string }>;
}

export class PaiflowError extends Error {
  constructor(message: string, public httpStatus: number, public retryAfter?: string | null) {
    super(message);
  }
}

async function upstream(path: string, options: RequestInit = {}, preparationRequestId: string | null = null) {
  const origin = new URL(process.env.PAIFLOW_BASE_URL ?? "");
  const id = process.env.PAIFLOW_DEPLOYMENT_ID ?? "";
  const token = process.env.PAIFLOW_API_TOKEN ?? "";
  if (
    origin.protocol !== "https:" || origin.pathname !== "/" || origin.username || origin.password || origin.search || origin.hash ||
    !/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(id) ||
    !/^pfk_[a-f0-9]{64}$/.test(token)
  ) throw new Error("Invalid server configuration");

  const res = await fetch(new URL(`/api/v1/deployments/${id}/${path}`, origin), {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(preparationRequestId ? { "x-preparation-request-id": preparationRequestId } : {}),
    },
    cache: "no-store",
    signal: AbortSignal.timeout(35000),
  });
  const body: any = await res.json().catch(() => ({}));
  if (!res.ok || body?.error) {
    throw new PaiflowError(body?.error?.message ?? `HTTP ${res.status}`, res.status, res.headers.get("Retry-After"));
  }
  return { data: body.data, headers: res.headers };
}

export function createPaiflowClient(): PaiflowClient {
  return {
    async prepare(from, amountStroops) {
      const { data, headers } = await upstream("execute", { method: "POST", body: JSON.stringify({ from, amount: amountStroops }) });
      return { ...data, preparationRequestId: headers.get("x-history-request-id") };
    },
    async submit(signedXdr, preparationRequestId) {
      const { data } = await upstream("execute/submit", { method: "POST", body: JSON.stringify({ signedXdr }) }, preparationRequestId);
      return { status: String(data?.status ?? "PENDING"), txHash: data?.txHash };
    },
    async lookup(txHash) {
      if (!/^[a-f0-9]{64}$/i.test(txHash)) throw new Error("Invalid txHash");
      const { data } = await upstream(`transactions/${txHash}`);
      return { status: String(data?.status ?? "UNKNOWN") };
    },
  };
}
