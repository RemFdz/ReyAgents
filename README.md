# ReyAgents

A Claude Code plugin that runs a development task through a chain of specialized agents.

```
/rey-agents:rey <task>

 researcher ─▶ planner ─▶ architect ─▶ dev-<stack> ─▶ refactorer ─▶ reviewer ┐
 (web/Perplexity) (CLAUDE.md) (YAGNI/KISS)  (code + tests)  (readability) security ┘─▶ fixes (2 rounds max)
```

| Agent | Role | Edits code |
|---|---|---|
| `researcher` | Sourced best practices for the task and the project's versions | no |
| `planner` | Short plan that follows `CLAUDE.md` | no |
| `architect` | Critiques the plan (YAGNI, KISS, separation of concerns) | no |
| `dev-<stack>` | Minimal working code, tests first | yes |
| `refactorer` | Human readability, without touching tests or behaviour | yes |
| `reviewer` | Correctness, plan conformance, tests | no |
| `security` | Audit of exploitable vulnerabilities + available scanners | no |
| `agent-forge` | Creates `dev-<stack>` when it doesn't exist | one agent file |
| `splitter` | Splits a branch / MR diff into an ordered stack of atomic slices | no |

The orchestrator is the `rey` skill: it runs in your session, saves every deliverable to `.rey/<slug>/` and re-runs the tests itself instead of taking the agents' word for it.

## Reviewing a PR, an MR, a branch or a local diff

```
/rey-agents:review [#number | !iid | MR or PR url | branch]

 isolated checkout ─▶ reviewer + security + refactorer (report-only) ─▶ checks ─▶ findings verified ─▶ report.md
```

Read-only: the agents and the project's gates run in a throwaway worktree, so your branch and uncommitted files are not touched, and the skill edits, commits, pushes and posts nothing. The orchestrator reads the code behind each serious finding before reporting it, and lists what it dropped and what nothing covered. Reports stay in `.rey/review-<slug>/`.

## Splitting an MR into stacked MRs (GitLab) or PRs (GitHub)

```
/rey-agents:atomic [branch | !iid | #number | MR or PR url]

 splitter ─▶ plan.md ─▶ you validate ─▶ per slice: branch ─▶ dev-<stack> (only if hunks/adaptations) ─▶ check ─▶ commit ─▶ push ─▶ glab mr create / gh pr create
```

The plan is an Obsidian note in `$ATOMIC_VAULT_DIR` (default `~/Documents/obsi-brain/Atomic/`) with `statut`, `avancement` and a journal; the `Atomic.base` dashboard lists them all. Edit the note or set `statut: validé` in Obsidian, then re-run `/atomic` on the same branch: it resumes from the note. Each MR targets the previous slice's branch, and the last branch must end up identical to the source branch. Whole-file slices are applied with `git checkout` by the orchestrator, without spending a dev agent. Requires `glab` logged in and a clean working tree.

## Token budget

Every agent ends with a `Budget` section (targeted reads, narrow commands, deliverable-only final message). Planner, architect, refactorer and dev agents run at `effort: medium`; reviewer, security and splitter keep `high` because they are the quality gates.

## Installation

On any machine where Claude Code and `gh` are logged in to GitHub:

```bash
gh api repos/RemFdz/ReyAgents/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

Or from a clone of the repo: `./install.sh`. The script is safe to re-run: it installs the first time, then updates.

It installs, or updates on a re-run:

- the `rey-agents` plugin and the `perplexity` MCP server (below);
- [ponytail](https://github.com/DietrichGebert/ponytail), as a Claude Code plugin: its hooks turn it on in every session (say "stop ponytail" to turn it off for a session);
- [graphify](https://github.com/Graphify-Labs/graphify): the CLI with `uv tool install graphifyy` (needs [uv](https://docs.astral.sh/uv/)), then its `/graphify` skill with `graphify install --platform claude`.

Skip a third-party tool with `REY_SKIP_PONYTAIL=1` or `REY_SKIP_GRAPHIFY=1`, e.g. `REY_SKIP_GRAPHIFY=1 ./install.sh`.

Since the repo is private, you need a GitHub SSH key or `gh auth login`.

### Evolving the agents

Edit the files in `agents/` or `skills/`, commit, push, then re-run the script on each machine to get the new version. Bump `version` in `.claude-plugin/plugin.json` on every change: that is what triggers the update.

Add `.rey/` to your projects' `.gitignore`.

### Third-party skills

`third_party/skills/` holds reference copies of the ponytail and graphify skills, with their licenses (ponytail: MIT; graphify: Apache-2.0, with its NOTICE) and a `SOURCE.md` giving the version copied. The plugin does not load them: they would show up twice next to the real tools, and they do not work alone (ponytail is always on through its hooks, graphify needs its CLI). `install.sh` installs the real tools.

To make graphify the default way to explore a repo, build its graph once in that repo, then add its Claude Code hook there:

```bash
graphify update .                  # code graph, local, no LLM
graphify claude install --project  # hook that points Claude to the graph before it searches files
```

The second command edits the repo's `CLAUDE.md` and writes `.claude/settings.json`, `.claude/CLAUDE.md` and `.claude/skills/graphify/`; the graph itself lands in `graphify-out/` (hundreds of MB on a large repo). To keep it personal in a team repo, without touching tracked files:

```bash
git diff CLAUDE.md | sed -n '/^+## graphify/,$p' | sed 's/^+//' > CLAUDE.local.md && git checkout -- CLAUDE.md
mv .claude/settings.json .claude/settings.local.json   # if .claude/settings.local.json is gitignored
rm -rf .claude/skills/graphify .claude/CLAUDE.md       # the skill is already installed globally
printf 'graphify-out/\nCLAUDE.local.md\n' >> "$(git rev-parse --git-common-dir)/info/exclude"
```

### Perplexity

The script also adds the `perplexity` MCP server (user scope). Two options:

- **OAuth** (default): after installing, run `/mcp` in Claude Code, pick `perplexity` and sign in.
- **API key**: export the key before running the script, e.g. `PERPLEXITY_API_KEY=pplx-… ./install.sh`.

Keep the server name `perplexity`: the agents reference `mcp__perplexity__*`. Without it, they fall back to the built-in web search.

## Per-stack dev agents

Only `dev-svelte` (Svelte 5 runes + SvelteKit) ships with the plugin. For another stack, the orchestrator runs `agent-forge`, which writes `.claude/agents/dev-<stack>.md` in your project, modelled on `dev-svelte`. Review it and commit it.

A `dev-<stack>` agent in the project's `.claude/agents/` or in `~/.claude/agents/` takes precedence over the plugin's: that's how you override it.

Every dev agent must keep its `Stack rules` and `Security pitfalls` sections: the reviewer and the security agent read them.

## Design choices

- **Least privilege**: only `dev-<stack>` and `refactorer` edit files. The others return their deliverable and the orchestrator saves it. No subagent can launch other agents.
- **Refactoring can't break things**: the orchestrator takes a snapshot first, checks the test file hashes and that everything passes, otherwise it restores the developer's version.
- **Web content is data**: agents that read the web are told never to follow instructions found in pages.
- Agent prompts are in English, which uses fewer tokens and is followed more reliably; the orchestrator answers in your language.

## Limitations

- An agent created in a `.claude/agents/` folder that didn't exist at startup is only loaded after a restart; until then the orchestrator runs it through `general-purpose`.
- Without a git repository, the refactor snapshot and the diff review aren't reliable.
