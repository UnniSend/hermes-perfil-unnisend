#!/usr/bin/env bash
# Busca do GitHub um arquivo do kit do Torriani que não está no computador (artes do Instagram, fotos, prints,
# manuais em PDF, acervos) e grava no mesmo caminho dentro do clone. Só leitura; nada sobe para o GitHub.
#
#   buscar-arquivo.sh <caminho relativo a ContextOS/ ou ao clone> [outro caminho...]
#   buscar-arquivo.sh --pasta <pasta relativa>        baixa a pasta inteira (cuidado com artes/: são centenas de MB)
#   buscar-arquivo.sh --listar <pasta relativa>       lista o que existe no GitHub naquela pasta, sem baixar
#
# Exemplos:
#   buscar-arquivo.sh outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DbHPxzEDqmi-capa.jpg
#   buscar-arquivo.sh "negocios/sendflow/CerebroOS/marca/identidade-visual/manual/Manual de Identidade Visual - SendFlow.pdf"
#   (nome com espaço vai entre aspas)
#   buscar-arquivo.sh --listar outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes
#
# Como funciona: o clone é "sparse" (só texto, logos e fontes). Este script adiciona o caminho ao sparse-checkout
# e faz o git baixar só aquele blob. O arquivo passa a ficar no disco até a próxima abertura do kit, que reaplica o
# padrão enxuto (o que você baixou aqui some de novo; é de propósito, para o clone não engordar).
set -euo pipefail
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
P="$HERMES_HOME/profiles/unnisend"
REPO_DIR="${UNNISEND_TORRIANI_REPO:-${UNNISEND_TORRIANI_DIR:-$HOME/UnniSend/consultoria-torriani}}"
CHAVE_SSH="$P/chaves/torriani_ed25519"
[ -d "$REPO_DIR/.git" ] || { echo "Não achei o kit em $REPO_DIR. Abra com 'torriani send' ou 'torriani unni' primeiro."; exit 1; }
[ -f "$CHAVE_SSH" ] || { echo "Chave de leitura do repositório não está no perfil. Abra o kit com 'torriani send|unni' (ela é baixada na abertura)."; exit 1; }
export GIT_SSH_COMMAND="ssh -i $CHAVE_SSH -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export GIT_LFS_SKIP_SMUDGE=1
cd "$REPO_DIR"

# caminho pode vir relativo a ContextOS/ (como as skills escrevem) ou ao clone; normaliza para o clone
normaliza() {
  local c="${1#./}"; c="${c#/}"
  case "$c" in ContextOS/*) ;; *) c="ContextOS/$c" ;; esac
  printf '%s' "$c"
}
modo="arquivo"
case "${1:-}" in
  --pasta) modo="pasta"; shift ;;
  --listar) modo="listar"; shift ;;
  -h|--help|"") sed -n '2,17p' "$0"; exit 0 ;;
esac
[ $# -ge 1 ] || { echo "Diga qual arquivo (caminho relativo a ContextOS/)."; exit 1; }

if [ "$modo" = "listar" ]; then
  pasta="$(normaliza "$1")"
  git ls-tree -r --name-only origin/main -- "$pasta" 2>/dev/null | sed "s#^ContextOS/##" | head -500
  n="$(git ls-tree -r --name-only origin/main -- "$pasta" 2>/dev/null | wc -l | tr -d ' ')"
  echo "($n arquivos no GitHub em $pasta; nenhum foi baixado)"
  exit 0
fi

regras=()
for a in "$@"; do
  c="$(normaliza "$a")"
  if [ "$modo" = "pasta" ]; then
    regras+=("/$c/**")
  else
    if ! git cat-file -e "origin/main:$c" 2>/dev/null; then
      echo "Não existe no GitHub: $c"
      echo "  (confira o nome com: buscar-arquivo.sh --listar \"$(dirname "${c#ContextOS/}")\")"
      continue
    fi
    regras+=("/$c")
  fi
done
[ ${#regras[@]} -gt 0 ] || exit 1
# entra no padrão do sparse-checkout (o repo já está em modo no-cone; 'add' herda o modo) e materializa
git sparse-checkout add "${regras[@]}" >/dev/null 2>&1 || true
git read-tree -mu HEAD >/dev/null 2>&1 || true
for a in "$@"; do
  c="$(normaliza "$a")"
  if [ "$modo" = "pasta" ]; then
    n="$(find "$c" -type f 2>/dev/null | wc -l | tr -d ' ')"; echo "Pasta baixada: $c ($n arquivos, $(du -sh "$c" 2>/dev/null | cut -f1))"
  elif git cat-file -e "origin/main:$c" 2>/dev/null; then
    # garantia: se o sparse-checkout não materializou, grava o conteúdo direto do GitHub no mesmo caminho
    if [ ! -s "$c" ]; then mkdir -p "$(dirname "$c")" && git show "origin/main:$c" > "$c"; fi
    echo "Baixado: $REPO_DIR/$c ($(du -h "$c" | cut -f1))"
  fi
done
