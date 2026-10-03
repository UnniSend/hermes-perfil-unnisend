#!/usr/bin/env bash
# Instalador do perfil Hermes da UnniSend (Mac e Linux). Um comando, o resto é automático:
#   1. instala o Hermes se ainda não existir;
#   2. instala (ou atualiza) o perfil "unnisend" a partir deste repositório;
#   3. pede a sua chave pessoal do OmniRoute da empresa e guarda só no seu computador.
# Nenhuma chave entra neste script nem no repositório.
set -euo pipefail

REPO="github.com/UnniSend/hermes-perfil-unnisend"
PERFIL="unnisend"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_PERFIL="$HERMES_HOME/profiles/$PERFIL/.env"

diga() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }

# 1) Hermes
if ! command -v hermes >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/hermes" ]; then
  diga "Instalando o Hermes (leva alguns minutos)..."
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --non-interactive
fi
export PATH="$HOME/.local/bin:$PATH"
command -v hermes >/dev/null 2>&1 || { echo "O Hermes não ficou disponível no PATH. Feche e abra o terminal e rode este comando de novo."; exit 1; }

# 2) Perfil da empresa (instala ou atualiza; suas conversas e chave não são tocadas)
if [ -d "$HERMES_HOME/profiles/$PERFIL" ]; then
  diga "Atualizando o perfil $PERFIL..."
  hermes profile update "$PERFIL" -y --force-config || true
else
  diga "Instalando o perfil $PERFIL..."
  hermes profile install "$REPO" --alias -y
fi

# 3) Chave pessoal (só se ainda não tiver)
if ! grep -qs '^UNNISEND_OMNIROUTE_KEY=sk-' "$ENV_PERFIL" 2>/dev/null; then
  diga "Cole a sua chave pessoal do OmniRoute da UnniSend (o Israel te enviou; começa com sk-)."
  printf 'Chave: '
  read -rs CHAVE </dev/tty
  echo
  case "$CHAVE" in
    sk-*) ;;
    *) echo "Isso não parece uma chave (precisa começar com sk-). Rode de novo quando tiver a chave."; exit 1 ;;
  esac
  mkdir -p "$(dirname "$ENV_PERFIL")"
  touch "$ENV_PERFIL"; chmod 600 "$ENV_PERFIL"
  grep -v '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" > "$ENV_PERFIL.tmp" 2>/dev/null || true
  printf 'UNNISEND_OMNIROUTE_KEY=%s\n' "$CHAVE" >> "$ENV_PERFIL.tmp"
  mv "$ENV_PERFIL.tmp" "$ENV_PERFIL"; chmod 600 "$ENV_PERFIL"
  unset CHAVE
fi

# 3b) Memória da empresa: o plugin hindsight do Hermes lê a chave em HINDSIGHT_API_KEY e o .env
# não expande ${...}; então gravamos a MESMA chave pessoal nessa variável. Nada novo entra no computador.
CHAVE_ATUAL="$(grep '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" | cut -d= -f2-)"
grep -v '^HINDSIGHT_API_KEY=' "$ENV_PERFIL" > "$ENV_PERFIL.tmp" 2>/dev/null || true
printf 'HINDSIGHT_API_KEY=%s\n' "$CHAVE_ATUAL" >> "$ENV_PERFIL.tmp"
mv "$ENV_PERFIL.tmp" "$ENV_PERFIL"; chmod 600 "$ENV_PERFIL"
unset CHAVE_ATUAL

# 3c) Plugin de memória (uma vez; o perfil já traz a configuração que aponta para o porteiro da empresa)
if [ ! -d "$HERMES_HOME/profiles/$PERFIL/plugins/hindsight" ]; then
  diga "Instalando o plugin de memória da empresa..."
  hermes -p "$PERFIL" plugins install hindsight >/dev/null 2>&1 || true
fi
hermes -p "$PERFIL" plugins enable hindsight >/dev/null 2>&1 || true

# 4) Atalho que atualiza o perfil sozinho (silencioso) e abre o chat
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/unnisend" <<'ATALHO'
#!/usr/bin/env bash
# Abre o Hermes com o perfil da UnniSend. Antes, puxa a versão mais nova do perfil (sem mexer na sua chave nem nas suas conversas).
export PATH="$HOME/.local/bin:$PATH"
( hermes profile update unnisend -y --force-config >/dev/null 2>&1 || true )
exec hermes -p unnisend "${@:-chat}"
ATALHO
chmod +x "$HOME/.local/bin/unnisend"

# 5) Prova rápida: a chave fala com o OmniRoute da empresa?
diga "Testando a conexão com o OmniRoute da UnniSend..."
CHAVE_TESTE="$(grep '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" | cut -d= -f2-)"
CODIGO="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "Authorization: Bearer $CHAVE_TESTE" https://omniroute.unnichat.com.br/v1/models || echo 000)"
unset CHAVE_TESTE
if [ "$CODIGO" = "200" ]; then
  diga "Tudo certo. Para usar, entre na pasta do projeto e rode:  unnisend chat"
else
  echo "A chave não foi aceita (resposta $CODIGO). Confira com o Israel se a chave está ativa e rode este comando de novo."
  exit 1
fi
