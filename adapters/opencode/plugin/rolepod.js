/**
 * rolepod opencode plugin — best-effort session hygiene shim.
 *
 * Two entry points, one shared core (v2.157.0):
 *   - `export const RolepodPlugin` — the v1 factory (`({ directory, client })
 *     => handlers`), unchanged in behaviour, for opencode 1.x.
 *   - `export default { id, setup(ctx) }` — the v2 plugin contract
 *     (opencode 2.x runs inside a shared background service; a v1-shaped
 *     module with no `default` export fails to load there:
 *     `PluginModule.LoadError: Plugin must export a default definition`).
 *   `makeCore({ directory, homedir })` holds the state both entry points
 *   read: the edit ledger, phase-log writers, the bypass log, and the
 *   cross-CLI session-lock registry. Nothing new is enforced — the same
 *   gates are re-attached to whichever event shape the running opencode
 *   speaks.
 *
 * Scope (deliberately small — every handler fails open):
 *   1. session start → register this session in the cross-CLI lock
 *      protocol at ~/.rolepod/session-locks/<sha256(worktree)[:16]>/, the
 *      same registry rolepod's Claude / Gemini / agy hooks maintain, so
 *      sibling sessions in ANY rolepod-equipped CLI can warn about
 *      concurrent edits to the same worktree. Stale locks (>30 min) are
 *      pruned on contact; a fresh sibling triggers a toast (v1) or a
 *      one-shot system-part nudge (v2 — server plugins have no toast).
 *   2. post-compact → re-anchor nudge (manage-context §7): trust disk over
 *      summary — plan checkboxes, git log, spec.
 *   3. tool result → session evidence tracker: edit/write(/patch, v2) on a
 *      high-risk path vs a test path, via the CLI-neutral edit ledger
 *      (<worktree>/.rolepod/evidence/edits.jsonl, windowed since the last
 *      commit — the same evidence every other CLI's gate reads).
 *   4. commit attempt → precommit gate: `git commit` while high-risk paths
 *      were edited and ZERO test evidence exists → throw (opencode's
 *      documented deny mechanism, both versions). ROLEPOD_GATES_SOFT=1
 *      logs the bypass to .rolepod/evidence/bypass.log instead (same file
 *      `make stats` reads).
 *   5. fix-loop-breaker (v2.133.0) → the SHARED Claude hook script
 *      (plugins/rolepod-shared/*.sh, byte-identical to hooks/) runs behind
 *      an opencode→Claude translator: bash exit codes feed the loop
 *      breaker. The nudge it emits is appended to the tool result the
 *      model reads — v1: `output.output`; v2: a pushed text part on
 *      `result.content`, or appended when `content` is a string.
 *   6. task/subagent dispatch → the dispatch-proof phase-log line the
 *      commit-gate's reviewer-evidence reading depends on.
 *   7. route record → the assistant's routing line (R-tier + skill) is
 *      recorded into phase-log.jsonl for `make stats`. opencode keeps no
 *      transcript file: v1 reads it back via the SDK client at
 *      `session.idle`; v2 has no idle in headless runs, so the `context`
 *      hook's `messages` carry it instead — the previous turn's text is
 *      recorded at the start of the next one (one turn late by design).
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

// Shared hook core (hooks/fix-loop-breaker.sh) ships next to this file as
// plugins/rolepod-shared/; ROLEPOD_OC_SHARED overrides (tests).
const HERE = path.dirname(fileURLToPath(import.meta.url))
const SHARED = process.env.ROLEPOD_OC_SHARED || path.join(HERE, "rolepod-shared")
// opencode tool id → the Claude tool name the shared cores classify on.
// v1 ids (read/grep/glob/list/webfetch/websearch/bash/task/edit/write) plus
// the v2 renames (shell/subagent/patch) — harmless for whichever runtime
// never produces the other set.
const TOOL_MAP = {
  read: "Read", grep: "Grep", glob: "Glob", list: "Glob", webfetch: "WebFetch",
  websearch: "WebSearch", bash: "Bash", task: "Agent", edit: "Edit", write: "Write",
  shell: "Bash", subagent: "Agent", patch: "Edit",
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

// v2.134.0: edit evidence lives in the CLI-neutral ledger
// (<worktree>/.rolepod/evidence/edits.jsonl via rolepod-shared/edit-ledger.py),
// windowed since the last commit — the same evidence every other CLI's gate reads.
function ledger(args) {
  try {
    const script = path.join(SHARED, "edit-ledger.py")
    if (!fs.existsSync(script)) return ""
    const r = spawnSync("python3", ["-I", script, ...args], { encoding: "utf8", timeout: 3000, stdio: ["ignore", "pipe", "ignore"] })
    return r.status === 0 ? String(r.stdout || "").trim() : ""
  } catch { return "" }
}
function lastCommitEpoch(dir) {
  try { return execSync("git log -1 --format=%ct", { cwd: dir, stdio: ["ignore", "pipe", "ignore"] }).toString().trim() } catch { return "" }
}

const REANCHOR_MSG =
  "rolepod post-compact re-anchor: the summary is a lossy narrator, not a " +
  "state file. Before the next action: re-read the plan artifact " +
  "(checkboxes mark the real position), run `git log --oneline -5` + " +
  "`git status`, re-open the spec if the flow has one. Disk beats summary " +
  "on every conflict."

function siblingMessage(activeSiblings) {
  return (
    `rolepod: ${activeSiblings} sibling session(s) active in this ` +
    "worktree (possibly another CLI). Concurrent edits will stomp " +
    "each other — isolate with `git worktree add` before editing, or " +
    "set ROLEPOD_ALLOW_SHARED_WORKTREE=1 if intentional."
  )
}
// One rule, both entry points: warn only when siblings exist and the user
// hasn't opted into sharing the worktree.
function shouldWarnSiblings(activeSiblings) {
  return activeSiblings > 0 && process.env.ROLEPOD_ALLOW_SHARED_WORKTREE !== "1"
}

function gateMessage(riskEdits) {
  return (
    "rolepod precommit gate: this session edited " +
    `${riskEdits} high-risk path(s) (auth/billing/migration/security` +
    "-class) since the last commit with zero test evidence (edit ledger). Run the check-work skill (or " +
    "add/run a test touching the changed surface) before `git " +
    "commit`. Intentional override: ROLEPOD_GATES_SOFT=1 (logged to " +
    ".rolepod/evidence/bypass.log, surfaced by `make stats`)."
  )
}

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

function lockDirFor(worktree, homedir) {
  const hash = createHash("sha256").update(worktree).digest("hex").slice(0, 16)
  return path.join(homedir, ".rolepod", "session-locks", hash)
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

// Quote-aware whitespace split (best-effort, not a full shell grammar): a
// '...' or "..." run is one token even when it holds spaces — needed once a
// `-c` / `eval` string argument (itself a whole sub-command) must come back
// as a single token to recurse into, not fragments split on its own spaces.
// A backslash inside "..." escapes the next char (shell double-quote rules);
// inside '...' nothing is special, matching shlex(posix=True) on the Python
// side.
function qsplit(s) {
  const toks = []
  let i = 0
  const n = s.length
  while (i < n) {
    while (i < n && /\s/.test(s[i])) i++
    if (i >= n) break
    let cur = ""
    while (i < n && !/\s/.test(s[i])) {
      const c = s[i]
      if (c === "'" || c === '"') {
        const q = c
        i++
        while (i < n && s[i] !== q) {
          if (q === '"' && s[i] === "\\" && i + 1 < n) {
            cur += s[i + 1]
            i += 2
          } else {
            cur += s[i]
            i++
          }
        }
        i++ // closing quote (or end of string on an unterminated one)
      } else {
        cur += c
        i++
      }
    }
    toks.push(cur)
  }
  return toks
}

// F8b/S8 (v2.166.x) — shell-wrapped commit unwind, ported from the same
// unwind in hooks/precommit-gate.sh (tables copied from
// hooks/lib/session_state.py's PREFIX / WRAPPER_VALUE / SHELLS / DURATION).
// `uwTokenize` is a real shell-grade tokenizer (quote/escape rules, a
// literal newline as its own boundary token) — round-1's TEXT-split fix
// (splitting on &&/||/;/|/newline via a hand-rolled scanner) was itself
// wrong on an escaped quote, a comment apostrophe, a bare `&`, and
// `$(...)` (round-2 external + security-engineer review): a hand-rolled
// special case for each shell quirk keeps missing the next one. Segment
// boundaries are any token made ENTIRELY of operator characters
// (`;`, `&&`, `&`, `|`, `\n`, ...). Unbalanced quoting anywhere (top level
// or inside a recursed -c / eval string) -> that segment's raw tokens are
// kept UNTOUCHED (no drop, no recursion) — ambiguous input never
// disappears, it just isn't optimized away, so `isGitCommit`'s own
// `git`+`commit` walk still sees it. Per clean segment: skip env assigns
// and a known wrapper's own flags/duration, then a shell head (SHELLS, or
// $SHELL / ${SHELL} from the environment) with a flag cluster containing
// 'c' (-c, -lc, -ec, -xc) — found by scanning every remaining token, never
// stopping at the first non-flag one, so a value-taking option before -c
// ('bash -o pipefail -c ...') or a long option ('--noprofile') cannot hide
// it — recurses into its string; 'eval' recurses into its joined remaining
// args. depth > 4 -> a forced commit hit (fail-closed).
const UW_PREFIX = new Set([
  "time", "env", "nice", "sudo", "rtk", "proxy", "caffeinate", "command", "exec", "nohup", "timeout",
])
const UW_WRAPPER_VALUE = {
  sudo: new Set(["-u", "-g", "-C", "-p", "-h", "-r", "-t", "-U", "-D"]),
  nice: new Set(["-n"]),
  env: new Set(["-u", "-C", "-S"]),
  timeout: new Set(["-k", "-s"]),
  nohup: new Set(),
  caffeinate: new Set(["-t", "-w"]),
}
const UW_ASSIGN_RE = /^[A-Za-z_][A-Za-z0-9_]*=/
const UW_DURATION_RE = /^[0-9]+(\.[0-9]+)?[smhd]?$/
const UW_SHELLS = new Set(["bash", "sh", "zsh", "dash", "ksh"])
const UW_OUTPUT_ONLY = new Set(["echo", "printf", ":"])
const UW_OPCHARS = new Set(["(", ")", ";", "<", ">", "|", "&", "\n"])

function uwHead(tIn) {
  // basename, not t[0] itself (round-3 external review: an absolute-path
  // wrapper, '/usr/bin/env bash -c ...', evaded every PREFIX check).
  let t = tIn
  let w = ""
  while (t.length) {
    const b0 = path.basename(t[0])
    if (UW_PREFIX.has(b0)) {
      w = b0
      t = t.slice(1)
      continue
    }
    if (t[0].startsWith("-")) {
      const takesValue = UW_WRAPPER_VALUE[w] && UW_WRAPPER_VALUE[w].has(t[0]) && t.length > 1
      t = takesValue ? t.slice(2) : t.slice(1)
      continue
    }
    if (UW_DURATION_RE.test(t[0]) || UW_ASSIGN_RE.test(t[0])) {
      t = t.slice(1)
      continue
    }
    break
  }
  return t
}

function uwIsOperatorTok(tok) {
  return tok.length > 0 && [...tok].every((c) => UW_OPCHARS.has(c))
}

// Shell-grade tokenizer: '...' literal (no escapes); "..." escapes the next
// char with a backslash; OUTSIDE quotes a backslash also escapes the very
// next character (POSIX shell rule qsplit above never implemented); a run
// of UW_OPCHARS characters (including a bare newline) is its own token
// instead of vanishing as whitespace. Returns {toks, ok}; ok=false
// (unbalanced quote) means the caller must not drop or unwrap anything.
function uwTokenize(sIn) {
  // ANSI-C / locale quoting (bash dollar-single-quote / dollar-double-quote
  // strings) — this tokenizer has no concept of it, reading the leading $
  // as an ordinary character that glues onto the quote instead of opening
  // it, which hid a real commit entirely (round-3 external review). Swap
  // the dollar-quote prefix for a plain quote first — enough for OUR
  // purpose (seeing the words inside).
  const s = sIn.split("$'").join("'").split('$"').join('"')
  const toks = []
  let i = 0
  const n = s.length
  while (i < n) {
    while (i < n && (s[i] === " " || s[i] === "\t" || s[i] === "\r")) i++
    if (i >= n) break
    if (UW_OPCHARS.has(s[i])) {
      let j = i
      while (j < n && UW_OPCHARS.has(s[j])) j++
      toks.push(s.slice(i, j))
      i = j
      continue
    }
    let cur = ""
    let closed = true
    while (i < n) {
      const c = s[i]
      if (c === "'") {
        const start = i + 1
        const end = s.indexOf("'", start)
        if (end === -1) { closed = false; i = n; break }
        cur += s.slice(start, end)
        i = end + 1
        continue
      }
      if (c === '"') {
        i++
        let done = false
        while (i < n) {
          if (s[i] === '"') { i++; done = true; break }
          if (s[i] === "\\" && i + 1 < n) { cur += s[i + 1]; i += 2; continue }
          cur += s[i]; i++
        }
        if (!done) { closed = false; i = n; break }
        continue
      }
      if (c === "\\" && i + 1 < n) {
        cur += s[i + 1]
        i += 2
        continue
      }
      if (c === " " || c === "\t" || c === "\r" || UW_OPCHARS.has(c)) break
      cur += c
      i++
    }
    toks.push(cur)
    if (!closed) return { toks, ok: false }
  }
  return { toks, ok: true }
}

function uwProcess(toksIn, depth) {
  if (depth > 4) return { toks: toksIn, forced: true }
  const out = []
  let i = 0
  while (i < toksIn.length) {
    let j = i
    while (j < toksIn.length && !uwIsOperatorTok(toksIn[j])) j++
    const seg = toksIn.slice(i, j)
    const t = uwHead(seg)
    let handled = false
    let forced = false
    if (t.length) {
      let ht = t[0]
      if (ht === "$SHELL" || ht === "${SHELL}") ht = process.env.SHELL || ""
      const hbase = path.basename(ht)
      if (UW_OUTPUT_ONLY.has(hbase)) {
        // a pure-output head (echo/printf/:) never invokes what follows it —
        // drop only THIS clean segment.
        handled = true
      } else if (UW_SHELLS.has(hbase)) {
        let cflag = -1
        for (let k = 1; k < t.length; k++) {
          if (t[k].startsWith("-") && !t[k].startsWith("--") && t[k].slice(1).includes("c")) {
            cflag = k
            break
          }
        }
        if (cflag !== -1 && cflag + 1 < t.length) {
          const inner = uwTokenize(t[cflag + 1])
          if (inner.ok) {
            const r = uwProcess(inner.toks, depth + 1)
            out.push(...r.toks)
            handled = true
            if (r.forced) forced = true
          }
        }
      } else if (hbase === "eval" && t.length > 1) {
        const inner = uwTokenize(t.slice(1).join(" "))
        if (inner.ok) {
          const r = uwProcess(inner.toks, depth + 1)
          out.push(...r.toks)
          handled = true
          if (r.forced) forced = true
        }
      }
    }
    if (!handled) out.push(...seg)
    if (forced) return { toks: out, forced: true }
    if (j < toksIn.length) out.push(toksIn[j])
    i = j + 1
  }
  return { toks: out, forced: false }
}

function isGitCommit(cmd) {
  const top = uwTokenize(cmd)
  let toks
  let forced = false
  if (top.ok) {
    const r = uwProcess(top.toks, 0)
    toks = r.toks
    forced = r.forced
  } else {
    // Unbalanced quoting at the top level: unwrap is unsafe. A quote-aware
    // fallback (qsplit) can itself misparse here (an unterminated quote
    // swallows the rest of the string into one token, hiding a later
    // 'git'/'commit' pair) — a NAIVE whitespace split, ignoring quotes
    // entirely, is the safer fallback: 'git' and 'commit' stay two
    // separate words regardless of any quote confusion elsewhere in the
    // string (matches session_state.py's own last-resort `s.split()`).
    toks = cmd.split(/\s+/).filter(Boolean)
  }
  if (forced) return true
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

// The state and helpers both entry points share, bound to one plugin
// instance's project directory. Stateless helpers (ledger, runCore,
// isGitCommit, worktreeRoot, the regexes) are re-exposed here too, so a
// caller reaches for one object instead of module scope + this.
function makeCore({ directory, homedir } = {}) {
  const dir = directory || process.cwd()
  const hd = homedir || os.homedir()

  const phaseLogAppend = (line) => {
    try {
      const worktree = worktreeRoot(dir)
      if (!worktree) return
      const evDir = path.join(worktree, ".rolepod", "evidence")
      fs.mkdirSync(evDir, { recursive: true })
      fs.appendFileSync(path.join(evDir, "phase-log.jsonl"), JSON.stringify(line) + "\n")
    } catch { /* fail open */ }
  }

  const logBypass = () => {
    try {
      const worktree = worktreeRoot(dir)
      if (!worktree) return
      const evDir = path.join(worktree, ".rolepod", "evidence")
      fs.mkdirSync(evDir, { recursive: true })
      fs.appendFileSync(
        path.join(evDir, "bypass.log"),
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

  // Registers `id` in the worktree's lock dir and returns the count of
  // OTHER active (non-stale) sibling locks — the caller decides how to
  // surface that (v1: a toast; v2: a one-shot system-part nudge).
  const registerLock = (id) => {
    const worktree = worktreeRoot(dir)
    if (!worktree) return 0 // non-git dir = no stomp risk (same as bash hook)

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

    const lockDir = lockDirFor(worktree, hd)
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
    return activeSiblings
  }

  return {
    directory: dir, homedir: hd,
    ledger, lastCommitEpoch, phaseLogAppend, logBypass, registerLock,
    runCore, isGitCommit, worktreeRoot,
    RISK_RE, TEST_RE, VALUE_OPTS,
  }
}

// ── v1: opencode 1.x named export ───────────────────────────────────────
export const RolepodPlugin = async ({ directory, client }) => {
  const core = makeCore({ directory })
  let sessionId = null
  let lastPromptAt = 0 // epoch seconds of the newest user prompt (chat.message)

  // Route record: opencode keeps no transcript file, so at session.idle the plugin
  // hands the turn's assistant text to route_check.py --record-text (prompt_ts =
  // the once-per-turn guard). Messages come from the SDK client; no client → skip.
  const recordRoute = async (sessionID) => {
    try {
      if (!client?.session?.messages || !lastPromptAt) return
      const script = path.join(SHARED, "route_check.py")
      if (!fs.existsSync(script)) return
      const res = await client.session.messages({ path: { id: sessionID } })
      const msgs = Array.isArray(res) ? res : (res?.data ?? [])
      let lastUser = -1
      msgs.forEach((m, i) => { if (m?.info?.role === "user") lastUser = i })
      if (lastUser < 0) return
      const text = msgs.slice(lastUser + 1)
        .filter((m) => m?.info?.role === "assistant")
        .flatMap((m) => (m.parts || []).filter((p) => p?.type === "text").map((p) => String(p.text || "")))
        .join("\n")
      if (!text) return
      spawnSync("python3", ["-I", script, "--record-text"], {
        input: JSON.stringify({ assistant_text: text, prompt_ts: lastPromptAt }),
        cwd: core.worktreeRoot(directory || process.cwd()) || (directory || process.cwd()),
        encoding: "utf8", timeout: 3000, stdio: ["pipe", "ignore", "ignore"],
      })
    } catch { /* fail open */ }
  }

  const toast = (message) => {
    try {
      client?.tui?.showToast?.({ body: { message, variant: "warning" } })
    } catch {
      /* headless / older client — the lock itself still protects siblings */
    }
  }

  const registerLockAndWarn = (id) => {
    const activeSiblings = core.registerLock(id)
    if (shouldWarnSiblings(activeSiblings)) toast(siblingMessage(activeSiblings))
  }

  return {
    event: async ({ event }) => {
      try {
        if (event?.type === "session.created") {
          // The first session this process sees is the Lead's; a task subagent
          // creates a child session later and must not become "the session"
          // (measured live 2026-09-16: the child's id shadowed the parent's and
          // the parent's session.idle never matched, so no route was recorded).
          if (!sessionId) {
            sessionId =
              event?.properties?.info?.id ?? `opencode-${process.pid}-${Date.now()}`
            registerLockAndWarn(sessionId)
          }
        } else if (event?.type === "session.compacted") {
          toast(REANCHOR_MSG)
        } else if (event?.type === "session.idle") {
          const sid = event?.properties?.sessionID
          if (sid && sid === sessionId) await recordRoute(sid)
        }
      } catch {
        /* fail open — hygiene must never break the session */
      }
    },

    "chat.message": async (input, output) => {
      try {
        // New user prompt = new turn (route recording keys off this).
        lastPromptAt = Math.floor(Date.now() / 1000)
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
          if (fp) core.ledger(["append", "opencode", fp, "--cwd", directory || process.cwd()])
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
          if (tool === "task") {
            // Reviewer dispatch evidence for the commit gate (same line Codex / Cursor write).
            const agent = String(args?.subagent_type ?? "")
            if (agent) core.phaseLogAppend({ ts: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"), phase: "dispatch-proof", cli: "opencode", agent_type: agent, model: "", provenance: "hook-stdin" })
          }
          if (tool === "bash") {
            const exit = output?.metadata?.exit
            const m = core.runCore("fix-loop-breaker", {
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
      try {
        if (String(input?.tool ?? "") !== "bash") return
        const cmd = String(output?.args?.command ?? "")
        if (!core.isGitCommit(cmd)) return
        const dir = directory || process.cwd()
        const counts = core.ledger(["count", core.lastCommitEpoch(dir), "--cwd", dir]).split(/\s+/)
        const testEvidence = parseInt(counts[0] || "0", 10) || 0
        riskEdits = parseInt(counts[1] || "0", 10) || 0
        if (riskEdits > 0 && testEvidence === 0) {
          if (process.env.ROLEPOD_GATES_SOFT === "1") core.logBypass()
          else block = true
        }
      } catch {
        /* fail open — unknown payload shape must never block */
      }
      if (block) throw new Error(gateMessage(riskEdits))
    },
  }
}

// The text a shared core reads from / a nudge is appended to, from a v2
// Tool.Result: content when it's already a string, else its text parts
// joined, else the (rarer) structured `output`. Always a string.
function resultText(result) {
  if (typeof result?.content === "string") return result.content
  if (Array.isArray(result?.content)) {
    return result.content.filter((p) => p?.type === "text").map((p) => String(p.text || "")).join("\n")
  }
  return String(result?.output ?? "")
}

// Pushes a nudge where the model actually reads it. `content` array → a new
// text part; `content` string → appended; neither shape → skipped rather
// than inventing one (fail open).
function pushNote(result, note) {
  if (Array.isArray(result?.content)) result.content.push({ type: "text", text: note })
  else if (typeof result?.content === "string") result.content = result.content + "\n\n" + note
}

// Route record (v2): the previous turn's assistant text sits between the
// second-to-last and the last user message — recorded one turn late,
// at the start of the next turn's `context` call (opencode keeps no
// transcript file; @opencode/ai's exact Message shape isn't in the
// scratchpad types, so this stays defensive: string content or text parts).
function messageText(m) {
  const c = m?.content
  if (typeof c === "string") return c ? [c] : []
  if (Array.isArray(c)) return c.filter((p) => p?.type === "text").map((p) => String(p.text || ""))
  return []
}
function extractRouteText(messages) {
  const msgs = Array.isArray(messages) ? messages : []
  const userIdx = []
  msgs.forEach((m, i) => { if (m?.role === "user") userIdx.push(i) })
  // This port's own probe against the live opencode 2.0.12 binary
  // (2026-09-22) measured `e.messages` on the FIRST `context` call of a
  // turn already ending with that turn's new user prompt, so "the last
  // user message" below is the new prompt, not the one that opened the
  // turn being recorded. Fewer than two user turns (the session's first
  // prompt) -> nothing to record yet, not a malformed payload.
  if (userIdx.length < 2) return ""
  const start = userIdx[userIdx.length - 2]
  const end = userIdx[userIdx.length - 1]
  return msgs.slice(start + 1, end)
    .filter((m) => m?.role === "assistant")
    .flatMap((m) => messageText(m))
    .join("\n")
}

// ── v2: opencode 2.x default export (Plugin.define is the identity —
// no import needed, the file stays dependency-free) ─────────────────────
export default {
  id: "rolepod",
  async setup(ctx) {
    // Plugins run inside the SHARED daemon: its working directory is $HOME,
    // one instance per project — the directory must come from ctx.location.
    const directory = ctx.location?.directory ?? ctx.location?.project?.directory
    if (!directory) {
      console.error("rolepod: no location.directory on this plugin instance — hooks not registered")
      return
    }
    const core = makeCore({ directory })

    // sessions: sessionID -> { child } for sessions this instance has seen
    // via the (global) event stream and knows belong to this project —
    // see "Event scope" in the migration handoff: the instance may miss
    // its own first session.created, so the prompt/tool hooks (scoped to
    // this instance already) are the reliable source of "is this ours".
    const sessions = new Map()
    const lockedSessions = new Set()
    const pendingSibling = new Map() // sessionID -> activeSiblings count
    const pendingReanchor = new Set()
    const pendingRoute = new Set()
    const lastPromptAt = new Map()

    const isChild = (sid) => sessions.get(sid)?.child === true

    const recordRouteV2 = (sid, messages) => {
      try {
        const script = path.join(SHARED, "route_check.py")
        if (!fs.existsSync(script)) return
        const ts = lastPromptAt.get(sid)
        if (!ts) return
        const text = extractRouteText(messages)
        if (!text) return
        spawnSync("python3", ["-I", script, "--record-text"], {
          input: JSON.stringify({ assistant_text: text, prompt_ts: ts }),
          cwd: core.worktreeRoot(directory) || directory,
          encoding: "utf8", timeout: 3000, stdio: ["pipe", "ignore", "ignore"],
        })
      } catch { /* fail open */ }
    }

    // Each registration is its own try/catch: one hook opencode refuses
    // (a future signature change, a typo'd name) must not stop the rest
    // from registering, and must not fail setup() itself.
    try {
      await ctx.session.hook("prompt", (e) => {
        try {
          const sid = String(e?.sessionID ?? "")
          if (!sid) return
          lastPromptAt.set(sid, Math.floor(Date.now() / 1000))
          // A subagent's session never locks or routes. `isChild` depends on
          // the (async, global) event stream having already delivered this
          // session's `session.created` — a child's very first prompt can in
          // principle race ahead of it and be treated as a lead session once;
          // accepted, same "may miss its own first event" limitation the
          // migration handoff documents for the Lead's own session. Also
          // seeds `sessions` for a session the event stream never announced
          // (e.g. it predates a `service restart`): this hook is reliably
          // instance-scoped, so by the time it has fired once, later
          // event-stream lookups (re-anchor arming) can trust `sessions`
          // instead of needing another, unmeasured way to tell "is this
          // ours" from the event alone.
          if (isChild(sid)) return
          if (!sessions.has(sid)) sessions.set(sid, { child: false })
          if (!lockedSessions.has(sid)) {
            lockedSessions.add(sid)
            const activeSiblings = core.registerLock(sid)
            if (shouldWarnSiblings(activeSiblings)) pendingSibling.set(sid, activeSiblings)
          }
          pendingRoute.add(sid)
        } catch { /* fail open */ }
      })
    } catch (error) {
      console.error("rolepod: prompt hook not registered:", error)
    }

    try {
      await ctx.tool.hook("execute.before", (e) => {
        let block = false
        let riskEdits = 0
        try {
          const tool = String(e?.tool ?? "")
          if (tool !== "shell" && tool !== "bash") return
          const cmd = String(e?.input?.command ?? "")
          if (!core.isGitCommit(cmd)) return
          const counts = core.ledger(["count", core.lastCommitEpoch(directory), "--cwd", directory]).split(/\s+/)
          const testEvidence = parseInt(counts[0] || "0", 10) || 0
          riskEdits = parseInt(counts[1] || "0", 10) || 0
          if (riskEdits > 0 && testEvidence === 0) {
            if (process.env.ROLEPOD_GATES_SOFT === "1") core.logBypass()
            else block = true
          }
        } catch {
          /* fail open — unknown payload shape must never block */
        }
        if (block) throw new Error(gateMessage(riskEdits))
      })
    } catch (error) {
      console.error("rolepod: execute.before hook not registered:", error)
    }

    try {
      await ctx.tool.hook("execute.after", (e) => {
        try {
          if (e?.status !== "completed") return
          const tool = String(e?.tool ?? "")
          const input = e?.input ?? {}
          const sid = String(e?.sessionID ?? "")
          const result = e?.result

          if (tool === "edit" || tool === "write" || tool === "patch") {
            const fp = String(input?.path ?? input?.filePath ?? input?.file_path ?? "")
            if (fp) core.ledger(["append", "opencode", fp, "--cwd", directory])
          }

          const claudeTool = TOOL_MAP[tool]
          if (!sid || !claudeTool || !result) return
          const text = resultText(result)

          const notes = []
          if (tool === "subagent") {
            // Reviewer dispatch evidence for the commit gate (same line Codex / Cursor write).
            const agent = String(input?.agent ?? "")
            if (agent) core.phaseLogAppend({ ts: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"), phase: "dispatch-proof", cli: "opencode", agent_type: agent, model: "", provenance: "hook-stdin" })
          }
          if (tool === "shell") {
            const exit = result?.metadata?.exit
            const m = core.runCore("fix-loop-breaker", {
              hook_event_name: "PostToolUse", session_id: sid, tool_name: "Bash",
              tool_input: { command: String(input?.command ?? "") },
              tool_response: { stdout: text, exit_code: typeof exit === "number" ? exit : undefined },
            })
            if (m) notes.push(m)
          }
          if (notes.length) pushNote(result, notes.join("\n\n"))
        } catch {
          /* fail open */
        }
      })
    } catch (error) {
      console.error("rolepod: execute.after hook not registered:", error)
    }

    try {
      await ctx.session.hook("context", (e) => {
        try {
          const sid = String(e?.sessionID ?? "")
          if (!sid || !Array.isArray(e?.system)) return
          if (pendingSibling.has(sid)) {
            const n = pendingSibling.get(sid)
            pendingSibling.delete(sid)
            e.system.push({ type: "text", text: siblingMessage(n) })
          }
          if (pendingReanchor.has(sid)) {
            pendingReanchor.delete(sid)
            e.system.push({ type: "text", text: REANCHOR_MSG })
          }
          if (pendingRoute.has(sid)) {
            pendingRoute.delete(sid)
            recordRouteV2(sid, e?.messages)
          }
        } catch { /* fail open */ }
      })
    } catch (error) {
      console.error("rolepod: context hook not registered:", error)
    }

    // Global event stream (every project, every session) — used only for
    // session lifecycle bookkeeping the scoped hooks above can't see:
    // which sessionIDs are ours, which are subagent children, and when a
    // session compacts or is deleted. Copies rolepod-brain's shape.
    const controller = new AbortController()
    void (async () => {
      try {
        for await (const ev of ctx.event.subscribe({ signal: controller.signal })) {
          try {
            const data = ev?.data ?? {}
            const sid = data.sessionID ?? null
            if (ev?.type === "session.created") {
              const ours = data.location?.directory === directory || sessions.has(data.parentID)
              if (!ours) continue
              sessions.set(sid, { child: Boolean(data.parentID) })
            } else if (ev?.type === "session.compaction.ended") {
              // `sessions` is seeded either here (session.created) or by the
              // prompt hook the first time this sessionID prompts (measured
              // instance-scoped, unlike this global stream) — so an unknown
              // sid here is genuinely not ours, never a session we merely
              // haven't heard from yet.
              const known = sessions.get(sid)
              if (known && !known.child) pendingReanchor.add(sid)
            } else if (ev?.type === "session.deleted") {
              sessions.delete(sid)
              lockedSessions.delete(sid)
              pendingSibling.delete(sid)
              pendingReanchor.delete(sid)
              pendingRoute.delete(sid)
              lastPromptAt.delete(sid)
            }
            // every event for an unknown sessionID (another project's
            // stream) is ignored — the subscription is global.
          } catch {
            /* fail open — hygiene must never break the session */
          }
        }
      } catch (error) {
        // The stream ends with the service; a stream that dies before it
        // is the one failure worth a log line, because from here on
        // session boundaries (child detection, re-anchor arming) are lost.
        if (!controller.signal.aborted) console.error("rolepod: event stream ended:", error)
      }
    })()

    return () => controller.abort()
  },
}
