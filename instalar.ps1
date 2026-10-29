# Instalador do perfil Hermes da UnniSend para Windows (PowerShell). Um comando, o resto é automático.
# Nenhuma chave entra neste script nem no repositório.
$ErrorActionPreference = "Stop"
# Rodado por "irm ... | iex": nunca usar exit aqui (fecha a janela do PowerShell antes de a pessoa ler a mensagem).
$Repo = "github.com/UnniSend/hermes-perfil-unnisend"
$Perfil = "unnisend"
# No Windows o Hermes guarda tudo em %LOCALAPPDATA%\hermes (não em ~\.hermes). HERMES_HOME, se definido, manda.
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "hermes" } else { Join-Path $HOME "AppData\Local\hermes" }
$EnvPerfil = Join-Path $HermesHome "profiles\$Perfil\.env"

function Diga($t) { Write-Host "`n$t" -ForegroundColor Cyan }

# 1) Hermes
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
  Diga "Instalando o Hermes (leva alguns minutos)..."
  Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1) } -NonInteractive"
  $env:Path = "$HOME\.local\bin;" + [Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path
}
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
  Write-Host "O Hermes não ficou disponível. Feche e abra o PowerShell e rode este comando de novo." -ForegroundColor Yellow; return
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
# Chave na linha do comando sempre vale (substitui uma chave antiga ou colada errado).
if (-not $temChave -or $env:UNNISEND_OMNIROUTE_KEY) {
  if ($env:UNNISEND_OMNIROUTE_KEY) {
    $chave = $env:UNNISEND_OMNIROUTE_KEY.Trim()
  } else {
    Diga "Cole a sua chave pessoal do OmniRoute da UnniSend (o Israel te enviou; começa com sk-)."
    $segura = Read-Host -Prompt "Chave" -AsSecureString
    $chave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura))
  }
  $chave = "$chave".Trim()
  if (-not $chave.StartsWith("sk-")) { Write-Host "Isso não parece uma chave (precisa começar com sk-). Rode este comando de novo e cole a chave inteira." -ForegroundColor Yellow; return }
  New-Item -ItemType Directory -Force -Path (Split-Path $EnvPerfil) | Out-Null
  $linhas = @()
  if (Test-Path $EnvPerfil) { $linhas = Get-Content $EnvPerfil | Where-Object { $_ -notmatch '^UNNISEND_OMNIROUTE_KEY=' } }
  $linhas += "UNNISEND_OMNIROUTE_KEY=$chave"
  Set-Content -Path $EnvPerfil -Value $linhas -Encoding ascii
  $chave = $null
}

# 3b) Memoria da empresa: o plugin hindsight le a chave em HINDSIGHT_API_KEY e o .env nao expande ${...};
# gravamos a MESMA chave pessoal nessa variavel. Nada novo entra no computador.
$chaveAtual = ((Get-Content $EnvPerfil | Where-Object { $_ -match '^UNNISEND_OMNIROUTE_KEY=' }) -replace '^UNNISEND_OMNIROUTE_KEY=','')
$linhas = Get-Content $EnvPerfil | Where-Object { $_ -notmatch '^HINDSIGHT_API_KEY=' }
$linhas += "HINDSIGHT_API_KEY=$chaveAtual"
Set-Content -Path $EnvPerfil -Value $linhas -Encoding ascii
$chaveAtual = $null

# 3c) Plugin de memoria (uma vez; o perfil ja traz a configuracao que aponta para o porteiro da empresa)
if (-not (Test-Path (Join-Path $HermesHome "profiles\$Perfil\plugins\hindsight"))) {
  Diga "Instalando o plugin de memoria da empresa..."
  try { hermes -p $Perfil plugins install hindsight | Out-Null } catch {}
}
try { hermes -p $Perfil plugins enable hindsight | Out-Null } catch {}

# 4) Atalho "unnisend" que atualiza o perfil sozinho e abre o chat
$bin = Join-Path $HOME ".local\bin"; New-Item -ItemType Directory -Force -Path $bin | Out-Null
@'
@echo off
hermes profile update unnisend -y --force-config >nul 2>&1
if "%~1"=="torriani" (shift & goto torriani)
if "%~1"=="" (hermes -p unnisend chat) else (hermes -p unnisend %*)
goto :eof
:torriani
call "%~dp0torriani.cmd" %1 %2
'@ | Set-Content -Path (Join-Path $bin "unnisend.cmd") -Encoding ascii
# torriani send | unni: o kit roda no Git Bash (o mesmo que o Hermes usa para o terminal no Windows).
@'
@echo off
setlocal
hermes profile update unnisend -y --force-config >nul 2>&1
set "BASH="
for %%G in ("%ProgramFiles%\Git\bin\bash.exe" "%ProgramFiles(x86)%\Git\bin\bash.exe" "%LOCALAPPDATA%\Programs\Git\bin\bash.exe") do if not defined BASH if exist %%G set "BASH=%%~G"
if not defined BASH for /f "delims=" %%G in ('where bash.exe 2^>nul') do if not defined BASH set "BASH=%%G"
if not defined BASH for /f "delims=" %%G in ('dir /b /s "%LOCALAPPDATA%\hermes\tools\*bash.exe" 2^>nul') do if not defined BASH set "BASH=%%G"
if not defined BASH (echo Nao achei o Git Bash neste computador. Instale o Git for Windows ^(git-scm.com^) e rode de novo. & exit /b 1)
if defined HERMES_HOME set "HERMES_HOME_SET=1"
set "HH=%HERMES_HOME%"
if not defined HH set "HH=%LOCALAPPDATA%\hermes"
"%BASH%" -lc "exec bash \"$(cygpath -u '%HH%')/profiles/unnisend/scripts/torriani.sh\" %1"
'@ | Set-Content -Path (Join-Path $bin "torriani.cmd") -Encoding ascii
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($userPath -notlike "*$bin*") { [Environment]::SetEnvironmentVariable("Path", "$bin;$userPath", "User") }

# 5) Prova rápida
Diga "Testando a conexão com o OmniRoute da UnniSend..."
$k = (Get-Content $EnvPerfil | Where-Object { $_ -match '^UNNISEND_OMNIROUTE_KEY=' }) -replace '^UNNISEND_OMNIROUTE_KEY=',''
try {
  $r = Invoke-WebRequest -Uri "https://omniroute.unnichat.com.br/v1/models" -Headers @{ Authorization = "Bearer $k" } -UseBasicParsing -TimeoutSec 20
  $k = $null
  if ($r.StatusCode -eq 200) { Diga "Tudo certo. Feche e abra o PowerShell de novo. Kit do Torriani: torriani send (SendFlow) ou torriani unni (UnniChat). Assistente da empresa na pasta atual: unnisend" }
} catch {
  $k = $null
  # Tira a chave recusada do perfil: senão a próxima instalação acha que já tem chave e não pergunta de novo.
  $linhas = Get-Content $EnvPerfil | Where-Object { $_ -notmatch '^(UNNISEND_OMNIROUTE_KEY|HINDSIGHT_API_KEY)=' }
  Set-Content -Path $EnvPerfil -Value $linhas -Encoding ascii
  Write-Host "A chave não foi aceita. Confira com o Israel se a chave está certa e rode este comando de novo (ele vai pedir a chave outra vez)." -ForegroundColor Yellow; return
}
