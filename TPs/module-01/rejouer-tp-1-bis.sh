#!/usr/bin/env bash
# Rejoue le TP 1 bis (la clinique médicale) de bout en bout, en ligne de commande :
# projet, sprints, wiki, membres, processus hérité, nouvel état et sa colonne, Story Points
# par défaut, type Documentation, epic, feature, stories, tâches, étiquettes, cycle de vie,
# requêtes, capacité, plan de livraison et commentaire.
#
# Usage :
#   ./rejouer-tp-1-bis.sh <organisation> <Prénom>
#   ./rejouer-tp-1-bis.sh utopios-formation Ihab      # projet Clinique-Ihab, processus AgileCustomIhab
#
# Prérequis :
#   - az CLI avec l'extension azure-devops (az extension add -n azure-devops), puis az login
#     (ou un PAT, voir AZURE_DEVOPS_EXT_PAT) ;
#   - python3 et curl ;
#   - être Project Collection Administrator de l'organisation (processus, champs, membres) ;
#   - ni le projet Clinique-<Prénom> ni le processus AgileCustom<Prénom> ne doivent exister.
#
# Variables facultatives :
#   AZURE_DEVOPS_EXT_PAT=<PAT>  utilise un jeton d'accès personnel au lieu de az login (utile avec un
#                  compte Microsoft personnel) : User settings > Personal access tokens, portée
#                  Full access, expiration d'un jour
#   JIM=<adresse> JOHN=<adresse>   ajoute ces personnes à l'organisation (sans courriel d'invitation),
#                                  au groupe Contributors du projet et à l'équipe. Sans elles, leurs
#                                  tâches vous sont assignées et le commentaire de la section M ne
#                                  mentionne personne.
#   ACCES=express|stakeholder      niveau d'accès des personnes ajoutées (express = Basic ; défaut express)
#   CHAMP_ECHEANCE, CHAMP_TYPE     noms des deux champs créés (défaut « Échéance » et
#                                  « Type de documentation ») ; un champ du même nom déjà présent
#                                  dans l'organisation est réutilisé, comme dans le TP
#
# Reste à faire à la main (pas d'API publique) : Overview > Summary > About this project > Wiki.

