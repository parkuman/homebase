/**
 * Pi -> Rex status + notification.
 *
 * - agent starts  -> OSC 7501 state=working (Rex sidebar icon shows "working")
 * - agent settled -> OSC 7501 state=done    (icon shows "done") + OSC 777 desktop notification
 * - session exit  -> clear status
 *
 * No-op outside a Rex terminal (REX_BLOCK unset).
 * Source lives in ~/.config/rex/agents; symlinked into ~/.pi/agent/extensions/.
 *
 * OSC 7501 body is `key=value` pairs joined by ":" (see `rex block call program_status`).
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const APP = "pi";
const inRex = Boolean(process.env.REX_BLOCK);

function status(state: "working" | "done" | "idle" | "blocked"): void {
	if (!inRex) return;
	process.stdout.write(`\x1b]7501;state=${state}:app=${APP}\x1b\\`);
}

function notify(title: string, body: string): void {
	if (!inRex) return;
	// OSC 777 -> Rex "desktop_notification" event. ";" is the field separator, so strip it.
	const clean = (s: string) => s.replace(/[;\x00-\x1f]/g, " ");
	process.stdout.write(`\x1b]777;notify;${clean(title)};${clean(body)}\x1b\\`);
}

export default function (pi: ExtensionAPI) {
	pi.on("agent_start", async () => {
		status("working");
	});

	// agent_end can be followed by retries/compaction/queued work; settled is final.
	pi.on("agent_settled", async () => {
		status("done");
		notify("pi", "Done");
	});

	pi.on("session_shutdown", async () => {
		status("idle");
	});
}
