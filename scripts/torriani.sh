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
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*)
  # Git Bash no Windows: o Hermes guarda o perfil em %LOCALAPPDATA%\hermes; caminhos C:\... viram /c/... para o bash.
  [ -n "${HERMES_HOME_SET:-}" ] || HERMES_HOME="$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")/hermes"
  case "$HERMES_HOME" in [A-Za-z]:*) HERMES_HOME="$(cygpath -u "$HERMES_HOME")" ;; esac ;;
esac
PERFIL="unnisend"
P="$HERMES_HOME/profiles/$PERFIL"
ENV_PERFIL="$P/.env"
PORTEIRO="${UNNISEND_PORTEIRO:-https://memoria.unnichat.com.br}"
REPO_DIR="${UNNISEND_TORRIANI_DIR:-$HOME/UnniSend/consultoria-torriani}"
CHAVE_SSH="$P/chaves/torriani_ed25519"
SKILLS_DIR="$P/torriani-skills"

diga() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
case " $* " in *" --desktop "*) diga "Aviso: a opção --desktop ainda não existe; o kit abre aqui no terminal (é o caminho certo hoje). O aplicativo Hermes Desktop fica para a próxima rodada." ;; esac
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) WINDOWS=1 ;; *) WINDOWS=0 ;; esac
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python   # no Windows o Python do sistema costuma se chamar python
for b in git curl "$PY"; do command -v "$b" >/dev/null 2>&1 || { echo "Falta o programa '$b' no seu computador. Fale com o Israel."; exit 1; }; done
command -v hermes >/dev/null 2>&1 || { echo "O comando hermes não está no PATH deste terminal. Feche e abra o terminal de novo."; exit 1; }

CHAVE="$(grep '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" 2>/dev/null | cut -d= -f2- || true)"
[ -n "$CHAVE" ] || { echo "Sua chave do OmniRoute não está no perfil. Rode o instalador do perfil de novo."; exit 1; }

# 1) Porteiro: posso? quais negócios? chave de leitura do repositório
diga "Pedindo ao porteiro da empresa o acesso ao kit do Torriani..."
RESP="$(curl -sS --max-time 25 -H "Authorization: Bearer $CHAVE" "$PORTEIRO/ferramentas/repo-torriani" || true)"
unset CHAVE
PARSE="$(printf '%s' "$RESP" | "$PY" -c '
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
export GIT_SSH_COMMAND="ssh -i '$CHAVE_SSH' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export GIT_LFS_SKIP_SMUDGE=1
REMOTO="git@github.com:UnniSend/consultoria-torriani.git"
# O que chega ao computador (Caminho C, decisão do Israel em 28/10/2026, substitui o "tudo da marca" da 0.4.0):
#   1. todo texto do kit: .md, .txt, .json, .yaml, .csv, scripts; inclui os .md de referência de design em
#      outputs/*/compartilhado/design e o texto/OCR das artes do Instagram (texto/artes/*.txt);
#   2. de binário, SÓ logos (svg) e fontes (ttf/otf/woff/woff2) de negocios/*/CerebroOS/marca.
# Ficam no GitHub: artes do Instagram, fotos, prints, manuais em PDF, HTML/JS dos componentes, acervos, vídeos, zips.
# O assistente busca do GitHub só o arquivo que for usar, na hora: scripts/buscar-arquivo.sh (deste perfil).
# Ordem importa: no sparse-checkout sem cone, a ÚLTIMA regra que casa com o arquivo vence.
SO_TEXTO=('/*' '!/ContextOS/outputs/**' \
  '/ContextOS/outputs/*/compartilhado/design/*/*.md' '/ContextOS/outputs/*/compartilhado/design/*/**/*.md' \
  '/ContextOS/outputs/*/compartilhado/design/*/**/*.txt' '/ContextOS/outputs/*/compartilhado/design/*/*.json' \
  '!*.png' '!*.jpg' '!*.jpeg' '!*.gif' '!*.webp' '!*.svg' '!*.ttf' '!*.otf' '!*.woff' '!*.woff2' \
  '!*.html' '!*.pdf' '!*.zip' '!*.bin' '!*.mp4' '!*.mov' '!*.mp3' '!*.wav' '!*.pyc' '!*.psd' '!*.fig' '!*.xlsx' '!*.sha256' \
  '/ContextOS/negocios/*/CerebroOS/marca/**/*.svg' \
  '/ContextOS/negocios/*/CerebroOS/marca/**/*.ttf' '/ContextOS/negocios/*/CerebroOS/marca/**/*.otf' \
  '/ContextOS/negocios/*/CerebroOS/marca/**/*.woff' '/ContextOS/negocios/*/CerebroOS/marca/**/*.woff2')