{ # Bash lit ce bloc en entier avant de l'exécuter : modifier le fichier pendant un run ne le casse pas.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '2,30p' "$0"; exit 1; }

ORG="https://dev.azure.com/$1"
PRENOM="$2"
PROJET="Clinique-$PRENOM"
PROCESSUS="AgileCustom$PRENOM"
EQUIPE="$PROJET Team"
ACCES="${ACCES:-express}"
CHAMP_ECHEANCE="${CHAMP_ECHEANCE:-Échéance}"
CHAMP_TYPE="${CHAMP_TYPE:-Type de documentation}"
AGILE=adcc42ab-9882-485e-a3ed-7678f01f66bc
OBJECTIF="Permettre aux patients de prendre et de gérer leurs rendez-vous médicaux en ligne."

etape() { printf '\n== %s\n' "$*"; }
azo() { az "$@" --org "$ORG" --only-show-errors; }
azp() { az "$@" --org "$ORG" --project "$PROJET" --only-show-errors; }

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
url() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
PROJET_URL="$(url "$PROJET")"
EQUIPE_URL="$(url "$EQUIPE")"

rest() { # rest <méthode> <chemin après l'organisation> [json] [content-type]
  if [ -n "${3:-}" ]; then
    curl -sS -X "$1" -H "$AUTH" -H "Content-Type: ${4:-application/json}" "$ORG/$2" --data-binary "$3"
  else
    curl -sS -X "$1" -H "$AUTH" "$ORG/$2"
  fi
}
py() { python3 -c "import json, sys; d = json.loads(sys.stdin.buffer.read().decode('utf-8-sig') or 'null'); $1"; }
ok() { py "print(d.get('message')) if isinstance(d, dict) and d.get('message') else None" >&2; }   # affiche une erreur éventuelle
jarg() { python3 -c 'import json, sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2])), ensure_ascii=False))' "$@"; }

wiql() { # wiql <requête> : les ID, un par ligne
  rest POST "$PROJET_URL/_apis/wit/wiql?api-version=7.1" "$(python3 -c 'import json, sys; print(json.dumps({"query": sys.argv[1]}))' "$1")" \
    | py "print('\n'.join(str(w['id']) for w in d['workItems']))"
}

# --- Vérifications -------------------------------------------------------------------

if az devops project show --project "$PROJET" --org "$ORG" -o none 2>/dev/null; then
  echo "Le projet $PROJET existe déjà : supprimez-le ou choisissez un autre prénom." >&2; exit 1
fi
if rest GET "_apis/work/processes?api-version=7.1" | py "sys.exit(0 if any(p['name'].lower() == '$PROCESSUS'.lower() for p in d['value']) else 1)"; then
  echo "Le processus $PROCESSUS existe déjà : supprimez-le ou choisissez un autre prénom." >&2; exit 1
fi

# =====================================================================================

etape "A : le projet $PROJET"
azo devops project create --name "$PROJET" --description "$OBJECTIF" --process Agile \
  --source-control git --visibility private -o none
PROJET_ID="$(azo devops project show --project "$PROJET" --query id -o tsv)"
EQUIPE_ID="$(azp devops team show --team "$EQUIPE" --query id -o tsv)"
echo "  projet $PROJET_ID, équipe « $EQUIPE »"

etape "C : les trois sprints et le niveau Epics"
SPRINTS=("Sprint 1|2026-11-23|2026-12-04" "Sprint 2|2026-12-07|2026-12-18" "Sprint 3|2026-12-21|2027-01-01")
for i in 1 2 3; do
  IFS='|' read -r nom debut fin <<< "${SPRINTS[$((i - 1))]}"
  azp boards iteration project update --path "\\$PROJET\\Iteration\\Iteration $i" --name "$nom" \
    --start-date "$debut" --finish-date "$fin" -o none
  if ! azp boards iteration team list --team "$EQUIPE" --query "[].name" -o tsv | grep -qx "$nom"; then
    ID_IT="$(azp boards iteration project show --path "\\$PROJET\\Iteration\\$nom" --query identifier -o tsv)"
    azp boards iteration team add --id "$ID_IT" --team "$EQUIPE" -o none
  fi
  echo "  $nom : du $debut au $fin"
done
rest PATCH "$PROJET_URL/$EQUIPE_URL/_apis/work/teamsettings?api-version=7.1" \
  '{"backlogVisibilities":{"Microsoft.EpicCategory":true,"Microsoft.FeatureCategory":true,"Microsoft.RequirementCategory":true}}' | ok
echo "  niveau Epics coché"

etape "D : le wiki et la page Accueil"
ACCUEIL="$(mktemp)"
cat > "$ACCUEIL" <<EOF
# Clinique : prise de rendez-vous en ligne

## Contexte

| | |
|---|---|
| Début | lundi 23 novembre 2026 |
| Fin prévue | vendredi 19 février 2027 |
| Objectif | permettre aux patients de prendre et de gérer leurs rendez-vous médicaux en ligne |

## Équipe

| Membre | Rôle |
|---|---|
| $PRENOM | Développeur, administrateur du projet |
| Jim | Développeur FullStack |
| John | Testeur QA |

## Sprints

| Sprint | Du | Au | Objectif |
|---|---|---|---|
| Sprint 1 | 23/11/2026 | 04/12/2026 | prise de rendez-vous en ligne |
| Sprint 2 | 07/12/2026 | 18/12/2026 | rappels par courriel |
| Sprint 3 | 21/12/2026 | 01/01/2027 | tests de la gestion des rendez-vous |
EOF
azp devops wiki create --name "$PROJET.wiki" -o none
azp devops wiki page create --wiki "$PROJET.wiki" --path "Accueil" --file-path "$ACCUEIL" --encoding utf-8 -o none
rm -f "$ACCUEIL"
echo "  wiki « $PROJET.wiki », page Accueil ; description du projet posée en A"
echo "  à la main : Overview > Summary > About this project > Wiki"

etape "E : les membres"
GROUPES="$(azp devops security group list --query "graphGroups[].[displayName, descriptor]" -o tsv)"
G_CONTRIB="$(printf '%s\n' "$GROUPES" | awk -F'\t' '$1 == "Contributors" { print $2 }')"
G_EQUIPE="$(printf '%s\n' "$GROUPES" | awk -F'\t' -v e="$EQUIPE" '$1 == e { print $2 }')"
ajouter() { # ajouter <adresse>
  azo devops user show --user "$1" -o none 2>/dev/null \
    || azo devops user add --email-id "$1" --license-type "$ACCES" --send-email-invite false -o none
  local u; u="$(azo devops user show --user "$1" --query user.descriptor -o tsv)"
  azo devops security group membership add --group-id "$G_CONTRIB" --member-id "$u" -o none 2>/dev/null || true
  azo devops security group membership add --group-id "$G_EQUIPE" --member-id "$u" -o none 2>/dev/null || true
  echo "  $1 : organisation ($ACCES), Contributors, équipe"
}
[ -n "${JIM:-}" ] && ajouter "$JIM" || echo "  JIM non fourni : ses tâches vous seront assignées"
[ -n "${JOHN:-}" ] && ajouter "$JOHN" || echo "  JOHN non fourni : ses tâches vous seront assignées"
A_VOUS="$MOI"
A_JIM="${JIM:-${JOHN:-$MOI}}"     # TP, section E : sans Jim, ses tâches vont au voisin
A_JOHN="${JOHN:-$MOI}"

etape "F : le processus $PROCESSUS"
PROC="$(rest POST "_apis/work/processes?api-version=7.1" \
  "$(jarg name "$PROCESSUS" parentProcessTypeId "$AGILE" description "TP 1 bis, $PROJET")" | py "print(d['typeId'])")"
rest POST "$PROJET_URL/_apis/wit/projectprocessmigration?api-version=7.1-preview.1" "{\"typeId\":\"$PROC\"}" | ok
echo "  processus $PROC ; $PROJET basculé dessus"
P="_apis/work/processes/$PROC"

etape "G.1 : l'état « En attente de validation » et la colonne « Attente client »"
US_REF="$(rest POST "$P/workitemtypes?api-version=7.1" \
  '{"inheritsFrom":"Microsoft.VSTS.WorkItemTypes.UserStory","name":"User Story","color":"009CCC","icon":"icon_book","isDisabled":false}' \
  | py "print(d['referenceName'])")"
rest POST "$P/workitemtypes/$US_REF/states?api-version=7.1" \
  '{"name":"En attente de validation","stateCategory":"Resolved","color":"ff9d00"}' | ok
COLONNES="$(rest GET "$PROJET_URL/$EQUIPE_URL/_apis/work/boards/Stories/columns?api-version=7.1")"
NOUVELLES="$(printf '%s' "$COLONNES" | python3 -c '
import json, sys
cols = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))["value"]
etat = "En attente de validation"
# Sur un tableau jamais personnalisé, Azure DevOps a déjà créé une colonne pour le nouvel état :
# on la renomme (en gardant son identifiant) au lieu d en ajouter une seconde.
col = next((c for c in cols if c["columnType"] == "inProgress" and c["stateMappings"].get("User Story") == etat), None)
if col:
    cols.remove(col)
    col["name"] = "Attente client"
