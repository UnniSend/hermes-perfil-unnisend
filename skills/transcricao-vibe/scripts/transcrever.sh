#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'TXT'
uso: transcrever.sh <arquivo> [idioma] [pasta-de-saida]

  arquivo         áudio ou vídeo (mp4, m4a, mp3, wav, ogg, opus, mkv, mov, webm)
  idioma          código ISO (pt, en, es) ou "auto" — padrão: pt
  pasta-de-saida  onde salvar a transcrição — padrão: a pasta do arquivo

variáveis opcionais:
  VIBE_MODEL   caminho do modelo .bin (padrão: procura o ggml-large-v3-turbo.bin)
  VIBE_PORT    porta do servidor local (padrão: 8731)
  VIBE_FORMAT  srt, vtt, json, verbose_json ou text (padrão: srt)
TXT
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
	usage
	exit 1
fi

INPUT="$1"
LANGUAGE="${2:-pt}"
OUT_DIR="${3:-$(dirname "$INPUT")}"
PORT="${VIBE_PORT:-8731}"
FORMAT="${VIBE_FORMAT:-srt}"
MODEL="${VIBE_MODEL:-}"
BASE_URL="http://127.0.0.1:${PORT}"

for bin in vibe ffmpeg curl; do
	if ! command -v "$bin" >/dev/null 2>&1; then
		echo "erro: '$bin' não encontrado no PATH. Veja a seção Instalação do SKILL.md." >&2
		exit 1
	fi
done

if [[ ! -f "$INPUT" ]]; then
	echo "erro: arquivo não encontrado: $INPUT" >&2
	exit 1
fi

if [[ -z "$MODEL" ]]; then
	for dir in \
		"$HOME/.local/share/github.com.thewh1teagle.vibe" \
		"$HOME/Library/Application Support/github.com.thewh1teagle.vibe"; do
		if [[ -f "$dir/ggml-large-v3-turbo.bin" ]]; then
			MODEL="$dir/ggml-large-v3-turbo.bin"
			break
		fi
		candidate="$(find "$dir" -maxdepth 1 -name 'ggml-*.bin' 2>/dev/null | head -n 1 || true)"
		if [[ -n "$candidate" ]]; then
			MODEL="$candidate"
			break
		fi
	done
fi

if [[ -z "$MODEL" || ! -f "$MODEL" ]]; then
	echo "erro: modelo não encontrado. Baixe com:" >&2
	echo "  vibe pull https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin -o \"\$HOME/.local/share/github.com.thewh1teagle.vibe/ggml-large-v3-turbo.bin\"" >&2
	echo "ou aponte VIBE_MODEL para um .bin que já exista." >&2
	exit 1
fi

mkdir -p "$OUT_DIR"
WORK_DIR="$(mktemp -d)"
SERVER_PID=""

cleanup() {
	if [[ -n "$SERVER_PID" ]]; then
		kill "$SERVER_PID" 2>/dev/null || true
		wait "$SERVER_PID" 2>/dev/null || true
	fi
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

NAME="$(basename "${INPUT%.*}")"
WAV="$WORK_DIR/audio.wav"
OUTPUT="$OUT_DIR/$NAME.$FORMAT"
if [[ "$FORMAT" == "text" ]]; then
	OUTPUT="$OUT_DIR/$NAME.txt"
fi

echo "1/3 convertendo para WAV 16 kHz mono..."
ffmpeg -nostdin -loglevel error -y -i "$INPUT" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$WAV"

if curl -s -m 3 "$BASE_URL/v1/models" >/dev/null 2>&1; then
	echo "2/3 servidor já estava de pé na porta $PORT — reaproveitando"
else
	echo "2/3 subindo o vibe na porta $PORT ($(basename "$MODEL"))..."
	vibe serve "$MODEL" --port "$PORT" >"$WORK_DIR/server.log" 2>&1 &
	SERVER_PID=$!
	for _ in $(seq 1 120); do
		if curl -s -m 2 "$BASE_URL/v1/models" >/dev/null 2>&1; then
			break
		fi
		if ! kill -0 "$SERVER_PID" 2>/dev/null; then
			echo "erro: o servidor caiu ao subir. Log:" >&2
			cat "$WORK_DIR/server.log" >&2
			exit 1
		fi
		sleep 1
	done
	if ! curl -s -m 2 "$BASE_URL/v1/models" >/dev/null 2>&1; then
		echo "erro: o servidor não respondeu em 120 s. Log:" >&2
		cat "$WORK_DIR/server.log" >&2
		exit 1
	fi
fi

echo "3/3 transcrevendo (pode levar alguns minutos)..."
LANG_ARGS=()
if [[ "$LANGUAGE" != "auto" ]]; then
	LANG_ARGS=(-F "language=$LANGUAGE")
fi

curl -sS -f -m 3600 "$BASE_URL/v1/audio/transcriptions" \
	-F "file=@$WAV" \
	-F "model=$(basename "$MODEL")" \
	${LANG_ARGS[@]+"${LANG_ARGS[@]}"} \
	-F "response_format=$FORMAT" \
	-o "$OUTPUT"

echo "pronto: $OUTPUT"
