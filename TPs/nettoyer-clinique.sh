#!/usr/bin/env bash
# Supprime ce que créent les solutions du TP 1 bis (rejouer-tp-1-bis.sh) et du TP 2 bis
# (rejouer-tp-2-bis.sh), ou les mêmes TP faits à la main.
#
# Usage :
#   ./nettoyer-clinique.sh <organisation> <Prénom>
#   ./nettoyer-clinique.sh utopios-formation Ihab
#
# Ce qui est supprimé :
#   1. le projet Clinique-<Prénom> : tout le TP 2 bis (dépôt clinique-web, pipeline clinique-ci,
#      stratégies, pull requests) et l'essentiel du TP 1 bis (wiki, éléments de travail, requêtes,
#      capacité, plan de livraison) ;
#   2. le processus AgileCustom<Prénom>, une fois qu'aucun projet ne l'utilise plus ;
#   3. les champs « Échéance » et « Type de documentation » de l'organisation, SEULEMENT si plus
#      aucun processus ne les utilise (dans une organisation partagée, les autres stagiaires les
#      réutilisent) ; la liste de choix du second part avec lui ;
#   4. la copie de travail locale du TP 2 bis (~/tp2bis-solution par défaut).
#
# Variables facultatives :
#   AZURE_DEVOPS_EXT_PAT=<PAT>   jeton d'accès personnel au lieu de az login
#   CHAMP_ECHEANCE, CHAMP_TYPE   noms des champs, si vous en avez changé (défaut « Échéance »,
#                                « Type de documentation »)
#   TRAVAIL=<dossier>            copie de travail locale (défaut ~/tp2bis-solution)
#   RETIRER_MEMBRES=1 JIM=<adresse> JOHN=<adresse>
#                                retire aussi ces personnes de l'organisation (désactivé par défaut :
#                                votre voisin en a peut-être besoin pour les autres TP)
#   OUI=1                        ne demande pas de confirmation
#
# Un projet supprimé reste restaurable 28 jours (Organization settings > Projects). Le processus et
# les champs, eux, ne se restaurent pas.

{ # Bash lit ce bloc en entier avant de l'exécuter : modifier le fichier pendant un run ne le casse pas.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '2,32p' "$0"; exit 1; }

ORG="https://dev.azure.com/$1"
PRENOM="$2"
PROJET="Clinique-$PRENOM"
PROCESSUS="AgileCustom$PRENOM"
CHAMP_ECHEANCE="${CHAMP_ECHEANCE:-Échéance}"
CHAMP_TYPE="${CHAMP_TYPE:-Type de documentation}"
TRAVAIL="${TRAVAIL:-$HOME/tp2bis-solution}"

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
rest() { # rest <méthode> <chemin après l'organisation> : corps de la réponse ; code HTTP dans $CODE
  local sortie; sortie="$(curl -sS -X "$1" -H "$AUTH" -w '\n%{http_code}' "$ORG/$2")"
  CODE="${sortie##*$'\n'}"; printf '%s' "${sortie%$'\n'*}"
}
py() { python3 -c "import json, sys; d = json.loads(sys.stdin.buffer.read().decode('utf-8-sig') or 'null'); $1"; }

# --- Ce qui existe --------------------------------------------------------------------

PROJET_ID="$(az devops project show --project "$PROJET" --org "$ORG" --query id -o tsv --only-show-errors 2>/dev/null || true)"
PROCESSUS_ID="$(rest GET "_apis/work/processes?api-version=7.1" \
  | py "print(next((p['typeId'] for p in d['value'] if p['name'].lower() == '$PROCESSUS'.lower()), ''))")"
champ() { # champ <nom> : référence du champ de ce nom (casse ignorée), ou rien
  rest GET "_apis/wit/fields?api-version=7.1" | python3 -c '
import json, sys
nom = sys.argv[1].lower(); d = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
print(next((f["referenceName"] for f in d["value"] if f["name"].lower() == nom and f["referenceName"].startswith("Custom.")), ""))' "$1"
}
REF_ECHEANCE="$(champ "$CHAMP_ECHEANCE")"
REF_TYPE="$(champ "$CHAMP_TYPE")"

echo "Organisation : $ORG"
echo "  projet      $PROJET : ${PROJET_ID:-absent}"
echo "  processus   $PROCESSUS : ${PROCESSUS_ID:-absent}"
echo "  champs      $CHAMP_ECHEANCE : ${REF_ECHEANCE:-absent} ; $CHAMP_TYPE : ${REF_TYPE:-absent} (supprimés seulement s'ils ne servent plus)"
echo "  local       $TRAVAIL : $([ -d "$TRAVAIL" ] && echo présent || echo absent)"
if [ "${RETIRER_MEMBRES:-0}" = 1 ]; then
  echo "  membres     ${JIM:-} ${JOHN:-} (retirés de l'organisation)"
fi

if [ "${OUI:-0}" != 1 ]; then
  printf '\nTapez le nom du projet (%s) pour confirmer la suppression : ' "$PROJET"
  read -r reponse
  [ "$reponse" = "$PROJET" ] || { echo "Abandon : rien n'a été supprimé."; exit 1; }
fi

# --- 1. Le projet ---------------------------------------------------------------------

if [ -n "$PROJET_ID" ]; then
  az devops project delete --id "$PROJET_ID" --org "$ORG" --yes --only-show-errors -o none
  echo "projet $PROJET supprimé (restaurable 28 jours)"
fi

# --- 2. Le processus ------------------------------------------------------------------

if [ -n "$PROCESSUS_ID" ]; then
  for _ in $(seq 1 24); do  # la suppression du projet se termine en arrière-plan
    rest DELETE "_apis/work/processes/$PROCESSUS_ID?api-version=7.1" > /dev/null
    case "$CODE" in 2*) break ;; esac
    sleep 5
  done
  case "$CODE" in
    2*) echo "processus $PROCESSUS supprimé" ;;
    *)  echo "processus $PROCESSUS NON supprimé (HTTP $CODE) : un autre projet l'utilise-t-il ?" >&2 ;;
  esac
