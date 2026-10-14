import "server-only";

const STATUS = {
  SUCCESS: "Success",
  FAILED: "Failed",
  PENDING: "Pending",
} as const;

export interface TipInfo {
  id: string;
  userId: string;
  creator: string;
  amountUsd: number;
}

export function parseTip(value: unknown): TipInfo | null {
  if (!value || typeof value !== "object") return null;
  const t = value as Record<string, unknown>;
  const amountUsd = Number(t.amountUsd);
  if (
    typeof t.id !== "string" || !/^[A-Za-z0-9-]{1,64}$/.test(t.id) ||
    typeof t.userId !== "string" || !/^[A-Za-z0-9]{1,128}$/.test(t.userId) ||
    typeof t.creator !== "string" || !t.creator.trim() || t.creator.length > 100 ||
    !Number.isFinite(amountUsd) || amountUsd <= 0 || amountUsd > 1000000
  ) {
    return null;
  }
  return { id: t.id, userId: t.userId, creator: t.creator.trim(), amountUsd };
}

export async function recordTip(
  tip: TipInfo,
  status: keyof typeof STATUS,
  txHash?: string,
): Promise<void> {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!projectId || !apiKey) {
    console.warn("FIREBASE_PROJECT_ID / FIREBASE_WEB_API_KEY not set; tip not recorded.");
    return;
  }

  const now = new Date().toISOString();
  const fields: Record<string, object> = {
    userId: { stringValue: tip.userId },
    creator: { stringValue: tip.creator },
    amount: { doubleValue: tip.amountUsd },
    status: { stringValue: STATUS[status] },
    date: { timestampValue: now },
  };
  if (txHash) fields.txHash = { stringValue: txHash };
  if (status === "SUCCESS") fields.paidAt = { timestampValue: now };

  const params = new URLSearchParams({ key: apiKey });
  for (const name of Object.keys(fields)) params.append("updateMask.fieldPaths", name);

  const url =
    `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
    `/databases/(default)/documents/tips/${tip.id}?${params}`;

  const res = await fetch(url, {
    method: "PATCH",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fields }),
  });

  if (!res.ok) {
    console.error(`Could not record tip ${tip.id} as ${status}: HTTP ${res.status} ${await res.text()}`);
  }
}
