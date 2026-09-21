import { releaseDueInvitations } from "./api/_invitation-handler.js";
import { databaseHealth, databasePool } from "./api/_database.js";

let stopping = false;
let running = false;

async function run() {
  if (running || stopping) return;
  running = true;
  try {
    const released = await releaseDueInvitations();
    if (released > 0) console.log(JSON.stringify({ event: "automatic_access_released", count: released }));
  } catch (error) {
    console.error("Automatische Freigabe fehlgeschlagen", { code: error?.code || "DATABASE_ERROR" });
  } finally {
    running = false;
  }
}

async function main() {
  await databaseHealth();
  await run();
  const timer = setInterval(run, 60_000);
  const shutdown = async (signal) => {
    if (stopping) return;
    stopping = true;
    clearInterval(timer);
    console.log(JSON.stringify({ event: "worker_stopping", signal }));
    await databasePool().end();
    process.exit(0);
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((error) => {
  console.error("Workerstart fehlgeschlagen", { code: error?.code || "STARTUP_ERROR" });
  process.exitCode = 1;
});
