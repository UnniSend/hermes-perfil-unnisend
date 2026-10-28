#!/usr/bin/env bash
# torriani send | unni   (atalho de: unnisend torriani send | unni)
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
  *) echo "Uso: torriani send    (SendFlow)"; echo "     torriani unni    (UnniChat)"; exit 1 ;;
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
# O que chega ao computador (decisão do Israel, 16/10 e 28/10/2026):
#   1. textos do kit: instruções, contexto e configuração em .md/.yaml/.json e os scripts;
#   2. a marca inteira de cada negócio (negocios/*/CerebroOS/marca/**): logos, fontes, manual em PDF, design system
#      e componentes, porque sem isso os assistentes de design não acham logo nem fonte (reteste de 28/10);
#   3. as referências de design que as skills mandam ler, com as imagens: os .md de outputs/*/compartilhado/design,
#      as peças e páginas piloto e o padrão de post de 22/10, e as capas do Instagram (artes/*-capa.*; os slides
#      internos ficam no GitHub, só os 10 carrosséis citados em REFERENCIAS-INSTAGRAM.md descem).
# Ficam no GitHub: entregas antigas (resto de outputs/), acervo Lovable, vídeos, zips, bundles e snapshots.
# Ordem importa: no sparse-checkout sem cone, a ÚLTIMA regra que casa com o arquivo vence.
SO_TEXTO=('/*' '!/ContextOS/outputs/**' \
  '/ContextOS/outputs/*/compartilhado/design/*/*.md' '/ContextOS/outputs/*/compartilhado/design/*/**/*.md' \
  '!*.png' '!*.jpg' '!*.jpeg' '!*.gif' '!*.webp' '!*.svg' '!*.ttf' '!*.otf' '!*.woff' '!*.woff2' \
  '!*.html' '!*.pdf' '!*.zip' '!*.bin' '!*.mp4' '!*.mov' '!*.mp3' '!*.wav' '!*.pyc' '!*.psd' '!*.fig' \
  '/ContextOS/negocios/*/CerebroOS/marca/**' \
  '/ContextOS/outputs/*/compartilhado/design/pecas-piloto-2026-10-22/**' \
  '/ContextOS/outputs/*/compartilhado/design/paginas-piloto-2026-10-22/**' \
  '/ContextOS/outputs/*/compartilhado/design/padrao-de-post-2026-10-22/**' \
  '/ContextOS/outputs/*/compartilhado/design/instagram-2026-10-14/artes/*-capa.*' \
  '/ContextOS/outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DZazEu_FYHd-slide-*' \
  '/ContextOS/outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DaghxjJlX7D-slide-*' \
  '/ContextOS/outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DcwW3tvlWlT-slide-*' \
  '/ContextOS/outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DdC0QKrlT2s-slide-*' \
  '/ContextOS/outputs/sendflow/compartilhado/design/instagram-2026-10-14/artes/DdFZDxCFXDN-slide-*' \
  '/ContextOS/outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes/DT3Z9dKjpGq-slide-*' \
  '/ContextOS/outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes/DTJTRlyDnUv-slide-*' \
  '/ContextOS/outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes/Db0fuGpDp-b-slide-*' \
  '/ContextOS/outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes/DblPTvGjtNU-slide-*' \
  '/ContextOS/outputs/unnichat/compartilhado/design/instagram-2026-10-14/artes/DcRle42CRQm-slide-*' \
  '!**/*.mp4' '!**/*.mov' '!**/*.zip' '!**/*.tar.gz' '!**/*.bundle' '!**/*.psd' '!**/*.fig')
if [ ! -d "$REPO_DIR/.git" ]; then
  diga "Baixando o kit do Torriani (textos, marca e referências de design, uns 650 MB; leva de 1 a 3 minutos)..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone -q --filter=blob:none --no-checkout --depth 1 "$REMOTO" "$REPO_DIR"
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git checkout -q main )
else
  diga "Atualizando o kit do Torriani (na primeira vez depois de 28/10 baixa a marca e as referências, uns 400 MB)..."
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git fetch -q --depth 1 origin main && git reset -q --hard origin/main ) || echo "(não consegui atualizar agora; seguindo com a versão que já está no computador)"
fi
VERSAO="$(cd "$REPO_DIR" && git log -1 --format='%h de %ad' --date=format:'%d/%m %H:%M')"
# Conferência: logo e fonte precisam estar no disco; se não estiverem, o design não vai funcionar.
N_FONTES="$(find "$REPO_DIR"/ContextOS/negocios/"$NEG"/CerebroOS/marca -name '*.ttf' 2>/dev/null | wc -l | tr -d ' ')"
N_LOGOS="$(find "$REPO_DIR"/ContextOS/negocios/"$NEG"/CerebroOS/marca -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')"
[ "$N_FONTES" -gt 0 ] && [ "$N_LOGOS" -gt 0 ] || echo "Atenção: a marca do $NEG não baixou inteira ($N_LOGOS logos, $N_FONTES fontes). Avise o Israel."

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
