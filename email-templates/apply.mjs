import { execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PROJECT = "streamertipjar";
const ACTION_URL = "https://streamertipjar.web.app/auth/action";

execSync(`firebase projects:list`, { stdio: "ignore" });
const { tokens } = JSON.parse(
  fs.readFileSync(path.join(os.homedir(), ".config/configstore/firebase-tools.json"), "utf8"),
);

const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));
const body = fs
  .readFileSync(path.join(here, "password-reset.html"), "utf8")
  .replace(/^\s*<!--[\s\S]*?-->\s*/, "");

const fields = ["notification.sendEmail.resetPasswordTemplate", "notification.sendEmail.callbackUri"];
const res = await fetch(
  `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT}/config?updateMask=${fields.join(",")}`,
  {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${tokens.access_token}`,
      "x-goog-user-project": PROJECT,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      notification: {
        sendEmail: {
          callbackUri: ACTION_URL,
          resetPasswordTemplate: {
            senderLocalPart: "noreply",
            senderDisplayName: "JarJar",
            subject: "Reset your JarJar password",
            body,
            bodyFormat: "HTML",
          },
        },
      },
    }),
  },
);

const json = await res.json();
if (!res.ok) {
  console.error("Failed:", json.error?.message ?? json);
  process.exit(1);
}
const t = json.notification.sendEmail.resetPasswordTemplate;
console.log("Applied:", {
  subject: t.subject,
  sender: t.senderDisplayName,
  callbackUri: json.notification.sendEmail.callbackUri,
  bodyLength: t.body.length,
});
