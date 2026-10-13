---
name: transcricao-vibe
description: Use sempre que o usuário mandar um arquivo de áudio ou vídeo (mp4, m4a, mp3, wav, ogg, opus, mkv, mov, webm) para transcrever, resumir, extrair pontos ou pegar frames. Transcreve local com vibe (whisper.cpp + GPU) gerando SRT com timestamps. Se o vibe, o ffmpeg ou o modelo não estiverem instalados, guia a instalação antes.
---

# Transcrição local com vibe

Transcreve áudio e vídeo **na própria máquina**, sem mandar nada para fora. A saída padrão é **SRT**: os
timestamps permitem citar o minuto exato de cada fala e extrair o quadro do vídeo naquele momento.

Peças:

| Peça | Para quê |
|---|---|
| [vibe](https://github.com/thewh1teagle/vibe) | app de transcrição sobre o whisper.cpp; tem CLI e servidor HTTP compatível com a API da OpenAI |
| modelo `ggml-*.bin` | o Whisper em si; o recomendado é o `ggml-large-v3-turbo.bin` (~1,6 GB) |
| ffmpeg | converte qualquer áudio/vídeo para WAV 16 kHz mono e extrai frames |
| curl | chama o servidor local |

## Atalho: o script pronto

`scripts/transcrever.sh` (ao lado deste arquivo) faz o fluxo inteiro: confere dependências, converte, sobe o
servidor, gera o SRT e derruba o servidor no fim.

```
scripts/transcrever.sh "<ARQUIVO>" pt "<PASTA_DE_SAIDA>"   (caminho relativo à pasta desta skill; no perfil unnisend fica em skills/transcricao-vibe/)
```

Nos exemplos seguintes, `scripts/` é relativo à pasta desta skill.

- 2º argumento: idioma ISO (`pt`, `en`, `es`) ou `auto`. Padrão: `pt`.
- 3º argumento: pasta de saída. Padrão: a pasta do arquivo.
- Variáveis opcionais: `VIBE_MODEL` (caminho do `.bin`), `VIBE_PORT` (padrão `8731`), `VIBE_FORMAT`
  (`srt`, `vtt`, `json`, `verbose_json`, `text`).

Funciona em Linux e macOS. No Windows, rodar pelo WSL ou seguir o passo a passo manual abaixo.

Use o passo a passo manual quando houver vários arquivos (sobe o servidor uma vez só) ou quando o script falhar.

---

## 0. Checagem antes de começar

Rodar cada comando separado:

```
command -v vibe
command -v ffmpeg
command -v curl
```

E procurar o modelo na pasta de dados do vibe:

| SO | Pasta dos modelos |
|---|---|
| Linux | `~/.local/share/github.com.thewh1teagle.vibe/` |
| macOS | `~/Library/Application Support/github.com.thewh1teagle.vibe/` |
| Windows | `%LOCALAPPDATA%\github.com.thewh1teagle.vibe\` |

```
ls ~/.local/share/github.com.thewh1teagle.vibe/
```

Se algo faltar, ir para **Instalação**. Se houver outro `ggml-*.bin` na pasta, dá para usar ele em vez de baixar
o turbo.

---

## Instalação

### 1. vibe

Página de download: https://github.com/thewh1teagle/vibe/releases/latest (ou https://thewh1teagle.github.io/vibe/).

| SO | Como instalar | Onde fica o executável |
|---|---|---|
| Arch / Manjaro / Omarchy | `yay -S vibe-bin` (AUR) | `/usr/bin/vibe` |
| Debian / Ubuntu | baixar `vibe_<versão>_amd64.deb` (ou `arm64`) e rodar `sudo apt install ./vibe_<versão>_amd64.deb` | `/usr/bin/vibe` |
| Fedora / openSUSE | baixar `vibe-<versão>-1.x86_64.rpm` e rodar `sudo dnf install ./vibe-<versão>-1.x86_64.rpm` | `/usr/bin/vibe` |
| macOS (Apple Silicon) | baixar `vibe_<versão>_aarch64.dmg` e arrastar para Aplicativos | `/Applications/vibe.app/Contents/MacOS/vibe` |
| macOS (Intel) | baixar `vibe_<versão>_x64.dmg` | idem |
| Windows | baixar e rodar `vibe_<versão>_x64-setup.exe` | `%LOCALAPPDATA%\vibe\vibe.exe` |

No macOS e no Windows o executável não entra no PATH. Criar um alias ou usar o caminho completo no lugar de `vibe`:

```
alias vibe="/Applications/vibe.app/Contents/MacOS/vibe"
```

Windows: se aparecer erro de `vcomp140.dll`, instalar o [VC++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe).
Se for `vulkan-1.dll`, instalar o [Vulkan Runtime](https://vulkan.lunarg.com/sdk/home).

Confirmar:

```
vibe --help
```

Tem que listar os subcomandos `transcribe`, `serve`, `pull` e `devices`.

### 2. ffmpeg

| SO | Comando |
|---|---|
| Arch | `sudo pacman -S ffmpeg` |
| Debian / Ubuntu | `sudo apt install ffmpeg` |
| Fedora | `sudo dnf install ffmpeg` (precisa do RPM Fusion) |
| macOS | `brew install ffmpeg` |
| Windows | `winget install Gyan.FFmpeg` |

### 3. Modelo

Escolha pelo hardware:

| Modelo | Tamanho | Quando usar |
|---|---|---|
| `ggml-large-v3-turbo.bin` | ~1,6 GB | **padrão**: tem GPU (NVIDIA, AMD, Intel ou Apple) |
| `ggml-medium.bin` | ~1,5 GB | GPU fraca; mais lento que o turbo, qualidade parecida |
| `ggml-small.bin` | ~470 MB | só CPU; perde qualidade em áudio ruim e nomes próprios |
| `ggml-base.bin` | ~140 MB | só para teste rápido |

Baixar direto na pasta de modelos (Linux; ajustar a pasta no macOS/Windows):

```
mkdir -p ~/.local/share/github.com.thewh1teagle.vibe
```

```
vibe pull https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin -o ~/.local/share/github.com.thewh1teagle.vibe/ggml-large-v3-turbo.bin
```

Alternativa sem o `vibe pull`:

```
curl -L -o ~/.local/share/github.com.thewh1teagle.vibe/ggml-large-v3-turbo.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

Abrir o app gráfico do vibe uma vez também baixa o modelo padrão para essa pasta.

### 4. Conferir a GPU

```
vibe devices
```

Se só aparecer CPU, a transcrição funciona, mas fica várias vezes mais lenta. Em notebook com GPU híbrida no
Linux, conferir driver e Vulkan (`vulkaninfo --summary`).

### 5. Teste de fumaça

Áudio de 10 s do próprio projeto:

```
curl -L -o /tmp/single.wav https://github.com/thewh1teagle/vibe/raw/main/server/fixtures/single.wav
```

```
scripts/transcrever.sh /tmp/single.wav auto /tmp
```

Esperado em `/tmp/single.srt`: *"And so, my fellow Americans, ask not what your country can do for you, ask what you
can do for your country."*

---

## Por que SRT via servidor, e não `vibe transcribe`

`vibe transcribe` (CLI) **só imprime texto corrido, sem timestamps**. `--word-timestamps` e `-v` não mudam a
saída. Para SRT é obrigatório usar `vibe serve`, que expõe `POST /v1/audio/transcriptions` no formato da OpenAI e
aceita `response_format=srt`.

## Passo a passo manual

Nos comandos abaixo, `MODELO` é o caminho completo do `.bin` (ex.:
`~/.local/share/github.com.thewh1teagle.vibe/ggml-large-v3-turbo.bin`).

### 1. Extrair o áudio em WAV 16 kHz mono

Sempre converter antes: evita falha de container e acelera a inferência.

```
ffmpeg -y -i "<ARQUIVO>" -vn -ac 1 -ar 16000 -c:a pcm_s16le "<SAIDA>.wav"
```

### 2. Subir o servidor (uma vez, em background)

```
vibe serve "<MODELO>" --port 8731
```

No Claude Code, rodar com `run_in_background: true`. Confirmar que subiu:

```
curl -s -m 5 http://127.0.0.1:8731/v1/models
```

`--port 0` (o padrão) sorteia uma porta. Fixar sempre a porta.

### 3. Pedir o SRT

```
curl -s -m 900 http://127.0.0.1:8731/v1/audio/transcriptions -F file=@<SAIDA>.wav -F model=ggml-large-v3-turbo.bin -F language=pt -F response_format=srt -o <SAIDA>.srt
```

- `language`: código ISO (`pt`, `en`, `es`). Omitir para detectar sozinho.
- `response_format`: também aceita `json`, `verbose_json`, `text` e `vtt`.
- `model`: o nome do arquivo `.bin` que o servidor carregou.

### 4. Derrubar o servidor

**Assim que o último SRT sair.** Ele segura ~1,6 GB do modelo na GPU enquanto estiver de pé.
`--exit-with-parent` só age quando o processo pai morre, o que no Claude Code é a sessão inteira.

- No Claude Code: `TaskStop` no id do processo em background.
- No terminal: `pkill -f "vibe serve"`.

Vários arquivos: subir uma vez, transcrever todos, derrubar no fim.

### 5. Ler e reportar

Ler o `.srt` e, ao resumir, **citar o timestamp** de cada ponto:

```
[02:14] Ana: o clique tem que ser no node inteiro
```

## Extrair frames do vídeo

Com o timestamp do SRT, pegar o quadro correspondente:

```
ffmpeg -y -ss 00:02:14 -i "<VIDEO>" -frames:v 1 -q:v 2 "<SAIDA>-0214.jpg"
```

Depois abrir a imagem (no Claude Code, com Read). Fazer isso sempre que a fala apontar para algo visual
("esse botão aqui", "esse node", "olha esse layout"): o texto sozinho não diz o que é "esse".

Vários frames: um comando por timestamp.

## Regras

- Arquivos intermediários (`.wav`, `.srt`, frames) ficam numa pasta temporária ou no scratchpad da sessão, nunca
  dentro do repositório.
- Caminho com espaço ou parêntese: **sempre entre aspas**.
- Tempo de referência: 5 min de vídeo levam ~1 min numa RTX 4050 (Vulkan) com o turbo. Só CPU: conte 5–10× mais.
  Para vídeos longos, timeout de 900 s ou mais no `curl`.
- Nunca deixar o servidor de pé depois de terminar.

## Problemas comuns

| Sintoma | Causa | Saída |
|---|---|---|
| `vibe: command not found` no macOS/Windows | executável fora do PATH | alias ou caminho completo (tabela da Instalação) |
| `curl: (7) Failed to connect` | servidor ainda carregando ou caiu | esperar 5–10 s; se persistir, rodar `vibe serve` em primeiro plano e ler o erro |
| `Address already in use` | porta 8731 ocupada (servidor antigo esquecido) | `pkill -f "vibe serve"` ou trocar a porta |
| saída sem timestamps | usou `vibe transcribe` | usar o servidor com `response_format=srt` |
| texto em inglês num áudio em português | detecção automática errou | passar `language=pt` |
| muito lento | rodando na CPU | `vibe devices`; conferir driver/Vulkan ou usar `ggml-small.bin` |
| `vcomp140.dll` / `vulkan-1.dll` faltando (Windows) | runtime ausente | links na seção Instalação |
| frases repetidas em trecho de silêncio | alucinação do Whisper em silêncio longo | cortar o silêncio com ffmpeg antes, ou ignorar o trecho |
