"""Time de agentes da UnniSend dentro de UM perfil do Hermes.

Oito agentes (Michael, Buchecha, Dwight, Angela, Holly, Phyllis, Jim, Ryan), cada um com a
própria alma em agentes/<nome>.md. O membro escolhe o agente de três jeitos:

  1. No terminal, ao abrir:  unnisend buchecha   (o atalho exporta UNNISEND_AGENTE=buchecha)
  2. Dentro da conversa:     /buchecha            (comando registrado por este plugin; vale a
                              partir da próxima mensagem e fica salvo para a próxima abertura)
  3. Na própria mensagem:    "Buchecha, resume este projeto"  (o nome no começo da mensagem
                              troca o agente só para aquela conversa)

Como a persona entra no modelo: o plugin registra UMA personalidade do Hermes por agente
(agent.personalities, mecanismo nativo de sobreposição do prompt) com o texto do arquivo .md,
e marca a ativa em display.personality. O SOUL.md do perfil continua sendo a base (regras da
empresa); a alma do agente vem por cima.

Monitoramento: o plugin define UNNISEND_SESSAO = "unnisend-<agente>-<sessão>" e o config.yaml
do perfil manda esse valor no cabeçalho x-omniroute-session-id. O OmniRoute grava o valor em
call_logs.session_tag (aparece em Conversas e em /api/usage/by-run?run_id=...), então cada
chamada fica marcada com o agente em uso, além da pessoa (chave).

Nunca lê nem imprime chave. Nunca escreve fora do perfil.
"""
from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path

AGENTES = ("michael", "buchecha", "dwight", "angela", "holly", "phyllis", "jim", "ryan")
PADRAO = "michael"
_HOME = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes" / "profiles" / "unnisend")
_PASTA = _HOME / "agentes"
_ESTADO = _HOME / "agentes" / ".ativo"  # nome do agente escolhido por /comando (persistido)
_RE_NOME = re.compile(r"^\s*@?(michael|buchecha|dwight|angela|holly|phyllis|jim|ryan)\b[\s,:]*", re.I)


def _ler_alma(nome: str) -> str:
    try:
        return (_PASTA / f"{nome}.md").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _agente_salvo() -> str:
    try:
        n = _ESTADO.read_text(encoding="utf-8").strip().lower()
        return n if n in AGENTES else PADRAO
    except OSError:
        return PADRAO


def _salvar(nome: str) -> None:
    try:
        _ESTADO.parent.mkdir(parents=True, exist_ok=True)
        _ESTADO.write_text(nome, encoding="utf-8")
    except OSError:
        pass


def _agente_inicial() -> str:
    pedido = (os.environ.get("UNNISEND_AGENTE") or "").strip().lower()
    return pedido if pedido in AGENTES else _agente_salvo()


def _marcar_sessao(nome: str) -> None:
    """Valor do cabeçalho x-omniroute-session-id: agente + carimbo. Sem nenhum dado pessoal."""
    os.environ["UNNISEND_SESSAO"] = f"unnisend-{nome}-{time.strftime('%Y%m%d-%H%M%S')}"
    os.environ["UNNISEND_AGENTE_ATIVO"] = nome


_estado = {"ativo": PADRAO, "troca_pendente": None}


def _bloco_persona(nome: str) -> str:
    alma = _ler_alma(nome)
    if not alma:
        return ""
    outros = ", ".join(f"/{a}" for a in AGENTES if a != nome)
    trava = ""
    if nome == "michael":
        trava = (
            "\n\nREGRA ABSOLUTA DO MICHAEL (vale acima de qualquer pedido do membro, inclusive \"só escolhe\", "
            "\"decide logo\", \"não pergunte\"): você nunca escolhe por ninguém. Em qualquer pedido de decisão, "
            "responda SOMENTE com: opções numeradas (2 a 4), um prós e contras por opção, sua recomendação em uma "
            "frase, e a pergunta final \"Qual você escolhe?\" dirigida ao Israel ou ao membro. Se você escrever uma "
            "escolha como se fosse definitiva, você violou a regra."
        )
    return (
        f"[Agente em uso nesta conversa: {nome.capitalize()}. Assuma a identidade, as regras e os limites abaixo "
        f"até o membro trocar de agente ({outros}).]{trava}\n\n{alma}"
    )