if [ ! -d "$REPO_DIR/.git" ]; then
  diga "Baixando o kit do Torriani (textos, logos e fontes, uns 170 MB; leva menos de 1 minuto)..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone -q --filter=blob:none --no-checkout --depth 1 "$REMOTO" "$REPO_DIR"
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git checkout -q main && touch .git/caminho-c )
elif [ ! -f "$REPO_DIR/.git/caminho-c" ]; then
  # Quem veio da 0.3.x/0.4.0: o histórico local guarda artes, PDFs e componentes que não vamos mais usar (até 400 MB)
  # e o git não devolve esse espaço. Uma vez só: clone novo enxuto, e as suas entregas (outputs/, .env e tudo que não
  # é do repositório) passam para ele. Se o clone novo falhar, nada é apagado e segue a atualização normal.
  diga "Reorganizando o kit do Torriani (uma vez só: baixa de novo só o essencial, uns 170 MB, e mantém as suas entregas)..."
  NOVO="$REPO_DIR.novo.$$"
  if git clone -q --filter=blob:none --no-checkout --depth 1 "$REMOTO" "$NOVO" \
     && ( cd "$NOVO" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" && git checkout -q main ) \
     && ( cd "$REPO_DIR" && git ls-files --others -z | tar -c --null -T - -f - ) | ( cd "$NOVO" && tar -x -f - ); then
    touch "$NOVO/.git/caminho-c"
    mv "$REPO_DIR" "$REPO_DIR.antigo.$$" && mv "$NOVO" "$REPO_DIR" && rm -rf "$REPO_DIR.antigo.$$"
  else
    rm -rf "$NOVO"
    echo "(não consegui reorganizar agora; seguindo com a atualização normal)"
    ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" 2>/dev/null && git fetch -q --depth 1 origin main && git reset -q --hard origin/main ) || echo "(não consegui atualizar agora; seguindo com a versão que já está no computador)"
  fi
else
  diga "Atualizando o kit do Torriani..."
  # set + reset --hard reaplicam o padrão: o que a pessoa baixou com buscar-arquivo.sh sai do disco de novo (de propósito).
  ( cd "$REPO_DIR" && git sparse-checkout set --no-cone "${SO_TEXTO[@]}" 2>/dev/null && git fetch -q --depth 1 origin main && git reset -q --hard origin/main ) || echo "(não consegui atualizar agora; seguindo com a versão que já está no computador)"
fi
VERSAO="$(cd "$REPO_DIR" && git log -1 --format='%h de %ad' --date=format:'%d/%m %H:%M')"
# Conferência: logo e fonte precisam estar no disco; se não estiverem, o design não vai funcionar.
N_FONTES="$(find "$REPO_DIR"/ContextOS/negocios/"$NEG"/CerebroOS/marca -name '*.ttf' 2>/dev/null | wc -l | tr -d ' ')"
N_LOGOS="$(find "$REPO_DIR"/ContextOS/negocios/"$NEG"/CerebroOS/marca -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')"
[ "$N_FONTES" -gt 0 ] && [ "$N_LOGOS" -gt 0 ] || echo "Atenção: a marca do $NEG não baixou inteira ($N_LOGOS logos, $N_FONTES fontes). Avise o Israel."

# 3) Comandos de barra: só as skills do negócio escolhido (+ me-guia), por link simbólico; nada é copiado
rm -rf "$SKILLS_DIR"; mkdir -p "$SKILLS_DIR"
for s in "$REPO_DIR"/ContextOS/.agents/skills/"$NEG"-* "$REPO_DIR"/ContextOS/.agents/skills/me-guia; do
  if [ -f "$s/SKILL.md" ]; then
    if [ "$WINDOWS" = 1 ]; then cp -R "$s" "$SKILLS_DIR/$(basename "$s")"; else ln -s "$s" "$SKILLS_DIR/$(basename "$s")"; fi
  fi
done
N_SKILLS="$(ls "$SKILLS_DIR" | wc -l | tr -d ' ')"

# 4) Hermes dentro do kit, negócio fixado
export UNNISEND_TORRIANI_NEGOCIO="$NEG"
export UNNISEND_TORRIANI_REPO="$REPO_DIR"
export UNNISEND_AGENTE="${UNNISEND_AGENTE:-ryan}"
# buscar-arquivo.sh (deste perfil) no PATH da sessão: o assistente baixa do GitHub só o arquivo que for usar
chmod +x "$P/scripts/buscar-arquivo.sh" 2>/dev/null || true
export PATH="$P/scripts:$PATH"
# 5) Geração de imagem (política 1.1 do Torriani): a chave do OpenRouter da empresa vem do porteiro, por área, e entra
# na sessão só como OPENROUTER_API_KEY dos comandos de terminal (o Hermes bloqueia esse nome no ambiente herdado,
# por isso ela viaja com nome neutro e é traduzida pelo shell-init do perfil). Nada vai para arquivo.
IMG_RESP="$(curl -sS --max-time 25 -H "Authorization: Bearer $(grep '^UNNISEND_OMNIROUTE_KEY=' "$ENV_PERFIL" | cut -d= -f2-)" "$PORTEIRO/ferramentas/imagem-openrouter" 2>/dev/null || true)"
IMG_KEY="$(printf '%s' "$IMG_RESP" | "$PY" -c '
import json,sys,base64
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
s=d.get("segredo_base64")
if s: print(base64.b64decode(s).decode().strip())
')"
unset IMG_RESP
if [ -n "$IMG_KEY" ]; then
  # O chat roda no gateway do Hermes: do ambiente desta shell só viajam nomes de ferramenta sem cara de segredo
  # (terminal.client_env_passthrough do perfil lista UNNISEND_IMAGEM_OR). Dentro da sessão, o arquivo de início
  # do shell do perfil (terminal.shell_init_files) traduz para OPENROUTER_API_KEY e some com o nome neutro.
  export UNNISEND_IMAGEM_OR="$IMG_KEY"
  IMAGEM="imagem ligada"
else
  IMAGEM="imagem desligada (sua área não tem, ou o servidor não respondeu)"
fi
unset IMG_KEY
diga "Kit do Torriani $VERSAO, negócio $NEG, $N_SKILLS comandos (digite /${NEG}-copy, /${NEG}-trafego... ou /torriani para a lista); $IMAGEM."
cd "$REPO_DIR/ContextOS"
if [ "$WINDOWS" = 1 ]; then hermes -p "$PERFIL" chat; exit $?; fi
exec hermes -p "$PERFIL" chat
