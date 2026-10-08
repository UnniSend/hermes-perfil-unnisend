# Perfil Hermes da UnniSend

Este repositório é o perfil empresarial do Hermes para o time da UnniSend (SendFlow e UnniChat).
Ele define como o assistente trabalha, quais skills e agentes estão liberados e por onde passa a IA
(OmniRoute da empresa). Não contém nenhuma senha ou chave.

## Instalar no seu computador (uma vez)

Mac ou Linux, no Terminal:

    curl -fsSL https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/instalar.sh | bash

Windows, no PowerShell:

    irm https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/instalar.ps1 | iex

O instalador instala o Hermes (se faltar), baixa este perfil e pede a sua chave pessoal, que o Israel
entrega a cada pessoa. Depois, para usar, abra a pasta do projeto e rode:

    unnisend chat

## Atualizar

O perfil se atualiza sozinho ao abrir. Se quiser forçar:

    hermes profile update unnisend

Suas conversas, memória e chave ficam no seu computador e não são tocadas pela atualização.

## Modelos

O padrão do perfil é `unnisend/sonnet` (Claude Sonnet 4.6 com reservas automáticas). Também existem `unnisend/opus` (Opus 4.7) e `unnisend/haiku` (rápido e barato). Troque com `/model unnisend/opus` dentro da conversa ou `unnisend --model unnisend/opus`.

Evite por enquanto os modelos Claude 5.5 (`claude-sonnet-5-5`, `claude-opus-5-5`, `auto/claude-sonnet`, `auto/claude-opus`): a versão atual do roteador ainda envia o parâmetro `temperature`, que esses modelos recusam, e a chamada falha com 400 "temperature is deprecated". Nas IDEs (Claude Code, Cursor) esse problema não acontece.

Alterações feitas direto no `config.yaml` do perfil voltam ao padrão na próxima atualização. Para persistir, use `--model` na linha de comando ou peça a mudança ao Israel.

## Memória da empresa

Além da memória individual (no seu computador), o Hermes lembra fatos compartilhados da sua área e da empresa. Isso passa pelo porteiro de memória da UnniSend (https://memoria.unnichat.com.br), que reconhece você pela sua chave pessoal do OmniRoute e descobre a sua área no Notion da UnniSend (cadastro de membros): você só vê a memória da sua área e a geral. Quem é de Gestão ou Liderança vê todas as áreas. A chave administrativa da memória fica no servidor; no seu computador existe apenas a sua chave.

O instalador grava a sua chave também como `HINDSIGHT_API_KEY` no `.env` do perfil (o plugin de memória lê por esse nome). Se a memória da empresa parar de responder, confira com o Israel se a sua chave continua ativa.

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
