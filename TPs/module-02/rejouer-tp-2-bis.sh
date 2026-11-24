#!/usr/bin/env bash
# Rejoue le TP 2 bis de bout en bout, en ligne de commande : Boards, Repos, Pipelines.
#
# Usage :
#   ./rejouer-tp-2-bis.sh <organisation> <projet>
# Prérequis :
#   - az CLI avec l'extension azure-devops (az extension add -n azure-devops), puis az login
#     (ou un PAT, voir AZURE_DEVOPS_EXT_PAT) ;
#   - git et python3 ;
#   - le projet existe (processus Agile, ou hérité d'Agile), avec une itération
#     « Sprint 1 » datée et sélectionnée pour l'équipe par défaut.
#
# Le script retrouve la User Story « Prendre rendez-vous en ligne » et ses trois tâches
# (TP 1 bis) par leur titre, et les crée si elles n'existent pas. On peut aussi donner
# leurs ID : US1=400 T1=401 T2=402 T3=403 ./rejouer-tp-2-bis.sh ...
#
# Variables facultatives :
#   AZURE_DEVOPS_EXT_PAT=<PAT>  utilise un jeton d'accès personnel au lieu de az login (utile avec un
#                  compte Microsoft personnel) : User settings > Personal access tokens, portée
#                  Full access, expiration d'un jour
#   SEUL=1          une seule personne : l'auteur d'une PR peut l'approuver (défaut : 1)
#   GIT_AZ_TOKEN=1  git utilise le même jeton (az ou PAT) au lieu de Git Credential Manager
#   TRAVAIL=<dir>   dossier de travail local (défaut : ~/tp2bis-solution)
#
# Ce que le script ne fait pas, parce que c'est l'objet du TP dans l'interface : retirer
# puis remettre la tâche de la PR 1 pour voir la stratégie échouer, et regarder les
# écrans (Taskboard, Work details, zone Development).

{ # Bash lit ce bloc en entier avant de l'exécuter : modifier le fichier pendant un run ne le casse pas.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '2,25p' "$0"; exit 1; }

ICI="$(cd "$(dirname "$0")" && pwd)"
DEPART="$ICI/../../TPs/module-02/clinique-web"      
[ -d "$DEPART" ] || DEPART="$ICI/../clinique-web"     
SOLUTION="$ICI/clinique-web"
ORG="https://dev.azure.com/$1"
PROJET="$2"
DEPOT=clinique-web
TRAVAIL="${TRAVAIL:-$HOME/tp2bis-solution}"
SEUL="${SEUL:-1}"
SPRINT="$PROJET\\Sprint 1"

[ -d "$DEPART" ] && [ -d "$SOLUTION" ] || { echo "Code de départ ou solution introuvable." >&2; exit 1; }
[ ! -e "$TRAVAIL" ] || { echo "$TRAVAIL existe déjà : supprimez-le ou choisissez TRAVAIL=..." >&2; exit 1; }

etape() { printf '\n== %s\n' "$*"; }
azo() { az "$@" --org "$ORG" --only-show-errors; }                       # commandes sans projet
azp() { az "$@" --org "$ORG" --project "$PROJET" --only-show-errors; }   # commandes avec projet

# Authentification. Avec AZURE_DEVOPS_EXT_PAT défini, tout passe par ce jeton d'accès personnel (les
# commandes az devops le lisent aussi). Sinon, jeton Microsoft Entra du compte connecté par az login :
# 499b84ac-1321-427f-aa17-267ca6975798 est l'identifiant public d'Azure DevOps dans Entra ID, le même
# pour tout le monde.
if [ -n "${AZURE_DEVOPS_EXT_PAT:-}" ]; then
  AUTH="Authorization: Basic $(printf ':%s' "$AZURE_DEVOPS_EXT_PAT" | base64 | tr -d '\n')"
else
  AUTH="Authorization: Bearer $(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)"
fi
HTTP_ACCES="$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$ORG/_apis/projects?\$top=1&api-version=7.1")"
if [ "$HTTP_ACCES" != 200 ]; then
  echo "Accès refusé à $ORG (HTTP $HTTP_ACCES) : connectez-vous avec un compte de cette organisation" >&2
  echo "(az login, puis az account show pour vérifier le compte) ou fournissez AZURE_DEVOPS_EXT_PAT." >&2
  exit 1