else:
    sortie = next(i for i, c in enumerate(cols) if c["columnType"] == "outgoing")
    avant = cols[sortie - 1]["stateMappings"]
    col = {"name": "Attente client", "itemLimit": 0, "columnType": "inProgress", "isSplit": False, "description": "",
           "stateMappings": {t: (etat if t == "User Story" else e) for t, e in avant.items()}}
cols.insert(next(i for i, c in enumerate(cols) if c["columnType"] == "outgoing"), col)
print(json.dumps(cols, ensure_ascii=False))')"
rest PUT "$PROJET_URL/$EQUIPE_URL/_apis/work/boards/Stories/columns?api-version=7.1" "$NOUVELLES" | ok
echo "  colonnes : $(rest GET "$PROJET_URL/$EQUIPE_URL/_apis/work/boards/Stories/columns?api-version=7.1" | py "print(', '.join(c['name'] for c in d['value']))")"

etape "G.2 : 5 Story Points par défaut"
rest PATCH "$P/workitemtypes/$US_REF/fields/Microsoft.VSTS.Scheduling.StoryPoints?api-version=7.1" '{"defaultValue":"5"}' | ok
echo "  Story Points : 5 par défaut"

etape "G.3 : le type Documentation"
DOC_REF="$(rest POST "$P/workitemtypes?api-version=7.1" \
  '{"name":"Documentation","description":"Documentation technique du produit","color":"339947","icon":"icon_book","isDisabled":false}' \
  | py "print(d['referenceName'])")"
