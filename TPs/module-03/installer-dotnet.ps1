<#
Installe le SDK .NET s'il manque (Windows).

Usage, depuis une invite PowerShell ouverte dans le dossier du script :
  powershell -ExecutionPolicy Bypass -File .\installer-dotnet.ps1              # SDK .NET 10, celui du fil rouge rdv-api
  powershell -ExecutionPolicy Bypass -File .\installer-dotnet.ps1 -Canal 8.0   # un autre canal

Si dotnet répond déjà avec un SDK de ce canal, le script s'arrête sans rien changer. Sinon, il installe
le SDK avec le script officiel de Microsoft (https://dot.net/v1/dotnet-install.ps1) :
  - en administrateur : dans C:\Program Files\dotnet, à côté des SDK déjà présents (Visual Studio les voit) ;
  - sans droits : dans %LOCALAPPDATA%\Microsoft\dotnet, ajouté au PATH de l'utilisateur.

Sous macOS, Linux ou WSL : installer-dotnet.sh.
#>
param([string]$Canal = "10.0")

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -eq "Core" -and -not $IsWindows) {
  Write-Host "Hors Windows, utilisez installer-dotnet.sh."
  exit 1
}
# Windows PowerShell 5.1 ne négocie pas toujours TLS 1.2 tout seul
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$env:DOTNET_NOLOGO = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"

function Get-Sdks([string]$Dotnet) {
  # Les SDK du canal demandé que connaît cet exécutable dotnet
  try {
    @(& $Dotnet --list-sdks 2>$null | ForEach-Object { ($_ -split " ")[0] } | Where-Object { $_ -like "$Canal.*" })
  } catch {
    @()
  }
}

# 1. Déjà là ?
$commande = Get-Command dotnet -ErrorAction SilentlyContinue
if ($commande) {
  $sdks = Get-Sdks $commande.Source
  if ($sdks.Count -gt 0) {
    Write-Host "SDK .NET $Canal déjà installé : $($sdks -join ', ') ($($commande.Source))"
    exit 0
  }
}

# 2. Où installer : à côté des autres SDK si on est administrateur, sinon dans le profil
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
$machine = Join-Path $env:ProgramFiles "dotnet"
if ($admin) { $dossier = $machine } else { $dossier = Join-Path $env:LOCALAPPDATA "Microsoft\dotnet" }
$dotnet = Join-Path $dossier "dotnet.exe"

if ((Test-Path $dotnet) -and (Get-Sdks $dotnet).Count -gt 0) {
  Write-Host "SDK .NET $Canal présent dans $dossier, mais pas dans le PATH"
} else {
  $installeur = Join-Path ([IO.Path]::GetTempPath()) "dotnet-install.ps1"
  Invoke-WebRequest "https://dot.net/v1/dotnet-install.ps1" -OutFile $installeur -UseBasicParsing
  Write-Host "Installation du SDK .NET $Canal dans $dossier..."
  & $installeur -Channel $Canal -InstallDir $dossier -NoPath
  Remove-Item $installeur
}

# 3. Le PATH : celui de la machine en administrateur, celui de l'utilisateur sinon
if ($admin) { $portee = "Machine" } else { $portee = "User" }
$chemin = [Environment]::GetEnvironmentVariable("Path", $portee)
$elements = @($chemin -split ";" | Where-Object { $_ })
if ($elements -notcontains $dossier) {
  [Environment]::SetEnvironmentVariable("Path", (@($dossier) + $elements) -join ";", $portee)
  Write-Host "$dossier ajouté au PATH ($portee)"
}
$env:Path = "$dossier;$env:Path"

# 4. Vérification
$version = & $dotnet --version
Write-Host "SDK .NET $version prêt : $dotnet"
Write-Host "Ouvrez une nouvelle invite de commandes, puis : dotnet --version"
if (-not $admin -and (Test-Path (Join-Path $machine "dotnet.exe"))) {
  Write-Host ""
  Write-Host "Attention : $machine existe déjà, et le PATH de la machine passe avant celui de l'utilisateur."
  Write-Host "Dans les nouvelles invites, 'dotnet' sera celui de $machine, qui ne voit pas ce SDK."
  Write-Host "Relancez ce script en administrateur pour installer le SDK à côté des autres."
}