fi
MOI="$(curl -sS -H "$AUTH" "$ORG/_apis/connectionData" | python3 -c 'import json, sys; print(json.load(sys.stdin)["authenticatedUser"]["properties"]["Account"]["$value"])')"
PROJET_URL="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$PROJET")"
PROJET_ID="$(az devops project show --project "$PROJET" --org "$ORG" --query id -o tsv)"

rest() { # rest <méthode> <chemin après le projet> [json] [content-type]
  local args=(-sS -f -X "$1" -H "$AUTH" "$ORG/$PROJET_URL/$2")
  [ -n "${3:-}" ] && args+=(-H "Content-Type: ${4:-application/json}" --data-binary "$3")
  curl "${args[@]}"
}
json() { python3 -c "import json, sys; d = json.load(sys.stdin); print($1)"; }

g() {
  if [ "${GIT_AZ_TOKEN:-0}" = 1 ]; then
    git -c credential.helper= -c "http.extraHeader=$AUTH" "$@"
  else
    git "$@"
  fi
}

# --- Éléments de travail -------------------------------------------------------------

# az boards query renvoie une liste vide, sans erreur, quand la requête contient @project
# (extension azure-devops 1.0.11) : on passe par l'API REST.
wiql() { # wiql <requête> : les ID, un par ligne
  local corps; corps="$(python3 -c 'import json, sys; print(json.dumps({"query": sys.argv[1]}))' "$1")"
  rest POST "_apis/wit/wiql?api-version=7.1" "$corps" | json "'\\n'.join(str(w['id']) for w in d['workItems'])"
}
trouver() { # trouver <type> <titre> : ID ou rien
  local q="'"
  local titre="${2//$q/$q$q}"
  wiql "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = '$1' AND [System.Title] = '$titre'" | head -1
}
creer() { # creer <type> <titre> : ID
  azp boards work-item create --type "$1" --title "$2" --iteration "$SPRINT" --assigned-to "$MOI" --query id -o tsv
}
enfant() { azo boards work-item relation add --id "$1" --relation-type parent --target-id "$2" -o none; }
etat() { azo boards work-item update --id "$1" --state "$2" -o none; }
etat_de() { azo boards work-item show --id "$1" --query 'fields."System.State"' -o tsv; }
attendre_etat() { # attendre_etat <id> <état>
  for _ in $(seq 1 30); do [ "$(etat_de "$1")" = "$2" ] && return 0; sleep 5; done
  echo "  #$1 n'est pas passé à $2 (état : $(etat_de "$1"))" >&2; return 1
}
tache() { # tache <variable> <titre> : retrouve ou crée la tâche, enfant de US1
  local id="${!1:-}"
  [ -n "$id" ] || id="$(trouver Task "$2")"
  if [ -z "$id" ]; then id="$(creer Task "$2")"; enfant "$id" "$US1"; fi
  printf -v "$1" '%s' "$id"
}

# --- Repos ---------------------------------------------------------------------------

