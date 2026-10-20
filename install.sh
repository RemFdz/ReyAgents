#!/usr/bin/env bash
# Installe ou met à jour le plugin rey-agents dans Claude Code (relançable sans risque).
set -euo pipefail

REPO="RemFdz/ReyAgents"
MARKETPLACE="rey-agents"
PLUGIN="rey-agents@rey-agents"

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

if claude plugin marketplace list 2>/dev/null | grep -q "❯ ${MARKETPLACE}\$"; then
  echo "→ Mise à jour du marketplace ${MARKETPLACE}"
  claude plugin marketplace update "$MARKETPLACE"
else
  echo "→ Ajout du marketplace depuis ${SOURCE}"
  claude plugin marketplace add "$SOURCE"
fi

if claude plugin list 2>/dev/null | grep -q "$PLUGIN"; then
  echo "→ Mise à jour de ${PLUGIN}"
  claude plugin update "$PLUGIN"
else
  echo "→ Installation de ${PLUGIN}"
  claude plugin install "$PLUGIN"
fi

echo "✓ rey-agents prêt. Redémarre Claude Code puis lance : /rey-agents:rey <tâche>"
