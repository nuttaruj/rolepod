/**
 * rolepod opencode plugin — best-effort session hygiene shim.
 *
 * Scope (v1, deliberately small — every handler fails open):
 *   1. session.created  → register this session in the cross-CLI lock
 *      protocol at ~/.rolepod/session-locks/<sha256(worktree)[:16]>/, the
 *      same registry rolepod's Claude / Gemini / agy hooks maintain, so
 *      sibling sessions in ANY rolepod-equipped CLI can warn about
 *      concurrent edits to the same worktree. Stale locks (>30 min) are
 *      pruned on contact; a fresh sibling triggers a toast when the TUI
 *      client exposes one.
 *   2. session.compacted → post-compact re-anchor nudge (manage-context §7):
 *      trust disk over summary — plan checkboxes, git log, spec.
 *
 * NOT here (v1): pre-commit / subagent-commit gates. Detecting the agent
 * context inside tool.execute.before is undocumented; the gates stay
 * skill-enforced on opencode (see AGENTS.md "opencode specifics").
 *
 * Every handler is wrapped so a failure never breaks the user's session —
 * a hygiene shim must never cost more than the hygiene it buys.
 */

import { createHash } from "node:crypto"
import { execSync } from "node:child_process"
import * as fs from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

const STALE_MS = 30 * 60 * 1000 // matches session-lifecycle.sh STALE_THRESHOLD

const REANCHOR_MSG =
  "rolepod post-compact re-anchor: the summary is a lossy narrator, not a " +
  "state file. Before the next action: re-read the plan artifact " +
  "(checkboxes mark the real position), run `git log --oneline -5` + " +
  "`git status`, re-open the spec if the flow has one. Disk beats summary " +
  "on every conflict."

function worktreeRoot(dir) {
  try {
    return execSync("git rev-parse --show-toplevel", {
      cwd: dir,
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim()
  } catch {
    return null
  }
}

function lockDirFor(worktree) {
  const hash = createHash("sha256").update(worktree).digest("hex").slice(0, 16)
  return path.join(os.homedir(), ".rolepod", "session-locks", hash)
}

export const RolepodPlugin = async ({ directory, client }) => {
  let sessionId = null

  const registerLock = (id) => {
    const worktree = worktreeRoot(directory || process.cwd())
    if (!worktree) return // non-git dir = no stomp risk (same as bash hook)
    const lockDir = lockDirFor(worktree)
    fs.mkdirSync(lockDir, { recursive: true })

    let activeSiblings = 0
    const now = Date.now()
    for (const entry of fs.readdirSync(lockDir)) {
      if (!entry.endsWith(".lock")) continue
      if (entry === `${id}.lock`) continue
      const p = path.join(lockDir, entry)
      try {
        const age = now - fs.statSync(p).mtimeMs
        if (age < STALE_MS) activeSiblings += 1
        else fs.rmSync(p, { force: true })
      } catch {
        /* raced with another session's prune — ignore */
      }
    }
    fs.writeFileSync(path.join(lockDir, `${id}.lock`), "")

    if (activeSiblings > 0 && process.env.ROLEPOD_ALLOW_SHARED_WORKTREE !== "1") {
      toast(
        `rolepod: ${activeSiblings} sibling session(s) active in this ` +
          "worktree (possibly another CLI). Concurrent edits will stomp " +
          "each other — isolate with `git worktree add` before editing, or " +
          "set ROLEPOD_ALLOW_SHARED_WORKTREE=1 if intentional.",
      )
    }
  }

  const toast = (message) => {
    try {
      client?.tui?.showToast?.({ body: { message, variant: "warning" } })
    } catch {
      /* headless / older client — the lock itself still protects siblings */
    }
  }

  return {
    event: async ({ event }) => {
      try {
        if (event?.type === "session.created") {
          sessionId =
            event?.properties?.info?.id ?? `opencode-${process.pid}-${Date.now()}`
          registerLock(sessionId)
        } else if (event?.type === "session.compacted") {
          toast(REANCHOR_MSG)
        }
      } catch {
        /* fail open — hygiene must never break the session */
      }
    },
  }
}