for s in "Nouveau|Proposed|b2b2b2" "En cours|InProgress|007acc" "En révision|Resolved|ff9d00" "Complété|Completed|339933"; do
  IFS='|' read -r nom cat couleur <<< "$s"
  rest POST "$P/workitemtypes/$DOC_REF/states?api-version=7.1" "$(jarg name "$nom" stateCategory "$cat" color "$couleur")" | ok
done
for nom in New Active; do  # Closed disparaît seul : Complété prend la seule place de la catégorie Completed
  id="$(rest GET "$P/workitemtypes/$DOC_REF/states?api-version=7.1" | py "print(next((s['id'] for s in d['value'] if s['name'] == '$nom'), ''))")"
  [ -z "$id" ] || rest DELETE "$P/workitemtypes/$DOC_REF/states/$id?api-version=7.1" > /dev/null
done
echo "  états : $(rest GET "$P/workitemtypes/$DOC_REF/states?api-version=7.1" | py "print(', '.join(s['name'] for s in d['value']))")"

champ() { # champ <nom> : référence du champ de ce nom dans l'organisation (casse ignorée), ou rien
  rest GET "_apis/wit/fields?api-version=7.1" | python3 -c '
import json, sys
nom = sys.argv[1].lower()
d = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
print(next((f["referenceName"] for f in d["value"] if f["name"].lower() == nom), ""))' "$1"
}
reference() { python3 -c '
import sys, unicodedata, re
s = unicodedata.normalize("NFKD", sys.argv[1]).encode("ascii", "ignore").decode()
print("Custom." + re.sub(r"[^A-Za-z0-9]", "", s.title()))' "$1"; }

REF_ECHEANCE="$(champ "$CHAMP_ECHEANCE")"
if [ -z "$REF_ECHEANCE" ]; then
  REF_ECHEANCE="$(reference "$CHAMP_ECHEANCE")"
  rest POST "_apis/wit/fields?api-version=7.1" \
    "$(jarg name "$CHAMP_ECHEANCE" referenceName "$REF_ECHEANCE" type dateTime usage workItem)" | ok
  echo "  champ « $CHAMP_ECHEANCE » créé ($REF_ECHEANCE)"
else
  echo "  champ « $CHAMP_ECHEANCE » réutilisé ($REF_ECHEANCE)"
fi

VALEURS='["Manuel d'"'"'utilisation","Guide de démarrage rapide","Documentation API"]'
REF_TYPE="$(champ "$CHAMP_TYPE")"
if [ -z "$REF_TYPE" ]; then
  LISTE="$(rest POST "_apis/work/processes/lists?api-version=7.1" \
    "{\"name\":\"picklist_$(uuidgen | tr 'A-Z' 'a-z')\",\"type\":\"String\",\"isSuggested\":false,\"items\":$VALEURS}" | py "print(d['id'])")"
  REF_TYPE="$(reference "$CHAMP_TYPE")"
  rest POST "_apis/wit/fields?api-version=7.1" "$(python3 -c '
import json, sys
print(json.dumps({"name": sys.argv[1], "referenceName": sys.argv[2], "type": "string", "usage": "workItem",
                  "isPicklist": True, "picklistId": sys.argv[3]}, ensure_ascii=False))' "$CHAMP_TYPE" "$REF_TYPE" "$LISTE")" | ok
  echo "  champ « $CHAMP_TYPE » créé ($REF_TYPE)"
else
  # Champ réutilisé : on complète sa liste si l'une des trois valeurs manque.
  LISTE="$(rest GET "_apis/wit/fields/$REF_TYPE?api-version=7.1" | py "print(d.get('picklistId') or '')")"
  if [ -n "$LISTE" ]; then
    rest GET "_apis/work/processes/lists/$LISTE?api-version=7.1" | python3 -c '
import json, sys
d = json.loads(sys.stdin.buffer.read().decode("utf-8-sig")); voulues = json.loads(sys.argv[1])
manque = [v for v in voulues if v not in d["items"]]
if manque:
    d["items"] += manque; print(json.dumps(d, ensure_ascii=False))' "$VALEURS" > "${TMPDIR:-/tmp}/liste.json"
    [ -s "${TMPDIR:-/tmp}/liste.json" ] && rest PUT "_apis/work/processes/lists/$LISTE?api-version=7.1" "$(cat "${TMPDIR:-/tmp}/liste.json")" | ok
    rm -f "${TMPDIR:-/tmp}/liste.json"
  fi
  echo "  champ « $CHAMP_TYPE » réutilisé ($REF_TYPE)"
fi

rest POST "$P/workitemtypes/$DOC_REF/fields?api-version=7.1" '{"referenceName":"Microsoft.VSTS.Common.Priority"}' | ok
rest POST "$P/workitemtypes/$DOC_REF/fields?api-version=7.1" "$(python3 -c 'import json, sys; print(json.dumps({"referenceName": sys.argv[1], "required": True}))' "$REF_ECHEANCE")" | ok
rest POST "$P/workitemtypes/$DOC_REF/fields?api-version=7.1" "$(python3 -c '
import json, sys
print(json.dumps({"referenceName": sys.argv[1], "required": True, "defaultValue": "Manuel d\x27utilisation"}, ensure_ascii=False))' "$REF_TYPE")" | ok

# Ajouter un champ par l'API ne le met pas sur le formulaire : un groupe « Documentation » le fait.
PAGE="$(rest GET "$P/workitemtypes/$DOC_REF/layout?api-version=7.1" | py "print(d['pages'][0]['id'])")"
rest POST "$P/workitemtypes/$DOC_REF/layout/pages/$PAGE/sections/Section2/groups?api-version=7.1" "$(python3 -c '
import json, sys
print(json.dumps({"label": "Documentation", "visible": True, "controls": [
  {"id": "Microsoft.VSTS.Common.Priority", "label": "Priorité", "visible": True},
  {"id": sys.argv[1], "label": "Date d\x27échéance", "visible": True},
  {"id": sys.argv[2], "label": "Type de documentation", "visible": True}]}, ensure_ascii=False))' "$REF_ECHEANCE" "$REF_TYPE")" | ok
rest POST "$P/workitemtypesbehaviors/$DOC_REF/behaviors?api-version=7.1" \
  '{"behavior":{"id":"System.RequirementBacklogBehavior"},"isDefault":false}' | ok
echo "  Priority, $REF_ECHEANCE (obligatoire), $REF_TYPE (obligatoire, défaut Manuel d'utilisation) ; niveau Stories"
# Documentation rejoint le niveau Stories : Azure DevOps rattache alors toutes les colonnes intermédiaires
# à « Nouveau », et un élément En cours ou En révision n'a plus de colonne. On fixe la correspondance.
COLONNES="$(rest GET "$PROJET_URL/$EQUIPE_URL/_apis/work/boards/Stories/columns?api-version=7.1" | python3 -c '
import json, sys
cols = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))["value"]
doc = {"New": "Nouveau", "Active": "En cours", "Resolved": "En révision",
       "En attente de validation": "En révision", "Closed": "Complété"}
