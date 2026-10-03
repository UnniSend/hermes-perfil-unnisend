"""Atualização automática do perfil da UnniSend com o Hermes ABERTO.

Problema que resolve: o atalho `unnisend` atualiza o perfil só na abertura. Quem deixa o
Hermes aberto por dias nunca receberia a versão nova. Este plugin roda antes de cada
mensagem (gancho pre_llm_call): no máximo a cada INTERVALO segundos, compara a versão
publicada no GitHub com a instalada; se mudou, roda `hermes profile update` em segundo
plano (silencioso, sem mexer em .env nem nas conversas) e avisa o membro na resposta.

Nunca imprime chaves. Nunca bloqueia a conversa: a verificação é rápida (1 pedido HTTP com
tempo limite de 4 s) e a atualização roda em processo separado.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

PERFIL = Path(__file__).resolve().parents[2].name  # nome do perfil instalado (unnisend)
REPO_RAW = "https://raw.githubusercontent.com/UnniSend/hermes-perfil-unnisend/main/distribution.yaml"
INTERVALO = int(os.environ.get("UNNISEND_ATUALIZA_INTERVALO", "1800"))  # 30 min
_estado = {"ultima_checagem": 0.0, "versao_remota": None, "atualizando": False, "aviso": None}
_trava = threading.Lock()


def _home() -> Path:
    return Path(__file__).resolve().parents[2]  # <perfil>/plugins/unnisend_atualiza/__init__.py


def _versao_instalada() -> str | None:
    try:
        for linha in (_home() / "distribution.yaml").read_text(encoding="utf-8").splitlines():
            if linha.startswith("version:"):
                return linha.split(":", 1)[1].strip().strip("'\"")
    except Exception:
        return None
    return None


def _versao_remota() -> str | None:
    """Lê a versão publicada. O repositório é privado: usa o token de leitura do perfil
    (UNNISEND_PERFIL_TOKEN, só leitura, gravado pelo instalador) se existir."""
    cab = {"User-Agent": "unnisend-perfil"}
    token = os.environ.get("UNNISEND_PERFIL_TOKEN", "").strip()
    if token:
        cab["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(urllib.request.Request(REPO_RAW, headers=cab), timeout=4) as r:
            for linha in r.read().decode("utf-8", "ignore").splitlines():
                if linha.startswith("version:"):
                    return linha.split(":", 1)[1].strip().strip("'\"")
    except Exception:
        return None
    return None


def _atualizar_em_segundo_plano(nova: str) -> None:
    def _rodar():
        try:
            env = dict(os.environ)
            env.pop("HERMES_HOME", None)
            # Usa o mesmo Python em que o Hermes está rodando (o venv dele), nunca o python do sistema.
            r = subprocess.run(
                [sys.executable, "-m", "hermes_cli.main", "profile", "update", PERFIL, "-y", "--force-config"],
                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=180, check=False,
            )
            if r.returncode != 0:
                hermes = shutil.which("hermes") or str(Path.home() / ".local/bin/hermes")
                r = subprocess.run(
                    [hermes, "profile", "update", PERFIL, "-y", "--force-config"],
                    env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=180, check=False,
                )
            ok = r.returncode == 0 and _versao_instalada() == nova
            with _trava:
                _estado["aviso"] = (
                    f"[Perfil da UnniSend atualizado para a versão {nova} em segundo plano. "
                    "Regras e agentes novos valem a partir da próxima conversa; suas mensagens e sua chave não mudaram.]"
                    if ok else
                    f"[Há uma versão nova do perfil da UnniSend ({nova}), mas a atualização automática falhou. "
                    "Feche e abra o unnisend; se continuar, avise o Israel.]"
                )
        except Exception:
            pass
        finally:
            with _trava:
                _estado["atualizando"] = False
    threading.Thread(target=_rodar, name="unnisend-atualiza", daemon=True).start()


def _pre_llm_call(**kw):
    agora = time.time()
    with _trava:
        aviso = _estado["aviso"]
        _estado["aviso"] = None
        if agora - _estado["ultima_checagem"] < INTERVALO or _estado["atualizando"]:
            return {"context": aviso} if aviso else None
        _estado["ultima_checagem"] = agora
    local, remota = _versao_instalada(), _versao_remota()
    if remota and local and remota != local:
        with _trava:
            _estado["atualizando"] = True
        _atualizar_em_segundo_plano(remota)
    return {"context": aviso} if aviso else None


def register(ctx) -> None:
    ctx.register_hook("pre_llm_call", _pre_llm_call)
