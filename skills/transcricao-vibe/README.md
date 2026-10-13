# transcricao-vibe — skill do Claude Code

Transcreve áudio e vídeo localmente (vibe + whisper.cpp, com GPU) e gera SRT com timestamps. Nada sai da máquina.

## Instalar a skill

1. Copiar esta pasta para `<pasta de skills do seu Hermes ou Claude Code>/`:

   ```
   cp -r transcricao-vibe <pasta de skills do seu Hermes ou Claude Code>/
   ```

2. Dar permissão de execução ao script:

   ```
   chmod +x <pasta de skills do seu Hermes ou Claude Code>/transcricao-vibe/scripts/transcrever.sh
   ```

3. Abrir uma sessão nova do Claude Code. A skill aparece como `transcricao-vibe`.

## Instalar as dependências

Seção **Instalação** do `SKILL.md`: vibe, ffmpeg e o modelo `ggml-large-v3-turbo.bin` (~1,6 GB), com comandos para
Arch, Debian/Ubuntu, Fedora, macOS e Windows. O mesmo arquivo traz um teste de 10 s para confirmar.

## Usar

No Claude Code, mandar o arquivo: "transcreve esse áudio: /caminho/reuniao.m4a". A skill entra sozinha.

Sem o Claude, direto no terminal:

```
<pasta de skills do seu Hermes ou Claude Code>/transcricao-vibe/scripts/transcrever.sh "/caminho/reuniao.m4a" pt
```

O `.srt` sai na mesma pasta do arquivo.

## Conteúdo

| Arquivo | O que é |
|---|---|
| `SKILL.md` | instruções da skill: instalação, fluxo manual, frames, problemas comuns |
| `scripts/transcrever.sh` | fluxo completo num comando (Linux e macOS) |