lier_branche() { # lier_branche <id élément> <branche> : ce que fait « Create branch » dans Boards
  local nom; nom="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$2")"
  rest PATCH "_apis/wit/workitems/$1?api-version=7.1" \
    "[{\"op\":\"add\",\"path\":\"/relations/-\",\"value\":{\"rel\":\"ArtifactLink\",\"url\":\"vstfs:///Git/Ref/$PROJET_ID%2F$RID%2FGB${nom//%/%25}\",\"attributes\":{\"name\":\"Branch\"}}}]" \
    application/json-patch+json > /dev/null
}
branche_depuis() { # branche_depuis <id élément> <branche>
  local sha; sha="$(azp repos ref list -r "$DEPOT" --filter heads/main --query "[0].objectId" -o tsv)"
  azp repos ref create -r "$DEPOT" --name "heads/$2" --object-id "$sha" -o none
  lier_branche "$1" "$2"
  g fetch -q
  git switch -q "$2"
}
pr_statut() { azo repos pr show --id "$1" --query status -o tsv; }
attendre_pr() { # attendre_pr <id> : jusqu'à la fusion
  for _ in $(seq 1 60); do [ "$(pr_statut "$1")" = completed ] && return 0; sleep 10; done
  echo "  la PR $1 n'est pas terminée" >&2; return 1
}
build_de_la_pr() { azo repos pr policy list --id "$1" --query "[?configuration.type.displayName=='Build'].status | [0]" -o tsv; }
attendre_build_pr() { # attendre_build_pr <id> : approved ou rejected
  local s
  for _ in $(seq 1 60); do
    s="$(build_de_la_pr "$1")"
    case "$s" in approved|rejected) echo "$s"; return 0 ;; esac
    sleep 10
  done
  echo "timeout"
}
attendre_push_dans_pr() { # attendre_push_dans_pr <id> : la PR voit le dernier commit local
  local local_sha; local_sha="$(git rev-parse HEAD)"
  for _ in $(seq 1 30); do
    [ "$(azo repos pr show --id "$1" --query lastMergeSourceCommit.commitId -o tsv)" = "$local_sha" ] && return 0
    sleep 3
  done
}

# =====================================================================================

etape "Étape 1 : le sprint de la semaine"
US1="${US1:-$(trouver 'User Story' 'Prendre rendez-vous en ligne')}"
[ -n "$US1" ] || US1="$(creer 'User Story' 'Prendre rendez-vous en ligne')"
tache T1 "Créer la maquette de l'interface utilisateur pour la prise de rendez-vous"
tache T2 "Développer l'interface utilisateur selon la maquette approuvée"
tache T3 "Intégrer l'API de calendrier pour afficher les disponibilités des médecins"
tache T0 "Rédiger le README du dépôt clinique-web"
tache T4 "Écrire les tests unitaires du calcul des créneaux"
tache T5 "Mettre en place l'intégration continue du dépôt"
etat "$US1" New
for spec in "T0 Documentation 1" "T1 Design 3" "T2 Development 4" "T3 Development 4" "T4 Testing 2" "T5 Deployment 2"; do
  set -- $spec
  azo boards work-item update --id "${!1}" --state New --assigned-to "$MOI" --iteration "$SPRINT" \
    --fields "Microsoft.VSTS.Common.Activity=$2" "Microsoft.VSTS.Scheduling.RemainingWork=$3" -o none
done
printf '  US1=%s T0=%s T1=%s T2=%s T3=%s T4=%s T5=%s\n' "$US1" "$T0" "$T1" "$T2" "$T3" "$T4" "$T5"

etape "Étape 2 : le dépôt et le code de départ"
RID="$(azp repos show -r "$DEPOT" --query id -o tsv 2>/dev/null || true)"
[ -n "$RID" ] || RID="$(azp repos create --name "$DEPOT" --query id -o tsv)"
URL="$(azp repos show -r "$DEPOT" --query remoteUrl -o tsv)"
cp -R "$DEPART" "$TRAVAIL"
cd "$TRAVAIL"
git init -q -b main
git add .
git commit -q -m "Code de départ de la page de prise de rendez-vous"
git remote add origin "$URL"
g push -q -u origin main

etape "Étape 3 : une tâche fermée par un commit (T0)"
etat "$T0" Active
cp "$SOLUTION/README.md" README.md
git commit -q -am "Ajoute les conventions de l'équipe au README. Fixes #$T0"
g push -q
attendre_etat "$T0" Closed && echo "  T0 #$T0 : Closed"

