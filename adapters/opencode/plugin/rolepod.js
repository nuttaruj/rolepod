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
 *   5. sweep-nudge + fix-loop-breaker (v2.133.0) → the SHARED Claude hook
 *      scripts (plugins/rolepod-shared/*.sh, byte-identical to hooks/) run
 *      behind an opencode→Claude translator: chat.message resets the sweep
 *      state, edit/write set the edit flag, read/grep/glob/list/webfetch/bash
 *      output sizes accumulate, bash exit codes feed the loop breaker. The
 *      one nudge each emits is APPENDED to the tool result the model reads
 *      (output.output) — opencode's documented context channel after a tool.
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
import { execSync, spawnSync } from "node:child_process"
import * as fs from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { fileURLToPath } from "node:url"

const STALE_MS = 30 * 60 * 1000 // matches session-lifecycle.sh STALE_THRESHOLD

// Shared hook cores (hooks/sweep-nudge.sh, hooks/fix-loop-breaker.sh) ship next
// to this file as plugins/rolepod-shared/; ROLEPOD_OC_SHARED overrides (tests).
const HERE = path.dirname(fileURLToPath(import.meta.url))
const SHARED = process.env.ROLEPOD_OC_SHARED || path.join(HERE, "rolepod-shared")
// opencode tool id → the Claude tool name the shared cores classify on.
const TOOL_MAP = {
  read: "Read", grep: "Grep", glob: "Glob", list: "Glob", webfetch: "WebFetch",
  websearch: "WebSearch", bash: "Bash", task: "Agent", edit: "Edit", write: "Write",
}
// Run one shared core with a Claude-shape stdin; return its additionalContext or "".
function runCore(name, input) {
  try {
    const script = path.join(SHARED, `${name}.sh`)
    if (!fs.existsSync(script)) return ""
    const r = spawnSync("bash", [script], {
      input: JSON.stringify(input), encoding: "utf8", timeout: 3000,
      stdio: ["pipe", "pipe", "ignore"], env: process.env,
    })
    if (r.status !== 0 || !r.stdout) return ""
    const o = JSON.parse(r.stdout)
    return String(o?.hookSpecificOutput?.additionalContext || "")
  } catch {
    return "" // fail open — a nudge must never break a tool call
  }
}

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
  // v2.134.0: edit evidence lives in the CLI-neutral ledger
  // (<worktree>/.rolepod/evidence/edits.jsonl via rolepod-shared/edit-ledger.py),
  // windowed since the last commit — the same evidence every other CLI's gate reads.
  const ledger = (args) => {
    try {
      const script = path.join(SHARED, "edit-ledger.py")
      if (!fs.existsSync(script)) return ""
      const r = spawnSync("python3", ["-I", script, ...args], { encoding: "utf8", timeout: 3000, stdio: ["ignore", "pipe", "ignore"] })
      return r.status === 0 ? String(r.stdout || "").trim() : ""
    } catch { return "" }
  }
  const lastCommitEpoch = (dir) => {
    try { return execSync("git log -1 --format=%ct", { cwd: dir, stdio: ["ignore", "pipe", "ignore"] }).toString().trim() } catch { return "" }
  }

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

    "chat.message": async (input, output) => {
      try {
        // New user prompt = new turn: the sweep counter starts over.
        const text = (output?.parts || []).filter((p) => p?.type === "text").map((p) => p.text).join("\n")
        runCore("sweep-nudge", {
          hook_event_name: "UserPromptSubmit",
          session_id: String(input?.sessionID ?? sessionId ?? ""),
          prompt: text,
        })
      } catch {
        /* fail open */
      }
    },

    "tool.execute.after": async (input, output) => {
      const tool = String(input?.tool ?? "")
      const args = input?.args ?? output?.args ?? {}
      try {
        if (tool === "edit" || tool === "write") {
          const fp = String(args?.filePath ?? args?.file_path ?? "")
          if (fp) ledger(["append", "opencode", fp, "--cwd", directory || process.cwd()])
        }
      } catch {
        /* fail open — evidence tracking must never break an edit */
      }
      // Shared cores: the nudge rides on the tool result the model reads.
      try {
        const sid = String(input?.sessionID ?? sessionId ?? "")
        const claudeTool = TOOL_MAP[tool]
        if (sid && claudeTool && typeof output?.output === "string") {
          const notes = []
          if (tool === "edit" || tool === "write") {
            runCore("sweep-nudge", { hook_event_name: "PreToolUse", session_id: sid, tool_name: claudeTool, tool_input: args })
          } else {
            const m = runCore("sweep-nudge", { hook_event_name: "PostToolUse", session_id: sid, tool_name: claudeTool, tool_response: output.output })
            if (m) notes.push(m)
          }
          if (tool === "bash") {
            const exit = output?.metadata?.exit
            const m = runCore("fix-loop-breaker", {
              hook_event_name: "PostToolUse", session_id: sid, tool_name: "Bash",
              tool_input: { command: String(args?.command ?? "") },
              tool_response: { stdout: output.output, exit_code: typeof exit === "number" ? exit : undefined },
            })
            if (m) notes.push(m)
          }
          if (notes.length) output.output += "\n\n" + notes.join("\n\n")
        }
      } catch {
        /* fail open */
      }
    },

    "tool.execute.before": async (input, output) => {
      let block = false
      let riskEdits = 0
      let testEvidence = 0
      try {
        if (String(input?.tool ?? "") !== "bash") return
        const cmd = String(output?.args?.command ?? "")
        if (!isGitCommit(cmd)) return
        const dir = directory || process.cwd()
        const counts = ledger(["count", lastCommitEpoch(dir), "--cwd", dir]).split(/\s+/)
        testEvidence = parseInt(counts[0] || "0", 10) || 0
        riskEdits = parseInt(counts[1] || "0", 10) || 0
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
            "-class) since the last commit with zero test evidence (edit ledger). Run the check-work skill (or " +
            "add/run a test touching the changed surface) before `git " +
            "commit`. Intentional override: ROLEPOD_GATES_SOFT=1 (logged to " +
            ".rolepod/evidence/bypass.log, surfaced by `make stats`).",
        )
      }
    },
  }
}
