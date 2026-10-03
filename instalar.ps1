# Instalador do perfil Hermes da UnniSend para Windows (PowerShell). Um comando, o resto é automático.
# Nenhuma chave entra neste script nem no repositório.
$ErrorActionPreference = "Stop"
$Repo = "github.com/UnniSend/hermes-perfil-unnisend"
$Perfil = "unnisend"
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $HOME ".hermes" }
$EnvPerfil = Join-Path $HermesHome "profiles\$Perfil\.env"

function Diga($t) { Write-Host "`n$t" -ForegroundColor Cyan }

# 1) Hermes
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
  Diga "Instalando o Hermes (leva alguns minutos)..."
  Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1) } -NonInteractive"
  $env:Path = "$HOME\.local\bin;" + [Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path
}
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
  Write-Host "O Hermes não ficou disponível. Feche e abra o PowerShell e rode este comando de novo."; exit 1
}

# 2) Perfil da empresa
if (Test-Path (Join-Path $HermesHome "profiles\$Perfil")) {
  Diga "Atualizando o perfil $Perfil..."
  hermes profile update $Perfil -y --force-config
} else {
  Diga "Instalando o perfil $Perfil..."
  hermes profile install $Repo --alias -y
}

# 3) Chave pessoal
$temChave = (Test-Path $EnvPerfil) -and (Select-String -Path $EnvPerfil -Pattern '^UNNISEND_OMNIROUTE_KEY=sk-' -Quiet)
if (-not $temChave) {
  Diga "Cole a sua chave pessoal do OmniRoute da UnniSend (o Israel te enviou; começa com sk-)."
  $segura = Read-Host -Prompt "Chave" -AsSecureString
  $chave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura))
  if (-not $chave.StartsWith("sk-")) { Write-Host "Isso não parece uma chave (precisa começar com sk-)."; exit 1 }
  New-Item -ItemType Directory -Force -Path (Split-Path $EnvPerfil) | Out-Null
  $linhas = @()
  if (Test-Path $EnvPerfil) { $linhas = Get-Content $EnvPerfil | Where-Object { $_ -notmatch '^UNNISEND_OMNIROUTE_KEY=' } }
  $linhas += "UNNISEND_OMNIROUTE_KEY=$chave"
  Set-Content -Path $EnvPerfil -Value $linhas -Encoding ascii
  $chave = $null
}

# 4) Atalho "unnisend" que atualiza o perfil sozinho e abre o chat
$bin = Join-Path $HOME ".local\bin"; New-Item -ItemType Directory -Force -Path $bin | Out-Null
@'
@echo off
hermes profile update unnisend -y --force-config >nul 2>&1
if "%~1"=="" (hermes -p unnisend chat) else (hermes -p unnisend %*)
'@ | Set-Content -Path (Join-Path $bin "unnisend.cmd") -Encoding ascii
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($userPath -notlike "*$bin*") { [Environment]::SetEnvironmentVariable("Path", "$bin;$userPath", "User") }

# 5) Prova rápida
Diga "Testando a conexão com o OmniRoute da UnniSend..."
$k = (Get-Content $EnvPerfil | Where-Object { $_ -match '^UNNISEND_OMNIROUTE_KEY=' }) -replace '^UNNISEND_OMNIROUTE_KEY=',''
try {
  $r = Invoke-WebRequest -Uri "https://omniroute.unnichat.com.br/v1/models" -Headers @{ Authorization = "Bearer $k" } -UseBasicParsing -TimeoutSec 20
  $k = $null
  if ($r.StatusCode -eq 200) { Diga "Tudo certo. Para usar, entre na pasta do projeto e rode:  unnisend chat" }
} catch {
  $k = $null
  Write-Host "A chave não foi aceita. Confira com o Israel se a chave está ativa e rode este comando de novo."; exit 1
}
