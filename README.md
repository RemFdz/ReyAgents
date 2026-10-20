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

The orchestrator is the `rey` skill: it runs in your session, saves every deliverable to `.rey/<slug>/` and re-runs the tests itself instead of taking the agents' word for it.

## Installation

On any machine where Claude Code and `gh` are logged in to GitHub:

```bash
gh api repos/RemFdz/ReyAgents/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

Or from a clone of the repo: `./install.sh`. The script is safe to re-run: it installs the first time, then updates.

Since the repo is private, you need a GitHub SSH key or `gh auth login`.

### Evolving the agents

Edit the files in `agents/` or `skills/`, commit, push, then re-run the script on each machine to get the new version. Bump `version` in `.claude-plugin/plugin.json` on every change: that is what triggers the update.

Add `.rey/` to your projects' `.gitignore`.

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