etape "Étape 4 : configurer le dépôt et protéger main"
if [ "$SEUL" = 1 ]; then AUTO=true; else AUTO=false; fi
azp repos policy approver-count create --repository-id "$RID" --branch main --minimum-approver-count 1 \
  --creator-vote-counts "$AUTO" --allow-downvotes false --reset-on-source-push true --blocking true --enabled true -o none
azp repos policy work-item-linking create --repository-id "$RID" --branch main --blocking true --enabled true -o none
azp repos policy comment-required create --repository-id "$RID" --branch main --blocking true --enabled true -o none
azp repos policy merge-strategy create --repository-id "$RID" --branch main --allow-squash true --blocking true --enabled true -o none
echo "  4 stratégies sur main"

etape "Étape 5 : l'intégration continue (T5)"
etat "$T5" Active
# --skip-first-run : sans lui, la commande renvoie le run et non le pipeline
PIPE="$(azp pipelines create --name clinique-ci --repository "$DEPOT" --repository-type tfsgit --branch main \
  --yml-path azure-pipelines.yml --skip-first-run --query id -o tsv)"
RUN="$(azp pipelines run --id "$PIPE" --branch main --query id -o tsv)"
for _ in $(seq 1 60); do
  [ "$(azp pipelines runs show --id "$RUN" --query status -o tsv)" = completed ] && break
  sleep 10
done
echo "  run $RUN : $(azp pipelines runs show --id "$RUN" --query result -o tsv)"
azp repos policy build create --repository-id "$RID" --branch main --build-definition-id "$PIPE" \
  --display-name clinique-ci --queue-on-source-update-only false --manual-queue-only false --valid-duration 0 \
  --blocking true --enabled true -o none
azo boards work-item update --id "$T5" --discussion "Pipeline clinique-ci en place : $ORG/$PROJET_URL/_build/results?buildId=$RUN" -o none
etat "$T5" Closed
echo "  stratégie Build validation ajoutée ; T5 #$T5 : Closed"

etape "Étape 6 : une branche née d'une tâche (T1)"
etat "$US1" Active
etat "$T1" Active
branche_depuis "$T1" "feature/$T1-maquette"
cp "$SOLUTION/index.html" index.html
git commit -q -am "Ajoute le formulaire de prise de rendez-vous #$T1"
g push -q

etape "Étape 7 : première pull request, la maquette"
PR1="$(azp repos pr create -r "$DEPOT" -s "feature/$T1-maquette" -t main \
  --title "Maquette du formulaire de prise de rendez-vous" \
  --description "Ajoute le formulaire de prise de rendez-vous." "" "Pour tester : ouvrir index.html, choisir un médecin." \
  --work-items "$T1" --query pullRequestId -o tsv)"
LIGNE="$(grep -n '<textarea' index.html | cut -d: -f1)"
FIL="$(rest POST "_apis/git/repositories/$RID/pullRequests/$PR1/threads?api-version=7.1" \
  "{\"comments\":[{\"content\":\"Le motif doit-il être obligatoire ?\",\"commentType\":1}],\"status\":\"active\",\"threadContext\":{\"filePath\":\"/index.html\",\"rightFileStart\":{\"line\":$LIGNE,\"offset\":1},\"rightFileEnd\":{\"line\":$LIGNE,\"offset\":2}}}" | json "d['id']")"
rest POST "_apis/git/repositories/$RID/pullRequests/$PR1/threads/$FIL/comments?api-version=7.1" \
  '{"content":"Facultatif pour cette première version.","parentCommentId":1,"commentType":1}' > /dev/null
rest PATCH "_apis/git/repositories/$RID/pullRequests/$PR1/threads/$FIL?api-version=7.1" '{"status":"fixed"}' > /dev/null
azo repos pr update --id "$PR1" --auto-complete true --squash true --delete-source-branch true --transition-work-items true -o none
azo repos pr set-vote --id "$PR1" --vote approve -o none
attendre_pr "$PR1"
attendre_etat "$T1" Closed && echo "  PR $PR1 fusionnée ; T1 #$T1 : Closed"
git switch -q main
g pull -q --prune
git branch -q -D "feature/$T1-maquette"