fi

# --- 3. Les champs, s'ils ne servent plus ---------------------------------------------

utilise() { # utilise <référence> : liste les processus dont un type d'élément contient ce champ
  local procs; procs="$(rest GET "_apis/work/processes?api-version=7.1" \
    | py "print('\n'.join(p['typeId'] + '\t' + p['name'] for p in d['value'] if p.get('customizationType') != 'system'))")"
  while IFS=$'\t' read -r id nom; do
    [ -n "$id" ] || continue
    for wit in $(rest GET "_apis/work/processes/$id/workitemtypes?api-version=7.1" \
        | py "print(' '.join(w['referenceName'] for w in d['value'] if w.get('customization') != 'system'))"); do
      if rest GET "_apis/work/processes/$id/workitemtypes/$wit/fields?api-version=7.1" \
          | py "sys.exit(0 if any(f['referenceName'] == '$1' for f in d['value']) else 1)"; then
        echo "$nom"; break
      fi
    done
  done <<< "$procs"
}
supprimer_champ() { # supprimer_champ <référence> <nom>
  local ref="$1" nom="$2" liste qui
  [ -n "$ref" ] || return 0
  qui="$(utilise "$ref" | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
  if [ -n "$qui" ]; then
    echo "champ « $nom » conservé : utilisé par $qui"; return 0
  fi
  liste="$(rest GET "_apis/wit/fields/$ref?api-version=7.1" | py "print(d.get('picklistId') or '')")"
  for _ in $(seq 1 12); do
    rest DELETE "_apis/wit/fields/$ref?api-version=7.1" > /dev/null
    case "$CODE" in 2*) break ;; esac
    sleep 5
  done
  case "$CODE" in
    2*) echo "champ « $nom » supprimé"
        if [ -n "$liste" ]; then
          rest DELETE "_apis/work/processes/lists/$liste?api-version=7.1" > /dev/null
          echo "  liste de choix supprimée (HTTP $CODE)"
        fi ;;
    *)  echo "champ « $nom » NON supprimé (HTTP $CODE)" >&2 ;;
  esac
}
supprimer_champ "$REF_ECHEANCE" "$CHAMP_ECHEANCE"
supprimer_champ "$REF_TYPE" "$CHAMP_TYPE"

# --- 4. Les membres, sur demande ------------------------------------------------------

if [ "${RETIRER_MEMBRES:-0}" = 1 ]; then
  for adresse in ${JIM:-} ${JOHN:-}; do
    if az devops user remove --user "$adresse" --org "$ORG" --yes --only-show-errors -o none 2>/dev/null; then
      echo "$adresse retiré de l'organisation"
    else
      echo "$adresse : absent de l'organisation, ou retrait refusé" >&2
    fi
  done
fi

# --- 5. La copie de travail locale ----------------------------------------------------

if [ -d "$TRAVAIL" ]; then
  if [ -d "$TRAVAIL/.git" ] && [ "$(basename "$TRAVAIL")" != "$(basename "$HOME")" ]; then
    rm -rf "$TRAVAIL"
    echo "copie locale $TRAVAIL supprimée"
  else
    echo "$TRAVAIL n'est pas une copie Git du TP : laissée en place" >&2
  fi
fi

echo "Terminé."
exit
}
