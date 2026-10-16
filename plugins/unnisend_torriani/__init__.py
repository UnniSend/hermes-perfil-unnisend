"""Kit da consultoria Torriani dentro do Hermes da UnniSend.

Só faz algo quando a sessão foi aberta por `torriani send|unni` (scripts/torriani.sh), que
exporta UNNISEND_TORRIANI_NEGOCIO (sendflow|unnichat) e UNNISEND_TORRIANI_REPO (pasta do clone).
Nesse caso:
  1. põe no prompt de sistema o negócio fixado e a regra de não trocar de negócio (o kit do Torriani
     exige escolha explícita; o isolamento entre SendFlow e UnniChat vem daí);
  2. registra /torriani, que lista os comandos de barra do negócio (as skills do kit, ligadas por link
     simbólico em <perfil>/torriani-skills pelo launcher) e a versão do kit.
As skills em si são carregadas pelo próprio Hermes (skills.external_dirs: torriani-skills no config
do perfil). Fora do kit o plugin não registra nada. Nunca lê nem imprime chave.
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

NEGOCIO = (os.environ.get("UNNISEND_TORRIANI_NEGOCIO") or "").strip().lower()
REPO = Path(os.environ.get("UNNISEND_TORRIANI_REPO") or "").expanduser()
_HOME = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes" / "profiles" / "unnisend")
_SKILLS = _HOME / "torriani-skills"
NOMES = {"sendflow": "SendFlow", "unnichat": "UnniChat"}


def _versao() -> str:
    try:
        r = subprocess.run(["git", "log", "-1", "--format=%h de %ad", "--date=format:%d/%m %H:%M"],
                           cwd=str(REPO), capture_output=True, text=True, timeout=5, check=False)
        return r.stdout.strip() or "?"
    except Exception:
        return "?"


def _comandos() -> list[str]:
    try:
        return sorted(p.name for p in _SKILLS.iterdir() if (p / "SKILL.md").exists())
    except OSError:
        return []


def _comando_torriani(raw: str) -> str:
    cmds = _comandos()
    linhas = [f"Kit da consultoria Torriani, versão {_versao()}, negócio fixado: {NOMES.get(NEGOCIO, NEGOCIO)}.",
              f"Pasta: {REPO / 'ContextOS'}", "",
              f"Comandos deste negócio ({len(cmds)}):"]
    linhas += [f"  /{c}" for c in cmds]
    linhas += ["", "Para o outro negócio, feche e abra com `torriani send` ou `torriani unni`.",
               "Entregas vão para outputs/<negócio>/ dentro da pasta; o repositório é só leitura (nada sobe para o GitHub daqui)."]
    return "\n".join(linhas)


def register(ctx) -> None:
    if NEGOCIO not in NOMES or not REPO.is_dir():
        return
    bloco = (
        f"# Kit da consultoria Torriani (sessão fixada em {NOMES[NEGOCIO]})\n"
        f"Você está dentro de {REPO / 'ContextOS'}. O AGENTS.md dessa pasta é o contrato do Torriani e manda. "
        f"Negócio explícito desta sessão: `{NEGOCIO}`. Não troque de negócio nem leia negocios/ do outro; "
        f"use só as skills {NEGOCIO}-* (comandos de barra) e os squads por elas indicados; grave em outputs/{NEGOCIO}/. "
        "Não instale nada no HOME, não publique, não gaste, não conecte serviço externo: este kit é preparado, não integrado. "
        "Se um script do kit falhar, mostre o erro completo e diga que o Torriani precisa corrigir no repositório dele."
    )
    ctx.register_system_prompt_section("unnisend.torriani", bloco, position="after_memory", max_chars=1200)
    ctx.register_command("torriani", _comando_torriani, description="Kit do Torriani: negócio fixado, versão e comandos disponíveis")
