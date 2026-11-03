#!/usr/bin/env bash
# Installe ou met à jour le plugin rey-agents dans Claude Code (relançable sans risque).
set -euo pipefail

# Tout est dans main() pour que bash lise le script en entier avant de l'exécuter
# quand il arrive par un pipe (sinon une commande qui lit stdin avale la suite).
claude_cli() { claude "$@" </dev/null; }

main() {
  REPO="RemFdz/ReyAgents"
  MARKETPLACE="rey-agents"
  PLUGIN="rey-agents@rey-agents"
  PERPLEXITY_MCP_URL="https://api.perplexity.ai/mcp"

  command -v claude >/dev/null || { echo "Claude Code introuvable : https://claude.com/claude-code" >&2; exit 1; }
  command -v git >/dev/null || { echo "git introuvable." >&2; exit 1; }

  # Repo privé : on passe par SSH si la clé GitHub marche, sinon par gh (HTTPS authentifié).
  # ssh -T sort toujours en code 1 sur GitHub : on lit la sortie hors du pipe à cause de pipefail.
  SSH_OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 || true)
  if [[ "$SSH_OUT" == *"successfully authenticated"* ]]; then
    SOURCE="git@github.com:${REPO}.git"
  elif command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    gh auth setup-git >/dev/null
    SOURCE="https://github.com/${REPO}.git"
  else
    echo "Aucun accès GitHub : lance 'gh auth login' (ou ajoute ta clé SSH) puis relance." >&2
    exit 1
  fi

  MARKETPLACES=$(claude_cli plugin marketplace list 2>/dev/null || true)
  if [[ "$MARKETPLACES" == *"❯ ${MARKETPLACE}"$'\n'* ]]; then
    echo "→ Mise à jour du marketplace ${MARKETPLACE}"
    claude_cli plugin marketplace update "$MARKETPLACE"
  else
    echo "→ Ajout du marketplace depuis ${SOURCE}"
    claude_cli plugin marketplace add "$SOURCE"
  fi

  PLUGINS=$(claude_cli plugin list 2>/dev/null || true)
  if [[ "$PLUGINS" == *"$PLUGIN"* ]]; then
    echo "→ Mise à jour de ${PLUGIN}"
    claude_cli plugin update "$PLUGIN"
  else
    echo "→ Installation de ${PLUGIN}"
    claude_cli plugin install "$PLUGIN"
  fi

  # Les agents référencent mcp__perplexity__* : le serveur doit s'appeler "perplexity".
  if claude_cli mcp get perplexity >/dev/null 2>&1; then
    echo "→ MCP perplexity déjà configuré"
  elif [[ -n "${PERPLEXITY_API_KEY:-}" ]]; then
    echo "→ Ajout du MCP perplexity (clé API)"
    claude_cli mcp add --scope user --transport http perplexity "$PERPLEXITY_MCP_URL" \
      --header "Authorization: Bearer ${PERPLEXITY_API_KEY}"
  else
    echo "→ Ajout du MCP perplexity (connexion OAuth à faire dans Claude Code via /mcp)"
    claude_cli mcp add --scope user --transport http perplexity "$PERPLEXITY_MCP_URL"
  fi

  # Outils tiers (copies de référence dans third_party/skills/). REY_SKIP_PONYTAIL=1 ou REY_SKIP_GRAPHIFY=1 pour les sauter.
  if [[ -z "${REY_SKIP_PONYTAIL:-}" ]]; then
    if [[ "$MARKETPLACES" == *"❯ ponytail"$'\n'* ]]; then
      echo "→ Mise à jour du marketplace ponytail"
      claude_cli plugin marketplace update ponytail
    else
      echo "→ Ajout du marketplace ponytail"
      claude_cli plugin marketplace add DietrichGebert/ponytail
    fi
    if [[ "$PLUGINS" == *"ponytail@ponytail"* ]]; then
      echo "→ Mise à jour de ponytail@ponytail"
      claude_cli plugin update ponytail@ponytail
    else
      echo "→ Installation de ponytail@ponytail (actif à chaque session, « stop ponytail » pour le couper)"
      claude_cli plugin install ponytail@ponytail
    fi
  fi

  if [[ -z "${REY_SKIP_GRAPHIFY:-}" ]]; then
    if command -v uv >/dev/null; then
      if command -v graphify >/dev/null; then
        echo "→ Mise à jour du CLI graphify"
        uv tool upgrade graphifyy || echo "⚠ graphify n'a pas été installé par uv : mets-le à jour avec ton outil (pipx, pip)." >&2
      else
        echo "→ Installation du CLI graphify"
        uv tool install graphifyy
      fi
      echo "→ Installation du skill graphify pour Claude Code"
      graphify install --platform claude </dev/null
    else
      echo "⚠ uv introuvable : graphify non installé (https://docs.astral.sh/uv/, puis relance)." >&2
    fi
  fi

  echo "✓ rey-agents prêt. Redémarre Claude Code, connecte Perplexity avec /mcp si besoin, puis lance : /rey-agents:rey <tâche>"
}

main "$@"
