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