etape "Étape 8 : deuxième pull request, les tests d'abord"
for t in "$T2" "$T3" "$T4"; do etat "$t" Active; done
branche_depuis "$US1" "feature/$US1-creneaux-libres"
cp "$SOLUTION/tests/creneaux.test.js" tests/creneaux.test.js
git commit -q -am "Ajoute les tests des créneaux réservés #$T4"
g push -q -u origin "feature/$US1-creneaux-libres"
PR2="$(azp repos pr create -r "$DEPOT" -s "feature/$US1-creneaux-libres" -t main \
  --title "Ne proposer que les créneaux libres" \
  --description "Les créneaux déjà réservés ne sont plus proposés au patient." "" \
    "Closed:#$T2" "Closed:#$T3" "Closed:#$T4" "Resolved:#$US1" \
  --work-items "$T2" "$T3" "$T4" "$US1" --query pullRequestId -o tsv)"
echo "  PR $PR2, build de validation : $(attendre_build_pr "$PR2") (attendu : rejected)"

etape "Étape 9 : le code, puis la fusion"
cp "$SOLUTION/js/creneaux.js" js/creneaux.js
git commit -q -am "Retire les créneaux déjà réservés #$T3"
cp "$SOLUTION/js/app.js" js/app.js
git commit -q -am "Affiche le nombre de créneaux libres #$T2"
g push -q
attendre_push_dans_pr "$PR2"
for _ in $(seq 1 20); do # le build rouge précédent doit laisser la place au nouveau run
  case "$(build_de_la_pr "$PR2")" in queued|running) break ;; esac
  sleep 3
done
azo repos pr update --id "$PR2" --auto-complete true --squash true --delete-source-branch true --transition-work-items false -o none
azo repos pr set-vote --id "$PR2" --vote approve -o none
echo "  build de validation : $(attendre_build_pr "$PR2") (attendu : approved)"
attendre_pr "$PR2"
attendre_etat "$US1" Resolved && echo "  PR $PR2 fusionnée ; US1 #$US1 : Resolved"
git switch -q main
g pull -q --prune
git branch -q -D "feature/$US1-creneaux-libres"

etape "Étape 10 : la traçabilité"
requete() { # requete <nom> <wiql>
  local corps id; corps="$(python3 -c 'import json, sys; print(json.dumps({"name": sys.argv[1], "wiql": sys.argv[2]}))' "$1" "$2")"
  rest POST "_apis/wit/queries/Shared%20Queries?api-version=7.1" "$corps" > /dev/null 2>&1 || echo "  (requête « $1 » déjà présente)"
  echo "  $1 :"
  for id in $(wiql "$2"); do
    printf '    #%s %s\n' "$id" "$(azo boards work-item show --id "$id" --query 'fields."System.Title"' -o tsv)"
  done
}
requete "Clinique - Tâches liées au code" \
  "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = 'Task' AND [System.IterationPath] = '$SPRINT' AND [System.ExternalLinkCount] > 0"
requete "Clinique - Fermées sans trace" \
  "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = 'Task' AND [System.State] = 'Closed' AND [System.ExternalLinkCount] = 0"

etape "Étape 11 : la recette de John"
if azo boards work-item update --id "$US1" --state "En attente de validation" -o none 2>/dev/null; then
  echo "  US1 #$US1 : En attente de validation"
else
  etat "$US1" Closed
  echo "  US1 #$US1 : Closed (pas d'état « En attente de validation » dans ce processus)"
fi

etape "État final"
for v in US1 T0 T1 T2 T3 T4 T5; do printf '  %-4s #%-6s %s\n' "$v" "${!v}" "$(etat_de "${!v}")"; done
echo "  main : $(git log --oneline | wc -l | tr -d ' ') commits"
git log --oneline | sed 's/^/    /'
exit
}
