# Perfil Hermes da UnniSend

Este repositório é o perfil empresarial do Hermes para o time da UnniSend (SendFlow e UnniChat).
Ele define como o assistente trabalha, quais skills e agentes estão liberados e por onde passa a IA
(OmniRoute da empresa). Não contém nenhuma senha ou chave.

## Instalar no seu computador (uma vez)

Mac ou Linux (Ubuntu, Fedora, Arch...), no Terminal:

    curl -fsSL https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/instalar.sh | bash

Windows, no PowerShell:

    irm https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/instalar.ps1 | iex

O instalador instala o Hermes (se faltar; leva de 3 a 8 minutos e pode parecer parado no download), baixa este perfil e pede a sua chave pessoal, que o Israel entrega a cada pessoa por DM. Se o campo da chave não aparecer (acontece em alguns terminais quando se roda por `curl | bash`), passe a chave na variável:

    UNNISEND_OMNIROUTE_KEY=sk-... bash <(curl -fsSL https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/instalar.sh) Depois, para usar, abra a pasta do projeto e rode:

    unnisend chat

## Atualizar

O perfil se atualiza sozinho ao abrir. Se quiser forçar:

    hermes profile update unnisend

Suas conversas, memória e chave ficam no seu computador e não são tocadas pela atualização.

## Modelos

O padrão do perfil é `unnisend/sonnet` (Claude Sonnet 5.5, com reserva automática no Sonnet 5 e 4.6). Também existem `unnisend/opus` (Opus 5.5, reserva Opus 5) e `unnisend/haiku` (Haiku 5.5, rápido e barato). Troque com `/model unnisend/opus` dentro da conversa ou `unnisend --model unnisend/opus`.

A sua chave libera `unnisend/*`, os Claude 5.5 (`claude/claude-sonnet-5-5`, `claude/claude-opus-5-5`, `claude/claude-haiku-5-5`), os 5.0 (`claude-sonnet-5`, `claude-opus-5`), o Sonnet 4.6 e o Haiku 4.5, além de `cc/claude-sonnet-5-5` e `cc/claude-opus-5-5` para quem usa a rota do Claude Code. Pedir modelo fora da lista devolve "Model not allowed". Quando a Anthropic lança modelo novo, um vigia da UnniSend confere duas vezes por semana e coloca o mais novo na frente dos `unnisend/*` sozinho; você não precisa mudar nada.

Alterações feitas direto no `config.yaml` do perfil voltam ao padrão na próxima atualização. Para persistir, use `--model` na linha de comando ou peça a mudança ao Israel.

## Transcrição local de áudio e vídeo (skill do José)

O perfil traz a skill `transcricao-vibe`, feita pelo José Augusto: transcreve reunião gravada, áudio de WhatsApp ou vídeo na própria máquina, sem mandar nada para fora, e entrega o texto com minutagem (SRT). Para usar, é preciso instalar o programa `vibe` (https://github.com/thewh1teagle/vibe/releases/latest) e o `ffmpeg`, e baixar o modelo de voz (1,6 GB) uma vez; o próprio Hermes guia a instalação quando você pedir para transcrever algo. Com placa de vídeo, uma hora de reunião leva uns 5 minutos; sem placa, pode levar de 30 minutos a 1 hora.

## Memória da empresa

Além da memória individual (no seu computador), o Hermes lembra fatos compartilhados da sua área e da empresa. Isso passa pelo porteiro de memória da UnniSend (https://memoria.unnichat.com.br), que reconhece você pela sua chave pessoal do OmniRoute e descobre a sua área no Notion da UnniSend (cadastro de membros): você só vê a memória da sua área e a geral. Quem é de Gestão ou Liderança vê todas as áreas. A chave administrativa da memória fica no servidor; no seu computador existe apenas a sua chave.

O instalador grava a sua chave também como `HINDSIGHT_API_KEY` no `.env` do perfil (o plugin de memória lê por esse nome). Se a memória da empresa parar de responder, confira com o Israel se a sua chave continua ativa.

## Quem sou eu para o Hermes

O Hermes descobre seu nome e sua área pela sua chave (via porteiro de memória e cadastro de membros do Notion) e usa isso para adaptar o que responde. Para conferir: `/eu` dentro da conversa. Se vier errado, fale com o Israel.

## Kit da consultoria Torriani (Marketing)

Os assistentes de marketing que o Juliano Torriani entrega ficam em um repositório privado da UnniSend (`consultoria-torriani`). Quem é de Marketing Sendi ou Marketing Unni abre o kit assim:

    torriani send      SendFlow
    torriani unni      UnniChat

(Quem instalou o perfil antes de 16/10 ainda não tem o atalho curto: use `unnisend torriani send` ou rode o instalador de novo.)

O comando pede ao porteiro da empresa a chave de leitura do repositório (só sua área recebe; quem não é de marketing vê "sua área não usa"), baixa ou atualiza o kit em `~/UnniSend/consultoria-torriani` (textos do kit, a marca inteira de cada negócio com logos, fontes e manual, e as referências de design com imagens: capas do Instagram, peças e páginas piloto; uns 650 MB. Vídeos, acervo Lovable e entregas antigas ficam no GitHub) e abre o Hermes dentro da pasta `ContextOS`, com o negócio fixado. Os quinze assistentes do negócio viram comandos de barra (`/sendflow-copy`, `/sendflow-trafego`, `/sendflow-design`...; ou `unnichat-*`); `/torriani` mostra a lista e a versão do kit. A cada abertura o kit é atualizado sozinho com o que o Torriani publicou.

O repositório é só leitura a partir do seu computador: as entregas ficam em `outputs/<negócio>/` na sua máquina e nada sobe para o GitHub daqui. Se um script do kit der erro, mande a mensagem para o Israel: é o Torriani quem corrige no repositório dele.

## Agentes do time

Dentro do mesmo perfil há um time de agentes, cada um com uma função. Você escolhe de três jeitos:

    unnisend buchecha           abre direto com o Buchecha
    /buchecha                   troca de agente dentro da conversa (vale a partir da próxima mensagem)
    "Buchecha, resume isto"     o nome no começo da mensagem troca só para aquela conversa

    /agentes                    lista o time

| Agente   | Função                                   | Para quem                     |
| -------- | ---------------------------------------- | ----------------------------- |
| Michael  | Orquestrador: entende o pedido, organiza o caminho e aciona o especialista. Nunca decide sozinho: propõe opções e pergunta ao Israel. | Todos (padrão ao abrir) |
| Buchecha | Projetos: status, risco, próximo passo, dono | Todos |
| Dwight   | Regras e processos da empresa             | Todos |
| Phyllis  | Eventos: briefing e abertura de projetos de evento | Marketing |
| Jim      | Comercial e comunicação: metas, funil, mensagens | Comercial, Marketing, Suporte |
| Ryan     | Marketing e os agentes de marketing do Torriani | Marketing |
| Angela   | Entregáveis e financeiro                  | Só Gestão |
| Holly    | Pessoas e cultura                         | Só Gestão |

Cada chamada à IA sai marcada com o agente em uso, então o Israel vê no painel do OmniRoute quem usou qual agente.
