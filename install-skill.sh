#!/usr/bin/env bash
# ==============================================================================
# wa-android-farm — Instalador da CLI Global + Skill Multi-Agente
# Instala a skill 'wa-android-farm' para Claude Code, Gemini/Antigravity, Codex e Cursor
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="${SCRIPT_DIR}/skills/wa-android-farm/SKILL.md"
CLI_SRC="${SCRIPT_DIR}/wa-farm.sh"

chmod +x "$CLI_SRC"

# 1. Instala a Skill nos diretórios globais de agentes de IA
SKILL_TARGETS=(
  "$HOME/.claude/skills/wa-android-farm"
  "$HOME/.gemini/config/skills/wa-android-farm"
  "$HOME/.codex/skills/wa-android-farm"
  "$HOME/.agents/skills/wa-android-farm"
)

for target_dir in "${SKILL_TARGETS[@]}"; do
  mkdir -p "$target_dir"
  cp -f "$SKILL_SRC" "${target_dir}/SKILL.md"
  printf "\033[1;32m[OK]\033[0m Skill instalada em: %s/SKILL.md\n" "$target_dir"
done

# 2. Cria symlink global ~/.local/bin/wa-farm
mkdir -p "$HOME/.local/bin"
ln -sf "$CLI_SRC" "$HOME/.local/bin/wa-farm"
printf "\033[1;32m[OK]\033[0m Atalho CLI criado em: %s/.local/bin/wa-farm\n" "$HOME"

printf "\n\033[1;36m[wa-android-farm]\033[0m Ferramenta e Skill instaladas com sucesso!\n"