for c in cols:
    us = c["stateMappings"].get("User Story")
    if us in doc:
        c["stateMappings"]["Documentation"] = doc[us]
print(json.dumps(cols, ensure_ascii=False))')"
rest PUT "$PROJET_URL/$EQUIPE_URL/_apis/work/boards/Stories/columns?api-version=7.1" "$COLONNES" | ok
echo "  tableau : Active -> En cours, Resolved et Attente client -> En révision, Closed -> Complété"

etape "H et I : epic, feature, stories, tâches, étiquettes"
creer() { # creer <type> <titre> [itération] [assigné] [champs…] : ID
  local type="$1" titre="$2" it="${3:-}" qui="${4:-}"; shift 4 || shift $#
  local args=(--type "$type" --title "$titre")
  [ -n "$it" ] && args+=(--iteration "$PROJET\\$it")
  [ -n "$qui" ] && args+=(--assigned-to "$qui")
  [ $# -gt 0 ] && args+=(--fields "$@")
  azp boards work-item create "${args[@]}" --query id -o tsv
}
parent() { azo boards work-item relation add --id "$1" --relation-type parent --target-id "$2" -o none; }

EPIC="$(creer Epic "Rendez-vous en ligne de la clinique" "" "$A_VOUS")"
FEAT="$(creer Feature "Gestion des rendez-vous" "" "$A_VOUS")"; parent "$FEAT" "$EPIC"
US1="$(creer "User Story" "Prendre rendez-vous en ligne" "Sprint 1" "$A_VOUS" "Microsoft.VSTS.Common.Priority=1" \
  "System.Description=En tant que patient, je veux pouvoir prendre rendez-vous en ligne afin de ne pas avoir à appeler la clinique.")"
US2="$(creer "User Story" "Recevoir des rappels par courriel" "Sprint 2" "$A_VOUS" "Microsoft.VSTS.Common.Priority=2" \
  "System.Description=En tant que patient, je veux recevoir des rappels par courriel de mon rendez-vous pour éviter de l'oublier.")"
US3="$(creer "User Story" "Tester la gestion des rendez-vous" "Sprint 3" "$A_VOUS" \
  "System.Description=En tant qu'équipe de développement, nous voulons tester minutieusement la fonctionnalité Gestion des rendez-vous pour assurer une expérience utilisateur fiable et intuitive.")"
for us in "$US1" "$US2" "$US3"; do parent "$us" "$FEAT"; done

tache() { # tache <story> <sprint> <titre> <assigné> <priorité> <étiquette> : ID
  local id; id="$(creer Task "$3" "$2" "$4" "Microsoft.VSTS.Common.Priority=$5" "System.Tags=$6")"
  parent "$id" "$1"; echo "$id"
}
T_MAQUETTE="$(tache "$US1" "Sprint 1" "Créer la maquette de l'interface utilisateur pour la prise de rendez-vous" "$A_VOUS" 1 Interface)"
T_INTERFACE="$(tache "$US1" "Sprint 1" "Développer l'interface utilisateur selon la maquette approuvée" "$A_JIM" 1 Interface)"
T_CALENDRIER="$(tache "$US1" "Sprint 1" "Intégrer l'API de calendrier pour afficher les disponibilités des médecins" "$A_JIM" 2 Backend)"
T_MODELE="$(tache "$US2" "Sprint 2" "Concevoir le modèle de courriel de rappel de rendez-vous" "$A_VOUS" 3 Interface)"
T_ENVOI="$(tache "$US2" "Sprint 2" "Développer l'envoi des courriels de rappel 24 h avant le rendez-vous" "$A_JIM" 2 Backend)"
T_FONCT="$(tache "$US3" "Sprint 3" "Préparer et exécuter des tests fonctionnels pour la prise de rendez-vous" "$A_JOHN" 2 Test)"
T_AUTO="$(tache "$US3" "Sprint 3" "Mettre en place des tests automatisés de la fonctionnalité de rappels par courriel" "$A_JOHN" 3 Test)"
DOC="$(creer Documentation "Guide de démarrage rapide de la prise de rendez-vous" "" "$A_VOUS" \
  "$REF_ECHEANCE=2026-12-18" "$REF_TYPE=Guide de démarrage rapide")"
echo "  epic $EPIC, feature $FEAT, stories $US1 $US2 $US3"
echo "  tâches $T_MAQUETTE $T_INTERFACE $T_CALENDRIER $T_MODELE $T_ENVOI $T_FONCT $T_AUTO ; Documentation $DOC"
echo "  Story Points des stories : $(for us in "$US1" "$US2" "$US3"; do azo boards work-item show --id "$us" --query 'fields."Microsoft.VSTS.Scheduling.StoryPoints"' -o tsv; done | tr '\n' ' ')"

etape "J : le cycle de vie"
etat() { azo boards work-item update --id "$1" --state "$2" -o none; }
etat "$T_MAQUETTE" Active; etat "$T_MAQUETTE" Closed
etat "$US1" Active; etat "$US1" Resolved; etat "$US1" "En attente de validation"
etat "$DOC" "En cours"; etat "$DOC" "En révision"
for id in "$T_MAQUETTE" "$US1" "$DOC"; do
  echo "  #$id : $(rest GET "$PROJET_URL/_apis/wit/workitems/$id/updates?api-version=7.1" \
    | py "print(' -> '.join(u['fields']['System.State']['newValue'] for u in d['value'] if 'System.State' in u.get('fields', {})))")"
done

etape "K : les requêtes partagées"
requete() { # requete <nom> <wiql>
  rest POST "$PROJET_URL/_apis/wit/queries/Shared%20Queries?api-version=7.1" "$(jarg name "$1" wiql "$2")" | ok
  echo "  $1 : $(wiql "$2" | tr '\n' ' ')"
}
requete "Clinique - Interface" \
  "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.Tags] CONTAINS 'Interface'"
requete "Clinique - Tâches P3" \
  "SELECT [System.Id], [System.Title], [System.AssignedTo] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = 'Task' AND [Microsoft.VSTS.Common.Priority] = 3"

etape "L : la capacité et le plan de livraison"
ITERATIONS="$(rest GET "$PROJET_URL/$EQUIPE_URL/_apis/work/teamsettings/iterations?api-version=7.1" \
  | py "print('\n'.join(i['name'] + '\t' + i['id'] for i in d['value']))")"
MEMBRES="$(azp devops team list-member --team "$EQUIPE" --query "[].[identity.uniqueName, identity.id]" -o tsv)"
conge() { # conge <adresse> <sprint> : le jour de congé du TP (sections L.1 et corrigé)
  local qui="vous"
  [ -n "${JIM:-}" ] && [ "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$JIM" | tr 'A-Z' 'a-z')" ] && qui=jim
  [ -n "${JOHN:-}" ] && [ "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$JOHN" | tr 'A-Z' 'a-z')" ] && qui=john
  case "$qui:$2" in
    vous:"Sprint 1") echo 2026-11-27 ;; jim:"Sprint 1") echo 2026-12-02 ;; john:"Sprint 1") echo 2026-11-30 ;;
    vous:"Sprint 2") echo 2026-12-11 ;; jim:"Sprint 2") echo 2026-12-14 ;; john:"Sprint 2") echo 2026-12-16 ;;
    vous:"Sprint 3") echo 2026-12-22 ;; jim:"Sprint 3") echo 2026-12-28 ;; john:"Sprint 3") echo 2026-12-30 ;;
  esac
}
for sprint in "Sprint 1" "Sprint 2" "Sprint 3"; do
  IT="$(printf '%s\n' "$ITERATIONS" | awk -F'\t' -v s="$sprint" '$1 == s { print $2 }')"
  while IFS=$'\t' read -r adresse id; do
    [ -n "$id" ] || continue
    activite=Development
    [ -n "${JOHN:-}" ] && [ "$(printf '%s' "$adresse" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$JOHN" | tr 'A-Z' 'a-z')" ] && activite=Testing
    jour="$(conge "$adresse" "$sprint")"
    rest PATCH "$PROJET_URL/$EQUIPE_URL/_apis/work/teamsettings/iterations/$IT/capacities/$id?api-version=7.1" \
      "{\"activities\":[{\"capacityPerDay\":6,\"name\":\"$activite\"}],\"daysOff\":[{\"start\":\"${jour}T00:00:00Z\",\"end\":\"${jour}T00:00:00Z\"}]}" | ok
  done <<< "$MEMBRES"
  if [ "$sprint" = "Sprint 3" ]; then
    rest PATCH "$PROJET_URL/$EQUIPE_URL/_apis/work/teamsettings/iterations/$IT/teamdaysoff?api-version=7.1" \
      '{"daysOff":[{"start":"2026-12-25T00:00:00Z","end":"2026-12-25T00:00:00Z"},{"start":"2027-01-01T00:00:00Z","end":"2027-01-01T00:00:00Z"}]}' | ok
  fi
  echo "  $sprint : $(rest GET "$PROJET_URL/$EQUIPE_URL/_apis/work/teamsettings/iterations/$IT/capacities?api-version=7.1" \
    | py "print(f\"{len(d['teamMembers'])} membre(s), {d['totalCapacityPerDay']:g} h par jour, {d['totalDaysOff']} jour(s) de congé\")")"
