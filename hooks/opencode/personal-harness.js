import { existsSync, readFileSync } from "node:fs"
import { dirname } from "node:path"
import { spawnSync } from "node:child_process"

const RECURSIVE_GREP = /(^|[^a-zA-Z])grep\s+(-[a-zA-Z]*[rR][a-zA-Z]*|--include|--exclude|--exclude-dir)/
const FIND_FILE_SEARCH = /(^|[^a-zA-Z])find\s+[^|;&]*\s(-iname|-name|-ipath|-path|-iregex|-regex)(\s|=|$)/
const GIT_WRITE = /(^|[^a-zA-Z])git\s+(commit|push)/

const announced = new Set()

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

function identityConfig(gitIdentity) {
  return {
    personal: {
      email: gitIdentity?.personal?.email ?? process.env.PERSONAL_GIT_EMAIL ?? "",
      name: gitIdentity?.personal?.name ?? process.env.PERSONAL_GIT_NAME ?? "",
    },
    work: {
      email: gitIdentity?.work?.email ?? process.env.WORK_GIT_EMAIL ?? "",
      name: gitIdentity?.work?.name ?? process.env.WORK_GIT_NAME ?? "",
      gitlabHost: gitIdentity?.work?.gitlabHost ?? process.env.WORK_GITLAB_HOST ?? "",
    },
  }
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
  const { personal, work } = identityConfig(gitIdentity)
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

function sessionIDFromEvent(event) {
  const props = event?.properties ?? {}
  return props.sessionID ?? props.sessionId ?? props.id ?? props.session?.id
}

function repoContext(cwd, gitIdentity) {
  const { personal, work } = identityConfig(gitIdentity)
  let remote = ""
  let branch = ""
  let actualEmail = ""
  if (cwd && isGitRepo(cwd)) {
    remote = runText("git", ["-C", cwd, "remote", "get-url", "origin"], cwd)
    branch = runText("git", ["-C", cwd, "branch", "--show-current"], cwd)
    actualEmail = runText("git", ["-C", cwd, "config", "user.email"], cwd)
  }

  const workHost = work.gitlabHost ?? ""
  const isWork = workHost.length > 0 && remote.includes(workHost)
  const repoType = isWork ? "work" : "personal"
  let classificationRule = "origin remote did not match WORK_GITLAB_HOST"
  if (isWork) {
    classificationRule = "origin remote matched WORK_GITLAB_HOST"
  } else if (!remote) {
    classificationRule = "no origin remote; defaulted to personal"
  } else if (!workHost) {
    classificationRule = "WORK_GITLAB_HOST unset; defaulted to personal"
  }

  const identity = isWork ? work : personal

  return `Session repository classification:
- repo_type: ${repoType}
- cwd: ${cwd || "<unknown>"}
- origin: ${remote || "<none>"}
- branch: ${branch || "<none>"}
- classification_rule: ${classificationRule}
- expected_commit_identity: ${identity.name || "<unset>"} <${identity.email || "<unset>"}>
- current_git_email: ${actualEmail || "<unset>"}

Use repo_type as session-scoped context. If you have not already done so, mention once to the user near the start of the session that this repository was detected as ${repoType}. When committing or using commit-code, follow the ${repoType} path: verify git user.name and user.email against the expected ${repoType} identity, extract a Jira key from the branch only for work repositories, and do not push unless the user explicitly asks.`
}

async function announceSessionContext(client, cwd, gitIdentity, sessionID) {
  if (!client || !sessionID || announced.has(sessionID)) return
  announced.add(sessionID)

  await client.session.prompt({
    path: { id: sessionID },
    body: { parts: [{ type: "text", text: repoContext(cwd, gitIdentity) }] },
  })
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



export const PersonalHarness = async ({ directory, worktree, client }, options = {}) => {
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

    event: async ({ event }) => {
      if (event.type === "session.created") {
        await announceSessionContext(client, fallbackCwd, gitIdentity, sessionIDFromEvent(event))
      }
    },
  }
}

export default PersonalHarness
