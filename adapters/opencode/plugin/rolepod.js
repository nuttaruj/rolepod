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
 *   3. tool.execute.after → session evidence tracker: edit/write on a
 *      high-risk path vs a test path (in-memory counters, this session).
 *   4. tool.execute.before → precommit gate: `git commit` while high-risk
 *      paths were edited and ZERO test evidence exists → throw (opencode's
 *      documented deny mechanism). ROLEPOD_GATES_SOFT=1 logs the bypass to
 *      .rolepod/evidence/bypass.log instead (same file `make stats` reads).
 *
 * Subagent-commit ban is NOT here — it ships as `permission:` blocks in
 * every rendered agent file (platform-enforced; see build/merge-agent.py),
 * because agent identity inside tool.execute.before is undocumented.
 *
 * Every handler is wrapped so a failure never breaks the user's session —
 * a hygiene shim must never cost more than the hygiene it buys. The gate
 * only ever denies on POSITIVE evidence (risk edits seen, no test edits) —
 * unknown payload shapes fall through to allow, never to block.
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

// Canonical high-risk regex — byte-equivalent (modulo JS `\/` escaping) to
// the RISK_CANON pinned in tests/static/lean-surface.sh across all shells.
const RISK_RE =
  /(^|\/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(\/|\.|_|$)/i
const TEST_RE =
  /(^|\/)(tests?|__tests__|spec|e2e)\/|\.(test|spec)\.[jt]sx?$|_test\.(go|py|rb|exs?|rs)$|(^|\/)test_[^/]*\.py$/i

// git-commit detection — token walk ported from hooks/precommit-gate.sh.
// The old adjacency regex missed flag-separated forms entirely:
// `git -C /repo commit` and `git -c k=v commit` walked straight past the
// adapter's only hard-deny gate. Whitespace split matches the bash walk's
// shlex fallback semantics (glued `;git` misses on both — same limitation).
const VALUE_OPTS = new Set(["-C", "--git-dir", "--work-tree", "--namespace", "--exec-path"])
function isGitCommit(cmd) {
  const toks = cmd.split(/\s+/).filter(Boolean)
  for (let i = 0; i < toks.length; i++) {
    if (path.basename(toks[i]) !== "git") continue
    let j = i + 1
    while (j < toks.length && toks[j].startsWith("-")) {
      if (VALUE_OPTS.has(toks[j])) j += 2
      else if (toks[j] === "-c" && j + 1 < toks.length && toks[j + 1].includes("=")) j += 2
      else j += 1
    }
    if (j < toks.length && toks[j] === "commit") return true
  }
  return false
}

export const RolepodPlugin = async ({ directory, client }) => {
  let sessionId = null
  let riskEdits = 0
  let testEvidence = 0

  const logBypass = () => {
    try {
      const worktree = worktreeRoot(directory || process.cwd())
      if (!worktree) return
      const dir = path.join(worktree, ".rolepod", "evidence")
      fs.mkdirSync(dir, { recursive: true })
      fs.appendFileSync(
        path.join(dir, "bypass.log"),
        JSON.stringify({
          ts: new Date().toISOString(),
          hook: "opencode-precommit-gate",
          var: "ROLEPOD_GATES_SOFT",
          reason: "unreasoned",
        }) + "\n",
      )
    } catch {
      /* fail open */
    }
  }

  const registerLock = (id) => {
    const worktree = worktreeRoot(directory || process.cwd())
    if (!worktree) return // non-git dir = no stomp risk (same as bash hook)

    // Combined-mode marker for child plugins (uiproof/wplab/dblab) — parent
    // active in this worktree. opencode has no session-end hook; the marker
    // persists, and stale is benign (children only read its presence).
    try {
      const rp = path.join(worktree, ".rolepod")
      fs.mkdirSync(rp, { recursive: true })
      fs.writeFileSync(path.join(rp, "parent-active"), "v1\n")
    } catch {
      /* fail open */
    }

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

    "tool.execute.after": async (input, output) => {
      try {
        const tool = String(input?.tool ?? "")
        if (tool !== "edit" && tool !== "write") return
        const fp = String(output?.args?.filePath ?? output?.args?.file_path ?? "")
        if (!fp) return
        if (TEST_RE.test(fp)) testEvidence += 1
        else if (RISK_RE.test(fp)) riskEdits += 1
      } catch {
        /* fail open — evidence tracking must never break an edit */
      }
    },

    "tool.execute.before": async (input, output) => {
      let block = false
      try {
        if (String(input?.tool ?? "") !== "bash") return
        const cmd = String(output?.args?.command ?? "")
        if (!isGitCommit(cmd)) return
        if (riskEdits > 0 && testEvidence === 0) {
          if (process.env.ROLEPOD_GATES_SOFT === "1") logBypass()
          else block = true
        }
      } catch {
        /* fail open — unknown payload shape must never block */
      }
      if (block) {
        throw new Error(
          "rolepod precommit gate: this session edited " +
            `${riskEdits} high-risk path(s) (auth/billing/migration/security` +
            "-class) with zero test evidence. Run the check-work skill (or " +
            "add/run a test touching the changed surface) before `git " +
            "commit`. Intentional override: ROLEPOD_GATES_SOFT=1 (logged to " +
            ".rolepod/evidence/bypass.log, surfaced by `make stats`).",
        )
      }
    },
  }
}