done
rest POST "$PROJET_URL/_apis/work/plans?api-version=7.1" "{\"name\":\"Planning Clinique\",\"type\":\"deliveryTimelineView\",\"properties\":{
  \"teamBacklogMappings\":[{\"teamId\":\"$EQUIPE_ID\",\"categoryReferenceName\":\"Microsoft.RequirementCategory\"}],
  \"markers\":[{\"date\":\"2026-12-04T00:00:00Z\",\"label\":\"Revue et rétro S1\",\"color\":\"#339933\"},
               {\"date\":\"2026-12-18T00:00:00Z\",\"label\":\"Revue et rétro S2\",\"color\":\"#339933\"},
               {\"date\":\"2026-12-31T00:00:00Z\",\"label\":\"Revue et rétro S3\",\"color\":\"#339933\"}]}}" | ok
echo "  plan « Planning Clinique » : trois marqueurs (04/12, 18/12, 31/12)"

etape "M : le commentaire"
if [ -n "${JIM:-}" ]; then
  JIM_ID="$(azo devops user show --user "$JIM" --query id -o tsv)"
  TEXTE="<div><a href=\"#\" data-vss-mention=\"version:2.0,$JIM_ID\">@Jim</a> attention, la maquette risque encore d'être modifiée après la revue avec le client.</div>"
else
  TEXTE="<div>Jim : attention, la maquette risque encore d'être modifiée après la revue avec le client.</div>"
fi
rest POST "$PROJET_URL/_apis/wit/workItems/$T_INTERFACE/comments?api-version=7.1-preview.4" "$(jarg text "$TEXTE")" | ok
echo "  commentaire sur #$T_INTERFACE$([ -n "${JIM:-}" ] && echo ", avec la mention de Jim" || echo ", sans mention (JIM non fourni)")"

etape "Terminé"
echo "  $ORG/$PROJET_URL"
echo "  reste à la main : Overview > Summary > About this project > Wiki"
exit
}
