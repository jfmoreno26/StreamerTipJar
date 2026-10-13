"use client";
import { useEffect, useState } from "react";

type Row = { id: string; title: string; payer: string; amountStroops: string; dueDate: string; status: string };
const xlm = (s: string) => (Number(s) / 1e7).toString();

export default function Admin() {
  const [rows, setRows] = useState<Row[]>([]);
  const [form, setForm] = useState({ title: "", payer: "", amountXlm: "", dueDate: "" });
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const load = async () => setRows(await (await fetch("/api/bills")).json());
  useEffect(() => { load(); }, []);

  async function create(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setMsg("");
    try {
      const res = await fetch("/api/bills", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(form) });
      const out = await res.json();
      if (!res.ok || out.error) throw new Error(out.error || `HTTP ${res.status}`);
      setForm({ title: "", payer: "", amountXlm: "", dueDate: "" });
      setMsg(`Created "${out.title}".`);
    } catch (e: any) {
      setMsg(e.message);
    } finally {
      setBusy(false); load();
    }
  }

  const field = (k: keyof typeof form) => ({ value: form[k], onChange: (e: React.ChangeEvent<HTMLInputElement>) => setForm({ ...form, [k]: e.target.value }), required: true });

  return (
    <main style={{ maxWidth: 720, margin: "2rem auto", fontFamily: "system-ui", padding: "0 1rem" }}>
      <h1>Admin: bills</h1>
      <form onSubmit={create} style={{ display: "grid", gap: 8, maxWidth: 400 }}>
        <input placeholder="Title" {...field("title")} />
        <input placeholder="Payer" {...field("payer")} />
        <input placeholder="Amount (XLM)" inputMode="decimal" {...field("amountXlm")} />
        <input type="date" {...field("dueDate")} />
        <button disabled={busy}>Create bill</button>
      </form>
      {msg && <p role="alert">{msg}</p>}
      <table style={{ width: "100%", marginTop: 24, borderCollapse: "collapse" }}>
        <thead><tr><th align="left">Title</th><th align="left">Payer</th><th align="right">XLM</th><th align="left">Due</th><th align="left">Status</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} style={{ borderTop: "1px solid #ddd" }}>
              <td>{r.title}</td><td>{r.payer}</td><td align="right">{xlm(r.amountStroops)}</td><td>{r.dueDate.slice(0, 10)}</td><td>{r.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  );
}
