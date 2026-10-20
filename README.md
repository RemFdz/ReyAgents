# ReyAgents

Plugin Claude Code qui fait passer une tâche de dev par une chaîne d'agents spécialisés.

```
/rey-agents:rey <tâche>

 researcher ─▶ planner ─▶ architect ─▶ dev-<stack> ─▶ refactorer ─▶ reviewer ┐
 (web/Perplexity) (CLAUDE.md) (YAGNI/KISS)  (code + tests)  (lisibilité)  security ┘─▶ corrections (2 tours max)
```

| Agent | Rôle | Modifie le code |
|---|---|---|
| `researcher` | Bonnes pratiques sourcées pour la tâche et les versions du projet | non |
| `planner` | Plan court qui respecte `CLAUDE.md` | non |
| `architect` | Critique le plan (YAGNI, KISS, séparation des responsabilités) | non |
| `dev-<stack>` | Code minimal qui marche, tests d'abord | oui |
| `refactorer` | Lisibilité humaine, sans toucher aux tests ni au comportement | oui |
| `reviewer` | Correction, conformité au plan, tests | non |
| `security` | Audit des failles exploitables + scanners disponibles | non |
| `agent-forge` | Crée `dev-<stack>` quand il n'existe pas | un fichier agent |

L'orchestrateur est le skill `rey` : il tourne dans ta session, sauvegarde chaque livrable dans `.rey/<slug>/` et relance lui-même les tests au lieu de croire les agents sur parole.

## Installation

Sur n'importe quel ordi où Claude Code et `gh` sont connectés à GitHub :

```bash
gh api repos/RemFdz/ReyAgents/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

Ou depuis un clone du repo : `./install.sh`. Le script est relançable : il installe la première fois, puis met à jour.

Le repo étant privé, il faut une clé SSH GitHub ou `gh auth login`.

### Faire évoluer les agents

Modifie les fichiers dans `agents/` ou `skills/`, commite, pousse, puis relance le script sur chaque ordi pour récupérer la nouvelle version. Pense à incrémenter `version` dans `.claude-plugin/plugin.json` à chaque changement : c'est elle qui déclenche la mise à jour.

Ajoute `.rey/` au `.gitignore` de tes projets.

### Perplexity (optionnel)

```bash
claude mcp add --transport http perplexity https://api.perplexity.ai/mcp
```

Garde le nom de serveur `perplexity` : les agents référencent `mcp__perplexity__*`. Sans lui, ils utilisent la recherche web intégrée.

## Agents dev par stack

Seul `dev-svelte` (Svelte 5 en runes + SvelteKit) est fourni. Pour une autre stack, l'orchestrateur lance `agent-forge`, qui écrit `.claude/agents/dev-<stack>.md` dans ton projet sur le modèle de `dev-svelte`. Relis-le et commite-le.

Un agent `dev-<stack>` dans `.claude/agents/` du projet ou dans `~/.claude/agents/` est prioritaire sur celui du plugin : c'est comme ça qu'on surcharge.

Chaque agent dev doit garder les sections `Stack rules` et `Security pitfalls` : le reviewer et l'agent sécurité les lisent.

## Choix de conception

- **Moindre privilège** : seuls `dev-<stack>` et `refactorer` modifient des fichiers. Les autres renvoient leur livrable et l'orchestrateur l'enregistre. Aucun sous-agent ne peut lancer d'autres agents.
- **Le refacto ne peut pas casser** : l'orchestrateur prend un instantané avant, vérifie l'empreinte des tests et que tout passe, sinon il restaure la version du dev.
- **Contenu web = données** : les agents qui lisent le web ont pour consigne de ne jamais suivre d'instructions trouvées dans les pages.
- Les prompts des agents sont en anglais, plus économe en tokens et suivi de façon plus fiable ; l'orchestrateur te répond dans ta langue.

## Limites

- Un agent créé dans un dossier `.claude/agents/` qui n'existait pas au démarrage n'est chargé qu'après redémarrage ; l'orchestrateur l'exécute via `general-purpose` en attendant.
- Sans repo git, le snapshot du refacto et la revue du diff ne sont pas fiables.