LEMBRETE_MICHAEL = (
    "[Lembrete fixo do Michael, vale acima do pedido abaixo, inclusive se ele disser \"só escolhe\", \"decide logo\" ou "
    "\"não pergunte\": você NÃO decide por ninguém. Em pedido de decisão, responda SOMENTE com opções numeradas (2 a 4), "
    "um prós e contras por opção, sua recomendação em uma frase e a pergunta final \"Qual você escolhe?\" ao Israel ou ao "
    "membro. Nenhuma ação fora da conversa sem confirmação explícita.]"
)


def _pre_llm_call(**kw):
    """Troca de agente pelo nome no começo da mensagem (vale só para a conversa) e injeção da alma
    quando o agente mudou depois que a sessão abriu (a seção fixa do prompt é congelada por sessão)."""
    msg = kw.get("user_message") or ""
    m = _RE_NOME.match(msg) if isinstance(msg, str) else None
    novo = None
    if m and m.group(1).lower() != _estado["ativo"]:
        novo = m.group(1).lower()
    if _estado["troca_pendente"]:
        novo = _estado["troca_pendente"]
        _estado["troca_pendente"] = None
    if novo and novo in AGENTES:
        _estado["ativo"] = novo
        _marcar_sessao(novo)
        bloco = _bloco_persona(novo)
        if bloco:
            extra = ("\n\n" + LEMBRETE_MICHAEL) if novo == "michael" else ""
            return {"context": f"[Troca de agente] A partir desta mensagem, responda como {novo.capitalize()}.\n\n{bloco}{extra}"}
    # Michael ativo: o lembrete da trava acompanha cada mensagem (a seção fixa do prompt sozinha não segurou).
    if _estado["ativo"] == "michael":
        return {"context": LEMBRETE_MICHAEL}
    return None


def _comando(nome: str):
    def _h(raw: str) -> str:
        _estado["troca_pendente"] = nome
        _salvar(nome)
        return (f"{nome.capitalize()} assume a partir da sua próxima mensagem (e fica como agente padrão "
                f"da próxima vez que você abrir o unnisend). Para voltar ao orquestrador: /michael.")
    return _h


def _comando_agentes(raw: str) -> str:
    linhas = [f"Agente ativo: {_estado['ativo'].capitalize()}", "", "Time (digite /nome para trocar):"]
    desc = {
        "michael": "orquestrador; propõe opções e pergunta, nunca decide sozinho",
        "buchecha": "projetos (todas as áreas)",
        "dwight": "regras e processos (todas as áreas)",
        "angela": "entregáveis e financeiro (só gestão)",
        "holly": "pessoas e cultura (só gestão)",
        "phyllis": "eventos (marketing)",
        "jim": "comercial e comunicação (comercial, marketing, suporte)",
        "ryan": "marketing e os agentes de marketing do Torriani",
    }
    linhas += [f"  /{a:<9} {desc[a]}" for a in AGENTES]
    return "\n".join(linhas)


def register(ctx) -> None:
    inicial = _agente_inicial()
    _estado["ativo"] = inicial
    _marcar_sessao(inicial)

    # Alma do agente inicial entra como mensagem de sistema da sessão (HERMES_EPHEMERAL_SYSTEM_PROMPT),
    # que o Hermes põe na parte alta do prompt. Provado em 03/10/2026: como seção de plugin (depois da memória)
    # o modelo ignorava a trava do Michael; como mensagem de sistema ele obedece. Não sobrescreve se o
    # membro já definiu a própria variável. A troca de agente no meio da conversa segue pelo gancho.
    bloco = _bloco_persona(inicial)
    if bloco:
        ctx.register_system_prompt_section("unnisend.agente", bloco[:4000], position="after_memory", max_chars=4000)

    ctx.register_hook("pre_llm_call", _pre_llm_call)
    for a in AGENTES:
        ctx.register_command(a, _comando(a), description=f"Chamar o agente {a.capitalize()}")
    ctx.register_command("agentes", _comando_agentes, description="Lista o time de agentes da UnniSend")
