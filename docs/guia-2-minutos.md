# Manada no seu computador: guia de 2 minutos

Vale para o Hermes no Terminal (comando `unnisend` ou `torriani`) e para o Hermes Desktop (a janela). É a mesma coisa, só muda a moldura.

## Como pedir

Escreva como falaria com uma pessoa do time: o que você quer, para quem é, e o que já tem em mãos. Exemplos:

- "Escreve 3 opções de legenda para o Instagram do UnniChat sobre atendimento com IA, tom direto, sem emoji."
- "Lê o arquivo briefing.md desta pasta e me diz o que falta para começar a campanha."
- "Gera uma imagem de fundo para post, 1080x1350, sem texto."

Ele trabalha na pasta em que você abriu o programa. Abra na pasta do projeto e ele enxerga os arquivos de lá.

## Os comandos que importam

| Comando | O que faz |
|---|---|
| `/me-guia` | Mostra o que você pode pedir (os especialistas da sua área) |
| `/eu` | Confirma quem ele acha que você é (nome e área) |
| `/cota` | Quanto falta do seu limite de IA hoje e na semana |
| `/model` | Troca o modelo. `unnisend/sonnet` é o padrão (bom e barato); `unnisend/opus` para tarefas difíceis |
| `/new` | Começa uma conversa nova (faça isso ao trocar de assunto) |
| `/exit` | Sai |

## Tela enxuta ou tela detalhada

Por padrão a tela é **enxuta** (modo foco): você vê o seu pedido e a resposta. O que ele fez por baixo (arquivos lidos, comandos rodados) fica escondido, e no fim aparece uma linha dizendo quantas linhas foram escondidas.

- Quer ver o que ele está fazendo? `/focus off`
- Quer voltar para a tela limpa? `/focus on`
- Quer o nível máximo de detalhe (cada comando e resultado)? `/verbose verbose`
- Quer ver o raciocínio dele antes da resposta? `/reasoning show` (e `/reasoning hide` para esconder)

A sua escolha fica guardada, mesmo quando o perfil da empresa atualiza sozinho.

## Como saber quem está falando

A sua mensagem aparece com **Você ❯** em verde. A resposta aparece com **☤ Manada**. Linhas que começam com `$` são comandos que ele rodou no seu computador (só aparecem fora do modo foco).

## Quando algo der errado

- "Chave não aceita" ou erro 401: a chave do OmniRoute no seu perfil está errada. Fale com o Israel.
- "Limite atingido" ou 429: você bateu o teto do dia. `/cota` mostra quando renova.
- Travou ou está estranho: `/new` resolve a maioria. Se não resolver, feche e abra de novo.
- Qualquer outra coisa: mande um print no #manada_ com o que você pediu.
