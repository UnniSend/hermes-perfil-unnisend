#!/usr/bin/env bash
# unnisend torriani send | unni
# Abre o Hermes da UnniSend DENTRO do kit da consultoria Torriani (repositório UnniSend/consultoria-torriani),
# fixado em um negócio (SendFlow ou UnniChat). O que acontece, nesta ordem:
#   1. pede ao porteiro da empresa (memoria.unnichat.com.br) a chave de leitura do repositório, usando a SUA chave
#      do OmniRoute; o porteiro só entrega para quem é de Marketing Sendi / Marketing Unni (ou gestão) e diz quais
#      negócios você pode abrir;
#   2. baixa (ou atualiza) o repositório em ~/UnniSend/consultoria-torriani, SÓ TEXTO (.md, .yaml, .json e os
#      scripts do kit): sem ContextOS/outputs, imagens, fontes, HTML, PDF, zip e sem LFS;
#   3. deixa visíveis como comandos de barra só as skills do negócio escolhido (/sendflow-copy, /sendflow-trafego...);
#   4. abre o Hermes na pasta ContextOS, que lê o AGENTS.md do Torriani e obedece ao contrato dele.
# Nada é gravado no repositório do Torriani (a chave é só de leitura). Nenhuma chave aparece na tela.
set -euo pipefail

NEG="${1:-}"
case "$NEG" in
  send|sendflow|sendi) NEG=sendflow ;;
  unni|unnichat) NEG=unnichat ;;
  *) echo "Uso: unnisend torriani send    (SendFlow)"; echo "     unnisend torriani unni    (UnniChat)"; exit 1 ;;
esac

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PERFIL="unnisend"
P="$HERMES_HOME/profiles/$PERFIL"
ENV_PERFIL="$P/.env"
PORTEIRO="${UNNISEND_PORTEIRO:-https://memoria.unnichat.com.br}"
REPO_DIR="${UNNISEND_TORRIANI_DIR:-$HOME/UnniSend/consultoria-torriani}"
CHAVE_SSH="$P/chaves/torriani_ed25519"
SKILLS_DIR="$P/torriani-skills"

diga() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
for b in git curl python3; do command -v "$b" >/dev/null 2>&1 || { echo "Falta o programa '$b' no seu computador. Fale com o Israel."; exit 1; }; done

CHAVE="$(grep '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" 2>/dev/null | cut -d= -f2- || true)"
[ -n "$CHAVE" ] || { echo "Sua chave do OmniRoute não está no perfil. Rode o instalador do perfil de novo."; exit 1; }

# 1) Porteiro: posso? quais negócios? chave de leitura do repositório
diga "Pedindo ao porteiro da empresa o acesso ao kit do Torriani..."
RESP="$(curl -sS --max-time 25 -H "Authorization: Bearer $CHAVE" "$PORTEIRO/ferramentas/repo-torriani" || true)"
unset CHAVE
PARSE="$(printf '%s' "$RESP" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("ERRO porteiro sem resposta"); sys.exit(0)
if "segredo_base64" not in d: print("ERRO "+str(d.get("detail","acesso negado"))); sys.exit(0)
print("OK "+",".join(d.get("negocios",[]))+" "+d["segredo_base64"])
')"
case "$PARSE" in
  OK*) ;;
  *) echo "${PARSE#ERRO }"; echo "(o porteiro só libera o kit para Marketing Sendi e Marketing Unni; se você é de uma dessas áreas, fale com o Israel)"; exit 1 ;;
esac
NEGOCIOS="$(printf '%s' "$PARSE" | cut -d' ' -f2)"
SEGREDO_B64="$(printf '%s' "$PARSE" | cut -d' ' -f3)"
unset PARSE RESP
case ",$NEGOCIOS," in
  *",$NEG,"*) ;;
  *) echo "Sua área não abre o negócio '$NEG' (você pode: $NEGOCIOS)."; exit 1 ;;
esac
mkdir -p "$(dirname "$CHAVE_SSH")"; chmod 700 "$(dirname "$CHAVE_SSH")"
umask 077
printf '%s' "$SEGREDO_B64" | base64 -d > "$CHAVE_SSH"
unset SEGREDO_B64
chmod 600 "$CHAVE_SSH"

# 2) Repositório: clone reduzido (sem outputs/, sem LFS) ou atualização
export GIT_SSH_COMMAND="ssh -i $CHAVE_SSH -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export GIT_LFS_SKIP_SMUDGE=1
REMOTO="git@github.com:UnniSend/consultoria-torriani.git"
# Só texto chega ao computador (decisão do Israel, 16/10/2026): instruções, contexto e configuração em .md/.yaml/.json
# e os scripts do kit. Ficam no GitHub: entregas antigas (outputs/), imagens, fontes, páginas HTML, PDFs, zips e snapshots.
SO_TEXTO=('/*' '!/ContextOS/outputs/' '!*.png' '!*.jpg' '!*.jpeg' '!*.gif' '!*.webp' '!*.svg' '!*.ttf' '!*.otf' '!*.woff' '!*.woff2' \
  '!*.html' '!*.pdf' '!*.zip' '!*.bin' '!*.mp4' '!*.mov' '!*.mp3' '!*.wav' '!*.pyc' '!*.psd' '!*.fig')
if [ ! -d "$REPO_DIR/.git" ]; then
  diga "Baixando o kit do Torriani (só os textos, uns 50 MB; leva menos de 1 minuto)..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone -q --filter=blob:none --no-checkout --depth 1 "$REMOTO" "$REPO_DIR"
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git checkout -q main )
else
  diga "Atualizando o kit do Torriani..."
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git fetch -q --depth 1 origin main && git reset -q --hard origin/main ) || echo "(não consegui atualizar agora; seguindo com a versão que já está no computador)"
fi
VERSAO="$(cd "$REPO_DIR" && git log -1 --format='%h de %ad' --date=format:'%d/%m %H:%M')"

# 3) Comandos de barra: só as skills do negócio escolhido (+ me-guia), por link simbólico; nada é copiado
rm -rf "$SKILLS_DIR"; mkdir -p "$SKILLS_DIR"
for s in "$REPO_DIR"/ContextOS/.agents/skills/"$NEG"-* "$REPO_DIR"/ContextOS/.agents/skills/me-guia; do
  [ -f "$s/SKILL.md" ] && ln -s "$s" "$SKILLS_DIR/$(basename "$s")"
done
N_SKILLS="$(ls "$SKILLS_DIR" | wc -l | tr -d ' ')"

# 4) Hermes dentro do kit, negócio fixado
export UNNISEND_TORRIANI_NEGOCIO="$NEG"
export UNNISEND_TORRIANI_REPO="$REPO_DIR"
export UNNISEND_AGENTE="${UNNISEND_AGENTE:-ryan}"
diga "Kit do Torriani $VERSAO, negócio $NEG, $N_SKILLS comandos (digite /${NEG}-copy, /${NEG}-trafego... ou /torriani para a lista)."
cd "$REPO_DIR/ContextOS"
exec hermes -p "$PERFIL" chat
