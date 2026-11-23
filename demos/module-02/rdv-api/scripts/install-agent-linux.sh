#!/usr/bin/env bash
# Installe un agent Azure Pipelines auto-hébergé sur Linux (x64 ou ARM64) et le lance en
# service systemd. ARM64 : VM Multipass, UTM ou Parallels sur un Mac Apple Silicon.
#
# Variables attendues :
#   AZP_URL        https://dev.azure.com/<organisation>
#   AZP_TOKEN      PAT avec la seule portée « Agent Pools (Read & manage) », durée courte :
#                  il ne sert qu'à l'enregistrement, l'agent utilise ensuite son propre jeton.
#   AZP_POOL       nom du pool (Santinord-Interne)
#   AGENT_VERSION  version de l'agent (v5 en novembre 2026) affichée par Azure DevOps :
#                  Organization settings > Agent pools > <pool> > New agent > Linux
# Facultatif :
#   AZP_AGENT_NAME nom de l'agent (défaut : nom de la machine)
#   DOSSIER        dossier d'installation (défaut : ~/azagent)
#
# Exemple :
#   AZP_URL=https://dev.azure.com/santinord AZP_POOL=Santinord-Interne \
#   AGENT_VERSION=5.x.y AZP_TOKEN=xxxx ./scripts/install-agent-linux.sh
set -euo pipefail

: "${AZP_URL:?AZP_URL manquant}"
: "${AZP_TOKEN:?AZP_TOKEN manquant}"
: "${AZP_POOL:?AZP_POOL manquant}"
: "${AGENT_VERSION:?AGENT_VERSION manquant, voir les commentaires en tête du script}"
AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)}"
DOSSIER="${DOSSIER:-$HOME/azagent}"

mkdir -p "$DOSSIER"
cd "$DOSSIER"

MACHINE=$(uname -m)
case "$MACHINE" in
  x86_64)        ARCHI=x64 ;;
  aarch64|arm64) ARCHI=arm64 ;;
  *) echo "Architecture non prise en charge : $MACHINE" >&2; exit 1 ;;
esac

echo "Téléchargement de l'agent $AGENT_VERSION ($ARCHI)"
curl -fsSL -o agent.tar.gz \
  "https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-${ARCHI}-${AGENT_VERSION}.tar.gz"
tar zxf agent.tar.gz
rm agent.tar.gz

echo "Installation des dépendances système (sudo)"
sudo ./bin/installdependencies.sh

echo "Enregistrement de $AZP_AGENT_NAME dans le pool $AZP_POOL"
./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --work _work \
  --replace

echo "Installation et démarrage du service systemd"
sudo ./svc.sh install "$(whoami)"
sudo ./svc.sh start
sudo ./svc.sh status

echo "Agent installé. Journaux de diagnostic : $DOSSIER/_diag"
