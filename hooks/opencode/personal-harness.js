import { existsSync, readFileSync } from "node:fs"
import { dirname } from "node:path"
import { spawnSync } from "node:child_process"

const COMPLETION_PROMPT = /(끝났어|끝났다|마무리하|마무리할|wrap.?up|all done|ship it|이제 끝|모두 완료|finished up|\/request-merge|PR[\s]*(만들|올리|생성|요청|올려)|MR[\s]*(만들|올리|생성|요청|올려)|(pull|merge)[\s]?request)/i
const RECURSIVE_GREP = /(^|[^a-zA-Z])grep\s+(-[a-zA-Z]*[rR][a-zA-Z]*|--include|--exclude|--exclude-dir)/
const FIND_FILE_SEARCH = /(^|[^a-zA-Z])find\s+[^|;&]*\s(-iname|-name|-ipath|-path|-iregex|-regex)(\s|=|$)/
const GIT_WRITE = /(^|[^a-zA-Z])git\s+(commit|push)/

function commandFromArgs(args) {
  return String(args?.command ?? args?.cmd ?? "")
}

function cwdFromArgs(args, fallback) {
  const cwd = args?.cwd ?? args?.directory
  if (typeof cwd === "string" && cwd.length > 0) return cwd
  const file = args?.filePath ?? args?.path
  if (typeof file === "string" && file.length > 0) return dirname(file)
  return fallback
}

function run(command, args, cwd) {
  return spawnSync(command, args, { cwd, encoding: "utf8" })
}

function runText(command, args, cwd) {
  const result = run(command, args, cwd)
  return (result.stdout ?? "").trim()
}

function isGitRepo(cwd) {
  return run("git", ["-C", cwd, "rev-parse", "--git-dir"], cwd).status === 0
}

function block(message) {
  throw new Error(message)
}

function guardSearchCommands(command) {
  if (RECURSIVE_GREP.test(command)) {
    block(`Use rg (ripgrep) instead of recursive grep for code search.

Why: rg is faster, respects .gitignore by default, and is the project convention.

Translation hints:
  grep -r "pattern" .                     ->  rg "pattern"
  grep -rn "pattern" src/                 ->  rg "pattern" src/
  grep -ri "pattern" .                    ->  rg -i "pattern"
  grep -r --include="*.ts" "p" .          ->  rg -t ts "p"
  grep -r --exclude-dir=node_modules ...  ->  rg "p"`)
  }

  if (FIND_FILE_SEARCH.test(command)) {
    block(`Use fd instead of find for file/code search.

Why: fd is faster, respects .gitignore by default, and is the project convention.

Translation hints:
  find . -name "*.ts"                  ->  fd -e ts
  find . -iname "readme*"              ->  fd -i readme
  find . -path "*/src/*" -name "*.go"  ->  fd -e go . src
  find . -type f -name "*.go"          ->  fd -e go -t f
  find . -type d -name "node_modules"  ->  fd -t d node_modules`)
  }
}

function guardGitIdentity(command, cwd, gitIdentity) {
  if (!GIT_WRITE.test(command) || !isGitRepo(cwd)) return

  const remote = runText("git", ["-C", cwd, "remote", "get-url", "origin"], cwd)
  const personal = gitIdentity?.personal ?? {}
  const work = gitIdentity?.work ?? {}
  const workHost = work.gitlabHost ?? ""
  const isWork = workHost.length > 0 && remote.includes(workHost)
  const expectedEmail = isWork ? work.email : personal.email
  const expectedName = isWork ? work.name : personal.name
  const identityType = isWork ? "work" : "personal"

  if (!expectedEmail) return

  const actualEmail = runText("git", ["-C", cwd, "config", "user.email"], cwd)
  if (actualEmail !== expectedEmail) {
    block(`Git identity mismatch - blocking commit/push.
  Repo type:   ${identityType}
  Remote URL:  ${remote || "<none>"}
  Expected:    ${expectedEmail}
  Actual:      ${actualEmail || "<unset>"}

Fix with:
  git -C "${cwd}" config user.email "${expectedEmail}"
  git -C "${cwd}" config user.name  "${expectedName ?? ""}"`)
  }
}

function findMakeDir(start) {
  let dir = start
  while (dir && dir !== "/") {
    if (existsSync(`${dir}/Makefile`)) return dir
    dir = dirname(dir)
  }
  return null
}

function makeTarget(makeDir) {
  const body = readFileSync(`${makeDir}/Makefile`, "utf8")
  if (/^fmt\s*:/m.test(body)) return "fmt"
  if (/^format\s*:/m.test(body)) return "format"
  return null
}

function runAutoFormat(cwd) {
  const makeDir = findMakeDir(cwd)
  if (!makeDir) return

  const target = makeTarget(makeDir)
  if (!target) return

  const result = run("make", ["-C", makeDir, target], makeDir)
  if (result.status !== 0) {
    const lines = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim().split("\n").slice(-20).join("\n")
    block(`[auto-format] make ${target} failed:\n${lines}`)
  }
}

function messageText(output) {
  const parts = Array.isArray(output.parts) ? output.parts : []
  return parts
    .filter((part) => part && part.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n")
}

function changedFiles(cwd) {
  if (!isGitRepo(cwd)) return []

  const upstream = ["@{u}", "origin/main", "origin/master"].find((ref) => {
    return run("git", ["-C", cwd, "rev-parse", "--verify", "--quiet", ref], cwd).status === 0
  })

  const uncommitted = runText("git", ["-C", cwd, "diff", "--name-only", "HEAD"], cwd).split("\n")
  const committed = upstream
    ? runText("git", ["-C", cwd, "diff", "--name-only", `${upstream}...HEAD`], cwd).split("\n")
    : []

  return [...new Set([...uncommitted, ...committed].map((x) => x.trim()).filter(Boolean))].sort()
}

function maybeInjectDocDriftReminder(cwd, output) {
  const prompt = messageText(output)
  if (!COMPLETION_PROMPT.test(prompt)) return

  const changed = changedFiles(cwd)
  if (changed.length === 0) return

  const docsChanged = changed.some((file) => /(^|\/)(README|AGENTS|CLAUDE)\.md$/i.test(file))
  const srcChanged = changed.filter((file) => !/(^|\/)(README|AGENTS|CLAUDE)\.md$/i.test(file) && !file.startsWith("docs/"))
  if (srcChanged.length === 0 || docsChanged) return

  output.parts.push({
    type: "text",
    text: `Doc-drift check: source files changed but README.md / AGENTS.md / legacy CLAUDE.md were NOT updated. Per global rule, verify whether these need syncing before wrapping up. Changed source files (truncated):\n${srcChanged.slice(0, 10).join("\n")}`,
  })
}

export const PersonalHarness = async ({ directory, worktree }, options = {}) => {
  const fallbackCwd = worktree || directory
  const gitIdentity = options.gitIdentity ?? {}

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const command = commandFromArgs(output.args)
      const cwd = cwdFromArgs(output.args, fallbackCwd)
      guardSearchCommands(command)
      guardGitIdentity(command, cwd, gitIdentity)
    },

    "tool.execute.after": async (input) => {
      if (!["edit", "write", "apply_patch"].includes(input.tool)) return
      const cwd = cwdFromArgs(input.args, fallbackCwd)
      runAutoFormat(cwd)
    },

    "chat.message": async (_input, output) => {
      maybeInjectDocDriftReminder(fallbackCwd, output)
    },
  }
}

export default PersonalHarness
