#!/usr/bin/env bash
# Rejoue le TP 3 (tests, bugs et régression) de bout en bout : Test Plans, Boards, Repos, Pipelines,
# et l'exécution des cas de test contre l'API lancée sur le poste.
#
# Usage :
#   ./rejouer-tp-3.sh <organisation> [<projet>]          (projet : RDV par défaut)
#   ./rejouer-tp-3.sh utopios-formation RDV
#
# Prérequis :
#   - az CLI avec l'extension azure-devops (az extension add -n azure-devops), puis az login
#     (ou un PAT, voir AZURE_DEVOPS_EXT_PAT) ;
#   - votre compte en Basic + Test Plans dans l'organisation ;
#   - git, python3 et le SDK .NET 10 ;
#   - le port 5080 libre (ou PORT=...).
#
# Point de départ : le script reprend le projet du TP 2 s'il existe (dépôt rdv-api, pipeline rdv-pr,
# stratégie Build validation, itération Sprint 1) et crée ce qui manque, comme le paragraphe
# « Si vous partez de zéro » de l'énoncé. Un dépôt neuf reçoit le code de demos/fil-rouge/rdv-api.
#
# Variables facultatives :
#   AZURE_DEVOPS_EXT_PAT=<PAT>  jeton d'accès personnel au lieu de az login
#   GIT_AZ_TOKEN=1              git utilise le même jeton (az ou PAT) au lieu de Git Credential Manager
#   TRAVAIL=<dossier>           copie de travail locale (défaut : ~/tp3-solution)
#   PORT=<port>                 port de l'API locale (défaut : 5080)
#   PLAN=<nom>                  nom du plan de test (défaut : « RDV - Sprint 1 »)
#
# Ce que le script ne fait pas : regarder les écrans (Test Runner, historique du point, onglet Tests),
# et reprendre ou rejeter le stage de production d'un run rdv-ci-cd déclenché par la fusion.
# À donner après le TP : le script montre l'écart que les stagiaires doivent trouver eux-mêmes.

{ # Bash lit ce bloc en entier avant de l'exécuter : modifier le fichier pendant un run ne le casse pas.
set -euo pipefail

[ $# -ge 1 ] && [ $# -le 2 ] || { sed -n '2,29p' "$0"; exit 1; }

ICI="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$ICI/../../demos/module-02/rdv-api"
ORG="https://dev.azure.com/$1"
PROJET="${2:-RDV}"
DEPOT=rdv-api
TRAVAIL="${TRAVAIL:-$HOME/tp3-solution}"
PORT="${PORT:-5080}"
PLAN="${PLAN:-RDV - Sprint 1}"
SPRINT="$PROJET\\Sprint 1"
ETAT="$TRAVAIL/.git/tp3-etat.json"   # identifiants des cas, du run, du bug : partagés avec la partie Python

[ ! -e "$TRAVAIL" ] || { echo "$TRAVAIL existe déjà : supprimez-le ou choisissez TRAVAIL=..." >&2; exit 1; }
for outil in az git python3 dotnet curl; do
  command -v "$outil" > /dev/null && continue
  echo "$outil est introuvable." >&2
  [ "$outil" != dotnet ] || echo "Pour installer le SDK .NET 10 : outils/installer-dotnet.sh (à la racine des supports)." >&2
  exit 1
done
if curl -s -o /dev/null "http://localhost:$PORT/sante"; then
  echo "Le port $PORT est déjà utilisé : arrêtez l'API qui tourne, ou choisissez PORT=..." >&2; exit 1
fi

etape() { printf '\n== %s\n' "$*"; }
azo() { az "$@" --org "$ORG" --only-show-errors; }                       # commandes sans projet
azp() { az "$@" --org "$ORG" --project "$PROJET" --only-show-errors; }   # commandes avec projet

# Authentification : PAT si AZURE_DEVOPS_EXT_PAT est défini, sinon jeton Microsoft Entra du compte
# connecté par az login (499b84ac-... est l'identifiant public d'Azure DevOps, le même pour tous).
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

rest() { # rest <méthode> <chemin après le projet> [json]
  local args=(-sS -f -X "$1" -H "$AUTH" "$ORG/$PROJET_URL/$2")
  [ -n "${3:-}" ] && args+=(-H "Content-Type: application/json" --data-binary "$3")
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

# --- Test Plans, Boards et exécution des cas : la partie Python ------------------------------------
# Elle crée le plan, les suites, les cas de test, puis joue chaque cas contre l'API locale comme le
# ferait Léa dans le Test Runner : un résultat par itération et par étape, la réponse obtenue en
# commentaire de chaque étape en échec.

TP3_PY="$(mktemp "${TMPDIR:-/tmp}/tp3.XXXXXX")"
trap 'rm -f "$TP3_PY"' EXIT
cat > "$TP3_PY" <<'PY'
import atexit, datetime, html, json, os, re, signal, subprocess, sys, time, uuid
import urllib.error, urllib.parse, urllib.request
from xml.sax.saxutils import escape

ORG, PROJET, ETAT, TRAVAIL = os.environ["ORG"], os.environ["PROJET"], os.environ["ETAT"], os.environ["TRAVAIL"]
SPRINT, PLAN, API = os.environ["SPRINT"], os.environ["PLAN"], "http://localhost:" + os.environ["PORT"]
ENTETE, JETON = os.environ["AUTH"].split(": ", 1)
BASE = ORG + "/" + urllib.parse.quote(PROJET)

def ado(methode, chemin, corps=None, type_contenu="application/json"):
    requete = urllib.request.Request(BASE + "/" + chemin, method=methode,
                                     data=None if corps is None else json.dumps(corps).encode(),
                                     headers={ENTETE: JETON, "Content-Type": type_contenu})
    try:
        with urllib.request.urlopen(requete) as reponse:
            texte = reponse.read().decode("utf-8-sig")
    except urllib.error.HTTPError as e:
        sys.exit(f"{methode} {chemin} : HTTP {e.code} {e.read().decode('utf-8', 'replace')[:600]}")
    return json.loads(texte) if texte else None

def lien(relation, id_):
    return {"rel": relation, "url": f"{ORG}/_apis/wit/workItems/{id_}"}

def creer_element(type_, champs, liens=()):
    ops = [{"op": "add", "path": "/fields/" + k, "value": v} for k, v in champs.items()]
    ops += [{"op": "add", "path": "/relations/-", "value": l} for l in liens]
    return ado("POST", f"_apis/wit/workitems/${urllib.parse.quote(type_)}?api-version=7.1", ops, "application/json-patch+json")

def modifier_element(id_, champs, liens=()):
    ops = [{"op": "add", "path": "/fields/" + k, "value": v} for k, v in champs.items()]
    ops += [{"op": "add", "path": "/relations/-", "value": l} for l in liens]
    return ado("PATCH", f"_apis/wit/workitems/{id_}?api-version=7.1", ops, "application/json-patch+json")

def wiql(requete):
    return [w["id"] for w in ado("POST", "_apis/wit/wiql?api-version=7.1", {"query": requete})["workItems"]]

def lire():
    try:
        with open(ETAT, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def ecrire(etat):
    with open(ETAT, "w", encoding="utf-8") as f:
        json.dump(etat, f, ensure_ascii=False, indent=1)

def horodatage():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

# --- Les dates des cas de test --------------------------------------------------------------------
# Les cas sont écrits avec des lettres, comme dans l'énoncé (J, S, D) ; on les remplace au moment
# d'exécuter. M et X encadrent l'horizon de 90 jours, H est un jour passé.
JOUR = datetime.timedelta(days=1)
AUJOURDHUI = datetime.date.today()
J = AUJOURDHUI + JOUR
while J.weekday() >= 5:
    J += JOUR
S = J + (5 - J.weekday()) * JOUR
M = AUJOURDHUI + 89 * JOUR
if M.weekday() == 6:
    M -= JOUR
DATES = {"J": J, "S": S, "D": S + JOUR, "H": AUJOURDHUI - JOUR, "M": M, "X": AUJOURDHUI + 91 * JOUR}
LEGENDE = ", ".join(f"{k} = {v.isoformat()}" for k, v in DATES.items())

def resoudre(valeur):  # « JT10:00:00 » -> « 2026-11-25T10:00:00 », « S » -> « 2026-11-28 »
    m = re.fullmatch(r"([JSDHMX])(T\d\d:\d\d:\d\d)?", valeur)
    return DATES[m.group(1)].isoformat() + (m.group(2) or "") if m else valeur

def remplir(texte, ligne):  # remplace les @paramètres par les valeurs de l'itération
    for nom in sorted(ligne, key=len, reverse=True):
        texte = texte.replace("@" + nom, ligne[nom])
    return texte

# --- La story et les cas de test ------------------------------------------------------------------
CRITERES = [
    "Un créneau libre, futur et prévu au planning d'un praticien connu se réserve : réponse 201 et en-tête Location vers le rendez-vous créé ; le créneau n'apparaît plus ensuite dans GET /api/creneaux.",
    "Le planning va du lundi au vendredi de 8 h à 19 h et le samedi de 8 h à 12 h, en créneaux de 20 minutes à partir de 8 h ; aucun créneau le dimanche. Une demande hors planning est refusée (422).",
    "Un créneau passé est refusé (422). Un créneau situé à plus de 90 jours est refusé (422).",
    "Un créneau déjà réservé est refusé (409), quel que soit le patient qui le demande.",
    "Un patient ne prend qu'un rendez-vous par jour chez un même praticien : une seconde demande pour le même jour et le même praticien est refusée (409). Il peut en revanche consulter deux praticiens différents le même jour.",
    "L'identifiant patient n'est sensible ni à la casse ni aux espaces de début et de fin : deux saisies qui ne diffèrent que par la casse ou par ces espaces désignent le même patient.",
    "Un praticien inconnu est refusé (404) ; une demande sans identifiant patient ou sans praticien est refusée (400).",
]
PIED = "Chaque refus métier (404, 409, 422) renvoie une réponse problem details qui porte un champ motif ; une requête mal formée (400) n'en porte pas."

PARTAGEE = "Démarrer l'API et vérifier /sante"
SANTE = None  # place de l'étape partagée dans un cas

def post(praticien, patient, debut):
    return {"post": [praticien, patient, debut]}

CAS = [
    dict(cle="reserver", titre="Un créneau libre se réserve et disparaît des créneaux libres", etapes=[
        SANTE,
        ("GET /api/creneaux?praticienId=DR-LV-01&date=J", "200, la liste contient JT10:00:00",
         {"get": "DR-LV-01", "date": "J", "contient": "JT10:00:00"}),
        ('POST /api/rendez-vous avec {"praticienId":"DR-LV-01","patientId":"P-104233","debut":"JT10:00:00"}',
         "201, en-tête Location: /api/rendez-vous/<guid>", post("DR-LV-01", "P-104233", "JT10:00:00")),
        ("GET /api/creneaux?praticienId=DR-LV-01&date=J", "200, JT10:00:00 n'est plus dans la liste",
         {"get": "DR-LV-01", "date": "J", "absent": "JT10:00:00"})]),
    dict(cle="hors-planning", titre="Une demande hors planning est refusée", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"@debut"', '422, "motif":"HorsPlanning"',
         post("DR-LV-01", "P-104233", "@debut"))],
        parametres=["debut"], lignes=[["JT10:05:00"], ["JT07:40:00"], ["JT19:00:00"], ["ST12:00:00"], ["DT10:00:00"]]),
    dict(cle="planning", titre="Les créneaux proposés suivent le planning", etapes=[
        SANTE,
        ("GET /api/creneaux?praticienId=DR-RG-01&date=@date", "200, @attendu",
         {"get": "DR-RG-01", "date": "@date", "planning": True})],
        parametres=["date", "attendu"], lignes=[["J", "33 créneaux, de 08:00 à 18:40"],
                                                ["S", "12 créneaux, de 08:00 à 11:40"],
                                                ["D", "0 créneau, liste vide"]]),
    dict(cle="passe", titre="Un créneau passé est refusé", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"HT10:00:00" (H = hier)', '422, "motif":"CreneauPasse"',
         post("DR-LV-01", "P-104233", "HT10:00:00"))]),
    dict(cle="horizon", titre="L'horizon de réservation est de 90 jours", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"@debut" (M = aujourd\'hui + 89 jours, la veille si '
         "c'est un dimanche ; X = aujourd'hui + 91 jours)", "@attendu", post("DR-LV-01", "P-104233", "@debut"))],
        parametres=["debut", "attendu"], lignes=[["MT10:00:00", "201"], ["XT10:00:00", '422, "motif":"TropLointain"']]),
    dict(cle="deja-pris", titre="Un créneau déjà réservé est refusé, quel que soit le patient", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"JT11:00:00"', "201",
         post("DR-LV-01", "P-104233", "JT11:00:00")),
        ('POST /api/rendez-vous avec DR-LV-01, @patient, "debut":"JT11:00:00"', '409, "motif":"CreneauDejaPris"',
         post("DR-LV-01", "@patient", "JT11:00:00"))],
        parametres=["patient"], lignes=[["P-200871"], ["P-104233"]]),
    dict(cle="doublon", titre="Un patient ne réserve qu'un rendez-vous par jour chez un praticien", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"JT10:00:00"', "201",
         post("DR-LV-01", "P-104233", "JT10:00:00")),
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"JT16:00:00"', '409, "motif":"DoublonPatient"',
         post("DR-LV-01", "P-104233", "JT16:00:00"))]),
    dict(cle="deux-praticiens", titre="Un patient peut consulter deux praticiens le même jour", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"JT10:00:00"', "201",
         post("DR-LV-01", "P-104233", "JT10:00:00")),
        ('POST /api/rendez-vous avec DR-LV-02, P-104233, "debut":"JT11:00:00"', "201",
         post("DR-LV-02", "P-104233", "JT11:00:00"))]),
    dict(cle="casse", titre="L'identifiant patient ignore la casse et les espaces", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec DR-LV-01, P-104233, "debut":"JT10:00:00"', "201",
         post("DR-LV-01", "P-104233", "JT10:00:00")),
        ('POST /api/rendez-vous avec DR-LV-01, « @patient » (espaces compris), "debut":"JT@heure:00"',
         '409, "motif":"DoublonPatient"', post("DR-LV-01", "@patient", "JT@heure:00"))],
        parametres=["patient", "heure"], lignes=[["p-104233", "16:00"], [" P-104233", "16:20"],
                                                 ["P-104233 ", "16:40"], [" p-104233 ", "17:00"]]),
    dict(cle="invalides", titre="Les demandes invalides sont refusées", etapes=[
        SANTE,
        ('POST /api/rendez-vous avec "praticienId":"@praticien", "patientId":"@patient", "debut":"JT10:00:00"', "@attendu",
         post("@praticien", "@patient", "JT10:00:00"))],
        parametres=["praticien", "patient", "attendu"], lignes=[["DR-XX-99", "P-104233", '404, "motif":"PraticienInconnu"'],
                                                                ["DR-LV-01", "", "400, sans motif"],
                                                                ["", "P-104233", "400, sans motif"]]),
]
PAR_CLE = {c["cle"]: c for c in CAS}

def xml_texte(texte):  # du HTML, lui-même échappé dans le XML du champ Steps
    return '<parameterizedString isformatted="true">' + escape("<DIV><P>" + escape(texte) + "</P></DIV>") + "</parameterizedString>"

def xml_etapes(etapes, partagee):
    morceaux = []
    for n, etape in enumerate(etapes, 2):
        if etape is SANTE:
            morceaux.append(f'<compref id="{n}" ref="{partagee}" />')
        else:
            morceaux.append(f'<step id="{n}" type="ValidateStep">{xml_texte(etape[0])}{xml_texte(etape[1])}<description/></step>')
    return f'<steps id="0" last="{len(etapes) + 1}">' + "".join(morceaux) + "</steps>"

def xml_donnees(noms, lignes):  # le format que l'éditeur de Test Plans écrit pour la grille Parameter values
    schema = ("<xs:schema id='NewDataSet' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:msdata='urn:schemas-microsoft-com:xml-msdata'>"
              "<xs:element name='NewDataSet' msdata:IsDataSet='true' msdata:Locale=''><xs:complexType>"
              "<xs:choice minOccurs='0' maxOccurs='unbounded'><xs:element name='Table1'><xs:complexType><xs:sequence>"
              + "".join(f"<xs:element name='{n}' type='xs:string' minOccurs='0' />" for n in noms)
              + "</xs:sequence></xs:complexType></xs:element></xs:choice></xs:complexType></xs:element></xs:schema>")
    return ("<NewDataSet>" + schema
            + "".join("<Table1>" + "".join(f"<{n}>{escape(v)}</{n}>" for n, v in zip(noms, l)) + "</Table1>" for l in lignes)
            + "</NewDataSet>")

# --- Étape 1 : la story ---------------------------------------------------------------------------
def story():
    ids = wiql("SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project "
               "AND [System.WorkItemType] = 'User Story' AND [System.Title] = 'Réserver un créneau'")
    criteres = "<ol>" + "".join(f"<li>{html.escape(c)}</li>" for c in CRITERES) + "</ol><p>" + html.escape(PIED) + "</p>"
    champs = {"Microsoft.VSTS.Common.AcceptanceCriteria": criteres}
    if ids:
        us = ado("GET", f"_apis/wit/workitems/{ids[0]}?$expand=relations&api-version=7.1")
        if us["fields"].get("Microsoft.VSTS.Common.AcceptanceCriteria"):
            champs = {}
        print(f"  story #{us['id']} retrouvée" + ("" if champs else " (critères déjà saisis)"), file=sys.stderr)
    else:
        us = creer_element("User Story", {
            "System.Title": "Réserver un créneau", "System.IterationPath": SPRINT,
            "System.Description": "<p>En tant que patient, je veux réserver un créneau libre chez un praticien, "
                                  "afin d'obtenir un rendez-vous sans appeler le secrétariat.</p>"})
        print(f"  story #{us['id']} créée dans {SPRINT}", file=sys.stderr)
    liens = []
    feature = wiql("SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project "
                   "AND [System.WorkItemType] = 'Feature' AND [System.Title] = 'Réservation en ligne'")
    if feature and not any(r["rel"] == "System.LinkTypes.Hierarchy-Reverse" for r in us.get("relations") or []):
        liens = [lien("System.LinkTypes.Hierarchy-Reverse", feature[0])]
        print(f"  rattachée à la feature « Réservation en ligne » #{feature[0]}", file=sys.stderr)
    if champs or liens:
        modifier_element(us["id"], champs, liens)
    if champs:
        print("  sept critères dans Acceptance Criteria", file=sys.stderr)
    print(us["id"])

# --- Étape 2 : plan, suite basée sur l'exigence, configuration -------------------------------------
def configurer(plan, suite, config):
    # La révision et le nom de la configuration sont obligatoires : sans eux, la réponse est un succès
    # mais la suite garde sa configuration.
    s = ado("GET", f"_apis/testplan/Plans/{plan}/suites/{suite}?api-version=7.1")
    ado("PATCH", f"_apis/testplan/Plans/{plan}/suites/{suite}?api-version=7.1",
        {"revision": s["revision"], "inheritDefaultConfigurations": False,
         "defaultConfigurations": [{"id": config["id"], "name": config["name"]}]})

def plan_et_suite(us):
    us = int(us)
    if any(p["name"] == PLAN for p in ado("GET", "_apis/testplan/plans?api-version=7.1")["value"]):
        sys.exit(f"Le plan « {PLAN} » existe déjà : supprimez-le (Test Plans > Test plans), ou choisissez PLAN=...")
    plan = ado("POST", "_apis/testplan/plans?api-version=7.1", {"name": PLAN, "areaPath": PROJET, "iteration": SPRINT})
    suite = ado("POST", f"_apis/testplan/Plans/{plan['id']}/suites?api-version=7.1",
                {"suiteType": "requirementTestSuite", "name": "Réserver un créneau",
                 "parentSuite": {"id": plan["rootSuite"]["id"]}, "requirementId": us})
    print(f"  plan « {PLAN} » #{plan['id']}, suite « {suite['name']} » #{suite['id']}")

    variable = next((v for v in ado("GET", "_apis/testplan/variables?api-version=7.1")["value"] if v["name"] == "Cible"), None)
    if variable is None:
        ado("POST", "_apis/testplan/variables?api-version=7.1", {"name": "Cible", "values": ["API locale"]})
    elif "API locale" not in variable["values"]:
        ado("PATCH", f"_apis/testplan/variables/{variable['id']}?api-version=7.1",
            {"name": "Cible", "values": variable["values"] + ["API locale"]})
    config = next((c for c in ado("GET", "_apis/testplan/configurations?api-version=7.1")["value"] if c["name"] == "API locale"), None)
    if config is None:
        config = ado("POST", "_apis/testplan/configurations?api-version=7.1",
                     {"name": "API locale", "values": [{"name": "Cible", "value": "API locale"}], "state": "active"})
    configurer(plan["id"], suite["id"], config)
    print("  configuration « API locale » (Cible = API locale), seule affectée à la suite")
    ecrire({"story": us, "plan": plan["id"], "racine": plan["rootSuite"]["id"], "suite": suite["id"],
            "config": {"id": config["id"], "name": config["name"]}, "cas": {}, "echecs": {}})

# --- Étape 3 : l'étape partagée et les cas de test -------------------------------------------------
def cas_de_test():
    e = lire()
    partagee = creer_element("Shared Steps", {
        "System.Title": PARTAGEE, "System.AreaPath": PROJET,
        "Microsoft.VSTS.TCM.Steps": xml_etapes([("Démarrer l'API : dotnet run --project src/Santinord.Rdv.Api "
                                                 "--urls http://localhost:5080, puis GET /sante", '200, {"statut":"ok"}', None)], 0)})
    e["partagee"] = {"id": partagee["id"], "rev": partagee["rev"]}
    print(f"  étape partagée « {PARTAGEE} » #{partagee['id']}")
    for cas in CAS:
        champs = {"System.Title": cas["titre"], "System.AreaPath": PROJET, "System.IterationPath": SPRINT,
                  "Microsoft.VSTS.TCM.Steps": xml_etapes(cas["etapes"], partagee["id"])}
        if cas.get("parametres"):
            champs["Microsoft.VSTS.TCM.Parameters"] = ("<parameters>" + "".join(
                f'<param name="{n}" bind="default" />' for n in cas["parametres"]) + "</parameters>")
            champs["Microsoft.VSTS.TCM.LocalDataSource"] = xml_donnees(cas["parametres"], cas["lignes"])
        tc = creer_element("Test Case", champs, [lien("Microsoft.VSTS.TestCase.SharedStepReferencedBy-Reverse", partagee["id"])])
        e["cas"][cas["cle"]] = {"id": tc["id"]}
    # Ajouter un cas à une suite basée sur l'exigence crée le lien Tests vers la story. Sans
    # pointAssignments, la nouvelle API n'affecte aucune configuration : aucun point de test.
    chemin = f"_apis/testplan/Plans/{e['plan']}/Suites/{e['suite']}/TestCase?api-version=7.1"
    ajout = [{"workItem": {"id": c["id"]}, "pointAssignments": [{"configurationId": e["config"]["id"]}]} for c in e["cas"].values()]
    ado("POST", chemin, ajout)
    points = {}
    for _ in range(10):
        points = {int(p["testCaseReference"]["id"]): p["id"] for p in ado(
            "GET", f"_apis/testplan/Plans/{e['plan']}/Suites/{e['suite']}/TestPoint?api-version=7.1")["value"]}
        if len(points) == len(CAS):
            break
        ado("PATCH", chemin, ajout)
        time.sleep(2)
    for cas in CAS:
        c = e["cas"][cas["cle"]]
        c["point"] = points[c["id"]]
        iterations = len(cas.get("lignes") or [])
        print(f"  #{c['id']} {cas['titre']}" + (f" ({iterations} itérations)" if iterations else ""))
    ecrire(e)
    liens = 0
    for c in e["cas"].values():
        w = ado("GET", f"_apis/wit/workitems/{c['id']}?$expand=relations&api-version=7.1")
        liens += any(r["rel"] == "Microsoft.VSTS.Common.TestedBy-Reverse" for r in w.get("relations") or [])
        etat_cas = w["fields"]["System.State"]
    print(f"  {len(CAS)} cas en état {etat_cas}, {liens} liés à la story (lien Tests), "
          f"{sum(1 for c in CAS if c.get('parametres'))} paramétrés, étape partagée dans les {len(CAS)}")

# --- Étapes 4 et 8 : exécuter contre l'API locale --------------------------------------------------
def http(methode, chemin, corps=None):
    requete = urllib.request.Request(API + chemin, method=methode, headers={"Content-Type": "application/json"},
                                     data=None if corps is None else json.dumps(corps).encode())
    try:
        with urllib.request.urlopen(requete, timeout=10) as r:
            return r.status, r.headers, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read().decode()

class Api:
    """L'API lancée par dotnet run, redémarrée à chaque étape partagée : l'agenda est en mémoire."""
    def __init__(self):
        self.processus = None
        atexit.register(self.arreter)

    def demarrer(self):
        self.arreter()
        try:  # une autre API sur le même port répondrait à notre place, avec son propre agenda
            http("GET", "/sante")
            sys.exit(f"Une autre application répond déjà sur {API} : arrêtez-la, ou choisissez PORT=...")
        except OSError:
            pass
        self.processus = subprocess.Popen(
            ["dotnet", "run", "--no-build", "--project", "src/Santinord.Rdv.Api", "--urls", API], cwd=TRAVAIL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(240):
            if self.processus.poll() is not None:
                sys.exit(f"dotnet run s'est arrêté (code {self.processus.returncode}) : le port {API} est-il libre ?")
            try:
                return http("GET", "/sante")
            except OSError:
                time.sleep(0.25)
        sys.exit("L'API ne répond pas sur " + API)

    def arreter(self):
        # dotnet run lance l'API dans un processus enfant : on arrête tout le groupe.
        if self.processus and self.processus.poll() is None:
            os.killpg(self.processus.pid, signal.SIGTERM)
            self.processus.wait(timeout=30)
        self.processus = None

def attendu_http(texte):  # « 422, "motif":"HorsPlanning" » -> (422, "HorsPlanning") ; « 400, sans motif » -> (400, "")
    statut = int(texte[:3])
    if "sans motif" in texte:
        return statut, ""
    m = re.search(r'motif\W+([A-Za-z]+)', texte)
    return statut, m.group(1) if m else None

def jouer_etape(api, etape, ligne):
    """Joue une étape ; renvoie (réussie, requête et réponse obtenue)."""
    action, attendu, controle = etape
    attendu = remplir(attendu, ligne)
    if controle is None:
        statut, _, corps = api.demarrer()
        return statut == 200 and json.loads(corps).get("statut") == "ok", f"GET /sante : {statut} {corps}"
    if "get" in controle:
        chemin = f"/api/creneaux?praticienId={controle['get']}&date={resoudre(remplir(controle['date'], ligne))}"
        statut, _, corps = http("GET", chemin)
        trace = f"GET {chemin} : {statut} {corps if len(corps) < 200 else corps[:200] + '…'}"
        if statut != 200:
            return False, trace
        liste = json.loads(corps)
        if "contient" in controle:
            return resoudre(controle["contient"]) in liste, trace
        if "absent" in controle:
            return resoudre(controle["absent"]) not in liste, trace
        nombre = int(re.search(r"(\d+) créneau", attendu).group(1))
        bornes = re.search(r"de (\d\d:\d\d) à (\d\d:\d\d)", attendu)
        trace = f"GET {chemin} : {statut}, {len(liste)} créneau(x)" + (f" de {liste[0][11:16]} à {liste[-1][11:16]}" if liste else "")
        return len(liste) == nombre and (not bornes or (liste[0][11:16], liste[-1][11:16]) == bornes.groups()), trace
    praticien, patient, debut = (resoudre(remplir(v, ligne)) for v in controle["post"])
    demande = {"praticienId": praticien, "patientId": patient, "debut": debut}
    statut, entetes, corps = http("POST", "/api/rendez-vous", demande)
    trace = f"POST /api/rendez-vous {json.dumps(demande, ensure_ascii=False)} : {statut} {corps}"
    statut_attendu, motif = attendu_http(attendu)
    reponse = json.loads(corps) if corps else {}
    ok = statut == statut_attendu
    if motif == "":
        ok = ok and "motif" not in reponse
    elif motif:
        ok = ok and reponse.get("motif") == motif
    if statut_attendu == 201:
        ok = ok and (entetes.get("Location") or "").startswith("/api/rendez-vous/")
    return ok, trace

def executer(retest):
    e = lire()
    cles = [c["cle"] for c in CAS if not retest or c["cle"] in e["echecs"]]
    api = Api()
    api.demarrer()
    version = http("GET", "/version")[2]
    tete = subprocess.check_output(["git", "-C", TRAVAIL, "rev-parse", "HEAD"], text=True).strip()[:8]
    if json.loads(version).get("commit") != tete:  # on teste bien le code du dépôt, pas une ancienne compilation
        sys.exit(f"L'API annonce le commit {json.loads(version).get('commit')}, le dépôt est à {tete} : dotnet build, puis relancez.")
    titre ="Re-test après relivraison" if retest else "Réserver un créneau, exécution manuelle"
    run = ado("POST", "_apis/test/runs?api-version=7.1", {
        "name": titre, "plan": {"id": str(e["plan"])}, "isAutomated": False, "state": "InProgress",
        "pointIds": [e["cas"][c]["point"] for c in cles], "comment": f"{LEGENDE} ; /version : {version}"})
    resultats = {int(r["testCase"]["id"]): r["id"] for r in ado("GET", f"_apis/test/Runs/{run['id']}/results?api-version=7.1")["value"]}
    print(f"  run #{run['id']} « {titre} » ; {LEGENDE}")
    print(f"  /version : {version}")
    partagee, mises_a_jour, echecs = e["partagee"], [], {}
    for cle in cles:
        cas = PAR_CLE[cle]
        noms, iterations = cas.get("parametres", []), []
        for i, valeurs in enumerate(cas.get("lignes") or [[]], 1):
            ligne = dict(zip(noms, valeurs))
            debut, actions, traces, iteration_ok = horodatage(), [], [], True
            for n, etape in enumerate(cas["etapes"], 2):
                if etape is SANTE:
                    ok, trace = jouer_etape(api, ("", "", None), ligne)
                    issue = "Passed" if ok else "Failed"
                    actions.append({"actionPath": f"{n:08X}", "iterationId": i, "stepIdentifier": str(n), "outcome": issue,
                                    "sharedStepModel": {"id": partagee["id"], "revision": partagee["rev"]}})
                    actions.append({"actionPath": f"{n:08X}00000002", "iterationId": i, "stepIdentifier": f"{n};2", "outcome": issue})
                    attendu = '200, {"statut":"ok"}'
                else:
                    ok, trace = jouer_etape(api, etape, ligne)
                    attendu = remplir(etape[1], ligne)
                    action = {"actionPath": f"{n:08X}", "iterationId": i, "stepIdentifier": str(n), "outcome": "Passed" if ok else "Failed"}
                    if not ok:  # ce que Léa écrit dans le commentaire de l'étape : la requête et la réponse obtenue
                        action["errorMessage"] = action["comment"] = f"{trace} ; attendu : {attendu}"
                    actions.append(action)
                traces.append({"trace": trace, "attendu": attendu, "ok": ok})
                iteration_ok = iteration_ok and ok
            derniere = f"{len(cas['etapes']) + 1:08X}"
            iteration = {"id": i, "outcome": "Passed" if iteration_ok else "Failed", "startedDate": debut,
                         "completedDate": horodatage(), "actionResults": actions,
                         "parameters": [{"parameterName": k, "value": v, "iterationId": i, "actionPath": derniere,
                                         "stepIdentifier": str(len(cas["etapes"]) + 1)} for k, v in ligne.items()]}
            if not iteration_ok:
                iteration["comment"] = next(t["trace"] for t in traces if not t["ok"])
                echecs.setdefault(cle, []).append({"iteration": i, "ligne": ligne, "etapes": traces})
            iterations.append(iteration)
        issue = "Failed" if cle in echecs else "Passed"
        resultat = {"id": resultats[e["cas"][cle]["id"]], "outcome": issue, "state": "Completed", "iterationDetails": iterations}
        if cle in echecs:
            resultat["comment"] = f"{len(echecs[cle])} itération(s) sur {len(iterations)} en échec"
        mises_a_jour.append(resultat)
        detail = f", {len(iterations)} itérations" if len(iterations) > 1 else ""
        detail += f", dont {len(echecs[cle])} en échec" if cle in echecs else ""
        print(f"  {'ÉCHEC ' if cle in echecs else 'réussi'} #{e['cas'][cle]['id']} {cas['titre']}{detail}")
        for ech in echecs.get(cle, []):
            fautive = next(t for t in ech["etapes"] if not t["ok"])
            print(f"           {fautive['trace']}")
            print(f"           attendu : {fautive['attendu']}")
    api.arreter()
    ado("PATCH", f"_apis/test/Runs/{run['id']}/results?api-version=7.1", mises_a_jour)
    if retest:
        e["retest"] = {"run": run["id"], "echecs": echecs}
    else:
        e.update(run=run["id"], resultats={c: resultats[e["cas"][c]["id"]] for c in cles}, echecs=echecs, version=version)
    if not echecs or retest:  # avec un écart, le run reste ouvert : le bug se crée depuis le runner (étape 5)
        ado("PATCH", f"_apis/test/runs/{run['id']}?api-version=7.1", {"state": "Completed"})
    ecrire(e)
    points = ado("GET", f"_apis/testplan/Plans/{e['plan']}/Suites/{e['suite']}/TestPoint?api-version=7.1")["value"]
    bilan = {}
    for p in points:
        bilan[p["results"].get("outcome", "?")] = bilan.get(p["results"].get("outcome", "?"), 0) + 1
    print("  points de la suite : " + ", ".join(f"{n} {k}" for k, n in sorted(bilan.items())))

# --- Étape 5 : le bug -----------------------------------------------------------------------------
TITRE_BUG = ("Un patient obtient deux rendez-vous le même jour chez le même praticien "
             "si son identifiant change de casse ou d'espaces")

def bug(sha):
    e = lire()
    cle = "casse"
    if cle not in e["echecs"]:
        sys.exit("Le cas « casse et espaces » n'a pas échoué : rien à signaler.")
    cas, echecs = e["cas"][cle], e["echecs"][cle]
    v = json.loads(e["version"])
    etapes = "".join(f"<li>{html.escape(t['trace'])}" + ("" if t["ok"] else " <b>(obtenu)</b>") + "</li>" for t in echecs[0]["etapes"])
    autres = ", ".join(f"« {html.escape(x['ligne']['patient'])} »" for x in echecs[1:])
    repro = (f"<p>Cas de test #{cas['id']} « {html.escape(PAR_CLE[cle]['titre'])} », run #{e['run']}, configuration API locale. "
             f"API lancée sur le poste (dotnet run --project src/Santinord.Rdv.Api --urls {API}).</p>"
             f"<ol>{etapes}</ol>"
             f"<p><b>Attendu</b> : {html.escape(echecs[0]['etapes'][-1]['attendu'])}, comme pour « P-104233 » saisi à l'identique "
             "(critères d'acceptation 5 et 6 de la story « Réserver un créneau »).</p>"
             + (f"<p>Même écart avec {autres} : {len(echecs)} itérations sur {len(PAR_CLE[cle]['lignes'])} en échec.</p>" if autres else ""))
    b = creer_element("Bug", {
        "System.Title": TITRE_BUG, "System.AreaPath": PROJET, "System.IterationPath": SPRINT,
        "Microsoft.VSTS.TCM.ReproSteps": repro,
        "Microsoft.VSTS.Build.FoundIn": f"/version : {v['version']}, commit {v['commit']} ; SHA testé {sha}",
        "Microsoft.VSTS.Common.Severity": "2 - High", "Microsoft.VSTS.Common.Priority": 1},
        [lien("Microsoft.VSTS.Common.TestedBy-Forward", cas["id"]), lien("System.LinkTypes.Related", e["story"])])
    # Le bug rattaché au résultat : c'est ce que fait Create bug dans le runner (lien « Test Result »).
    ado("PATCH", f"_apis/test/Runs/{e['run']}/results?api-version=7.1", [{"id": e["resultats"][cle], "associatedBugs": [{"id": str(b["id"])}]}])
    ado("PATCH", f"_apis/test/runs/{e['run']}?api-version=7.1", {"state": "Completed"})
    e["bug"] = b["id"]
    ecrire(e)
    print(f"  bug #{b['id']} « {TITRE_BUG} »", file=sys.stderr)
    print(f"  Severity 2 - High, Priority 1, Found in Build : /version {v['version']} ({v['commit']}), SHA {sha}", file=sys.stderr)
    print(f"  liens : cas de test #{cas['id']} (Tested By), story #{e['story']} (Related), résultat du run #{e['run']}", file=sys.stderr)
    print(b["id"])

# --- Étape 9 : la régression ----------------------------------------------------------------------
def taguer(id_):
    w = ado("GET", f"_apis/wit/workitems/{id_}?fields=System.Tags&api-version=7.1")
    tags = [t.strip() for t in (w["fields"].get("System.Tags") or "").split(";") if t.strip()]
    if "regression" not in tags:
        modifier_element(id_, {"System.Tags": "; ".join(tags + ["regression"])})

def contenu(plan, suite):
    return sorted(c["workItem"]["id"] for c in ado("GET", f"_apis/testplan/Plans/{plan}/Suites/{suite}/TestCase?api-version=7.1")["value"])

def regression():
    e = lire()
    for cle in ("deja-pris", "hors-planning"):
        taguer(e["cas"][cle]["id"])
    requete = ("SELECT [System.Id], [System.WorkItemType], [System.Title], [System.State] FROM WorkItems "
               "WHERE [System.WorkItemType] IN GROUP 'Microsoft.TestCaseCategory' AND [System.Tags] CONTAINS 'regression'")
    suite = ado("POST", f"_apis/testplan/Plans/{e['plan']}/suites?api-version=7.1",
                {"suiteType": "dynamicTestSuite", "name": "Régression", "parentSuite": {"id": e["racine"]}, "queryString": requete})
    configurer(e["plan"], suite["id"], e["config"])  # à la création, la suite prend la configuration par défaut du projet
    e["regression"] = suite["id"]
    ecrire(e)
    print(f"  suite « Régression » #{suite['id']} (requête : Tags Contains regression) : {contenu(e['plan'], suite['id'])}")
    taguer(e["cas"]["doublon"]["id"])
    for _ in range(10):
        cas = contenu(e["plan"], suite["id"])
        if len(cas) == 4:
            break
        time.sleep(3)
    print(f"  tag sur un quatrième cas (#{e['cas']['doublon']['id']}), sans toucher à la suite : {cas}")

def tests_du_build(build):
    runs = ado("GET", f"_apis/test/runs?buildUri=vstfs:///Build/Build/{build}&includeRunDetails=true&api-version=7.1")["value"]
    for r in sorted(runs, key=lambda r: r["id"]):
        print(f"    onglet Tests : « {r['name']} » : {r.get('totalTests', 0)} test(s), {r.get('passedTests', 0)} réussi(s)")

def automatiser(build):  # bonus : ce que fait Associate Test Case dans l'onglet Tests du run
    e = lire()
    nom = "Un_patient_ne_contourne_pas_le_doublon_en_changeant_la_casse"
    for run in ado("GET", f"_apis/test/runs?buildUri=vstfs:///Build/Build/{build}&api-version=7.1")["value"]:
        for r in ado("GET", f"_apis/test/Runs/{run['id']}/results?api-version=7.1")["value"]:
            if (r.get("automatedTestName") or "").endswith(nom):
                w = modifier_element(e["cas"]["casse"]["id"], {
                    "Microsoft.VSTS.TCM.AutomatedTestName": r["automatedTestName"],
                    "Microsoft.VSTS.TCM.AutomatedTestStorage": r.get("automatedTestStorage") or "Santinord.Rdv.Domain.Tests.dll",
                    "Microsoft.VSTS.TCM.AutomatedTestId": str(uuid.uuid4()),
                    "Microsoft.VSTS.TCM.AutomatedTestType": r.get("automatedTestType") or "Unit Test"})
                print(f"  cas #{e['cas']['casse']['id']} associé à {r['automatedTestName']} : "
                      f"Automation status = {w['fields'].get('Microsoft.VSTS.TCM.AutomationStatus')}")
                return
    print("  test de non-régression introuvable dans les résultats du run")

def etat(expression):
    e = lire()
    print(eval(expression, {}, {"e": e}))

commande, *arguments = sys.argv[1:]
{"story": story, "plan": plan_et_suite, "cas": cas_de_test, "executer": lambda: executer(False),
 "retester": lambda: executer(True), "bug": bug, "regression": regression, "tests": tests_du_build,
 "automatiser": automatiser, "etat": etat}[commande](*arguments)
PY
tp3() {
  ORG="$ORG" PROJET="$PROJET" AUTH="$AUTH" ETAT="$ETAT" TRAVAIL="$TRAVAIL" PORT="$PORT" SPRINT="$SPRINT" PLAN="$PLAN" \
    python3 "$TP3_PY" "$@"
}

# --- Repos et pipelines ----------------------------------------------------------------------------

pr_statut() { azo repos pr show --id "$1" --query status -o tsv; }
attendre_pr() { # attendre_pr <id> [tentatives de 10 s] : jusqu'à la fusion
  for _ in $(seq 1 "${2:-60}"); do [ "$(pr_statut "$1")" = completed ] && return 0; sleep 10; done
  echo "  la PR $1 n'est pas terminée" >&2; return 1
}
build_de_la_pr() { azo repos pr policy list --id "$1" --query "[?configuration.type.displayName=='Build'].status | [0]" -o tsv; }
attendre_build_pr() { # attendre_build_pr <id> : approved ou rejected
  local s
  for _ in $(seq 1 90); do
    s="$(build_de_la_pr "$1")"
    case "$s" in approved|rejected) echo "$s"; return 0 ;; esac
    sleep 10
  done
  echo "timeout"
}
dernier_build_pr() { azo repos pr policy list --id "$1" --query "[?configuration.type.displayName=='Build'].context.buildId | [0]" -o tsv; }
attendre_push_dans_pr() { # attendre_push_dans_pr <id> : la PR voit le dernier commit local
  local local_sha; local_sha="$(git rev-parse HEAD)"
  for _ in $(seq 1 30); do
    [ "$(azo repos pr show --id "$1" --query lastMergeSourceCommit.commitId -o tsv)" = "$local_sha" ] && return 0
    sleep 3
  done
}
attendre_run() { # attendre_run <id> : jusqu'à la fin du run
  for _ in $(seq 1 120); do
    [ "$(azp pipelines runs show --id "$1" --query status -o tsv)" = completed ] && return 0
    sleep 10
  done
  echo "  le run $1 n'est pas terminé" >&2; return 1
}
stage_de() { # stage_de <run> <stage> : « completed succeeded », « inProgress None »…
  rest GET "_apis/build/builds/$1/timeline?api-version=7.1" \
    | json "next((r['state'] + ' ' + str(r['result']) for r in d['records'] if r['type'] == 'Stage' and r['identifier'] == '$2'), 'absent')"
}
construire() { # dotnet build silencieux, sauf en cas d'erreur
  local journal; journal="$(mktemp)"
  dotnet build --nologo -v q > "$journal" 2>&1 || { cat "$journal" >&2; rm -f "$journal"; return 1; }
  rm -f "$journal"
}
tests_locaux() { # tests_locaux <arguments de dotnet test> : la ligne de bilan de chaque projet ; code de retour de dotnet test
  local journal rc=0; journal="$(mktemp)"
  dotnet test --nologo "$@" > "$journal" 2>&1 || rc=$?
  grep -E '^(Réussi|Échoué|Passed|Failed)!' "$journal" | sed 's/^/  /' || true
  grep -E '^ +(Échoué|Failed) ' "$journal" | sed -E 's/^ +[^ ]+ /    test en échec : /' || true
  rm -f "$journal"
  return "$rc"
}

# ==================================================================================================

etape "Point de départ : projet, dépôt rdv-api, pipeline rdv-pr, Sprint 1"
if ! az devops project show --project "$PROJET" --org "$ORG" -o none --only-show-errors 2>/dev/null; then
  azo devops project create --name "$PROJET" --process Agile --source-control git --visibility private -o none
  echo "  projet $PROJET créé (Agile, Git, privé)"
fi
EQUIPE="$(az devops project show --project "$PROJET" --org "$ORG" --query defaultTeam.name -o tsv)"
SPRINT_ID="$(azp boards iteration project show --path "\\$PROJET\\Iteration\\Sprint 1" --query identifier -o tsv 2>/dev/null || true)"
if [ -z "$SPRINT_ID" ]; then
  read -r LUNDI FIN <<< "$(python3 -c 'import datetime as d; t = d.date.today(); l = t - d.timedelta(days=t.weekday()); print(l, l + d.timedelta(days=11))')"
  SPRINT_ID="$(azp boards iteration project create --name "Sprint 1" --start-date "$LUNDI" --finish-date "$FIN" --query identifier -o tsv)"
  echo "  itération Sprint 1 créée, du $LUNDI au $FIN"
fi
azp boards iteration team add --team "$EQUIPE" --id "$SPRINT_ID" -o none 2>/dev/null || true
echo "  Sprint 1 sélectionnée pour l'équipe « $EQUIPE »"

RID="$(azp repos show -r "$DEPOT" --query id -o tsv 2>/dev/null || true)"
[ -n "$RID" ] || { RID="$(azp repos create --name "$DEPOT" --query id -o tsv)"; echo "  dépôt $DEPOT créé"; }
URL="$(azp repos show -r "$DEPOT" --query remoteUrl -o tsv)"
if [ -n "$(azp repos ref list -r "$DEPOT" --filter heads/main --query "[0].objectId" -o tsv)" ]; then
  g clone -q "$URL" "$TRAVAIL"
  echo "  $DEPOT cloné dans $TRAVAIL"
else
  [ -d "$SOURCE" ] || { echo "Code de rdv-api introuvable : $SOURCE" >&2; exit 1; }
  cp -R "$SOURCE" "$TRAVAIL"
  rm -rf "$TRAVAIL/.git"
  (cd "$TRAVAIL" && git init -q -b main && git add . && git commit -q -m "Import de rdv-api" \
    && git remote add origin "$URL" && g push -q -u origin main)
  echo "  code de demos/fil-rouge/rdv-api poussé dans $DEPOT, cloné dans $TRAVAIL"
fi
cd "$TRAVAIL"

PIPE_PR="$(azp pipelines list --name rdv-pr --query "[0].id" -o tsv)"
if [ -z "$PIPE_PR" ]; then
  # --skip-first-run : sans lui, la commande renvoie le run et non le pipeline
  PIPE_PR="$(azp pipelines create --name rdv-pr --repository "$DEPOT" --repository-type tfsgit --branch main \
    --yml-path pipelines/pr-validation.yml --skip-first-run --query id -o tsv)"
  echo "  pipeline rdv-pr créé (pipelines/pr-validation.yml)"
fi
if [ "$(azp repos policy list --repository-id "$RID" --branch main --query "length([?type.displayName=='Build'])" -o tsv)" = 0 ]; then
  azp repos policy build create --repository-id "$RID" --branch main --build-definition-id "$PIPE_PR" \
    --display-name rdv-pr --queue-on-source-update-only false --manual-queue-only false --valid-duration 0 \
    --blocking true --enabled true -o none
  echo "  stratégie Build validation rdv-pr sur main"
fi
echo "  main protégée : $(azp repos policy list --repository-id "$RID" --branch main --query "join(', ', [].type.displayName)" -o tsv)"

construire
echo "  dotnet test (point de contrôle 0) :"
tests_locaux --no-build

etape "Étape 1 : la user story et ses critères"
US="$(tp3 story)"

etape "Étape 2 : le plan de test et la suite de la story"
tp3 plan "$US"

etape "Étape 3 : l'étape partagée et les cas de test"
tp3 cas

etape "Étape 4 : exécuter contre l'API locale ($(git log -1 --format=%h))"
tp3 executer
if [ "$(tp3 etat 'len(e["echecs"])')" = 0 ]; then
  echo "  aucun écart : le dépôt contient déjà le correctif, il n'y a ni bug ni relivraison à rejouer."
  exit 0
fi
[ "$(tp3 etat 'list(e["echecs"])')" = "['casse']" ] \
  || { echo "  écarts inattendus (voir ci-dessus) : vérifiez la date du poste et le dépôt avant de continuer." >&2; exit 1; }

etape "Étape 5 : un bug par écart"
BUG="$(tp3 bug "$(git log -1 --format=%h)")"
echo "  run terminé ; bug #$BUG : $(azo boards work-item show --id "$BUG" --query 'fields."System.State"' -o tsv)"

etape "Étape 6 : piloter la correction (Thomas)"
azo boards work-item update --id "$BUG" --state Active --assigned-to "$MOI" -o none
echo "  bug #$BUG : Active, assigné à $MOI"
BRANCHE="bugfix/$BUG-casse-patient"
git switch -q -c "$BRANCHE"
python3 - tests/Santinord.Rdv.Domain.Tests/AgendaTests.cs <<'PY'
import sys
fichier = sys.argv[1]
texte = open(fichier, encoding="utf-8").read()
test = '''    [Fact]
    [Trait("Category", "Regression")]
    public void Un_patient_ne_contourne_pas_le_doublon_en_changeant_la_casse()
    {
        var agenda = NouvelAgenda();
        agenda.Reserver(Leroy, "P-104233", Mardi.ToDateTime(new TimeOnly(10, 0)));

        var resultat = agenda.Reserver(Leroy, " p-104233", Mardi.ToDateTime(new TimeOnly(16, 0)));

        Assert.Equal(MotifRefus.DoublonPatient, resultat.Motif);
    }

'''
ancre = "    [Fact]\n    public void Un_patient_peut_voir_deux_praticiens_le_meme_jour()"
if ancre in texte:
    texte = texte.replace(ancre, test + ancre, 1)
else:  # dépôt modifié depuis la livraison : le test va à la fin de la classe
    fin = texte.rstrip().rfind("}")
    texte = texte[:fin] + "\n" + test.rstrip() + "\n" + texte[fin:]
open(fichier, "w", encoding="utf-8").write(texte)
PY
echo "  test Un_patient_ne_contourne_pas_le_doublon_en_changeant_la_casse ajouté, trait Regression :"
if tests_locaux --filter "Category=Regression"; then
  echo "  le test passe sans correctif : il ne reproduit pas le bug." >&2; exit 1
fi
git commit -q -am "Test de non-régression du bug #$BUG"
g push -q -u origin "$BRANCHE"
PR="$(azp repos pr create -r "$DEPOT" -s "$BRANCHE" -t main \
  --title "Le doublon patient ignore la casse et les espaces (bug #$BUG)" \
  --description "Test de non-régression d'abord, puis le correctif : la première validation doit échouer." \
  --work-items "$BUG" --query pullRequestId -o tsv)"
echo "  PR $PR (bug #$BUG dans Work items), build de validation : $(attendre_build_pr "$PR") (attendu : rejected)"
tp3 tests "$(dernier_build_pr "$PR")"

python3 - src/Santinord.Rdv.Domain/Agenda.cs "$BUG" <<'PY'
import sys
fichier, bug = sys.argv[1], sys.argv[2]
texte = open(fichier, encoding="utf-8").read()
ancre = "    public ResultatReservation Reserver(string praticienId, string patientId, DateTime debut)\n    {\n"
if ancre not in texte:
    sys.exit("Agenda.Reserver introuvable : corrigez à la main, au début de la méthode.")
correctif = (f"        // Bug #{bug} : « p-104233 » et « P-104233 » désignent le même patient.\n"
             "        patientId = patientId.Trim().ToUpperInvariant();\n\n")
open(fichier, "w", encoding="utf-8").write(texte.replace(ancre, ancre + correctif, 1))
PY
echo "  correctif dans Agenda.Reserver : patientId = patientId.Trim().ToUpperInvariant()"
tests_locaux
git commit -q -am "Corrige le bug #$BUG"
g push -q
attendre_push_dans_pr "$PR"
for _ in $(seq 1 20); do # le build rouge précédent doit laisser la place au nouveau run
  case "$(build_de_la_pr "$PR")" in queued|running) break ;; esac
  sleep 3
done
# Squash, branche supprimée, et surtout pas de fermeture automatique du bug à la fusion.
azo repos pr update --id "$PR" --auto-complete true --squash true --delete-source-branch true --transition-work-items false -o none
azo repos pr set-vote --id "$PR" --vote approve -o none
ATTENTE=60
case "$(azp repos policy list --repository-id "$RID" --branch main --query "[?type.displayName=='Minimum number of reviewers'].settings.creatorVoteCounts | [0]" -o tsv)" in
  [Ff]alse)
    ATTENTE=180
    echo "  la stratégie du TP 2 exige l'approbation d'un autre réviseur : demandez-la à votre binôme"
    echo "  $ORG/$PROJET_URL/_git/$DEPOT/pullrequest/$PR" ;;
esac
echo "  build de validation : $(attendre_build_pr "$PR") (attendu : approved)"
tp3 tests "$(dernier_build_pr "$PR")"
attendre_pr "$PR" "$ATTENTE"
FUSION="$(azo repos pr show --id "$PR" --query lastMergeCommit.commitId -o tsv)"
echo "  PR $PR fusionnée (squash), branche supprimée ; bug #$BUG encore $(azo boards work-item show --id "$BUG" --query 'fields."System.State"' -o tsv)"
echo "  builds rdv-pr de la PR :"
azp pipelines runs list --pipeline-ids "$PIPE_PR" --branch "refs/pull/$PR/merge" --query "reverse(sort_by(@, &id))[].[buildNumber, result]" -o tsv \
  | sed 's/^/    /'
azo boards work-item update --id "$BUG" --state Resolved --reason Fixed -o none
echo "  bug #$BUG : Resolved (Fixed)"

etape "Étape 7 : relivrer"
CICD="$(azp pipelines list --name rdv-ci-cd --query "[0].id" -o tsv)"
if [ -n "$CICD" ]; then
  # Le pipeline existe : la fusion l'a déclenché, avec la production (valeur par défaut du paramètre).
  RUN_CICD=""
  for _ in $(seq 1 30); do
    RUN_CICD="$(azp pipelines runs list --pipeline-ids "$CICD" --branch main --query "[?sourceVersion=='$FUSION'].id | [0]" -o tsv)"
    [ -n "$RUN_CICD" ] && break
    sleep 5
  done
  [ -n "$RUN_CICD" ] || { echo "  aucun run de rdv-ci-cd pour la fusion $FUSION" >&2; exit 1; }
  echo "  run $RUN_CICD déclenché par la fusion ; on attend le stage Recette"
  for _ in $(seq 1 120); do
    case "$(stage_de "$RUN_CICD" Recette)" in "completed "*) break ;; esac
    sleep 10
  done
  echo "  Recette : $(stage_de "$RUN_CICD" Recette) ; Production : $(stage_de "$RUN_CICD" Prod)"
  echo "  la production attend « Vérification avant production » : Resume ou Reject dans l'interface"
else
  # Les environments n'existent pas encore : un run lancé hors de l'assistant de création ne les crée pas.
  CICD="$(azp pipelines create --name rdv-ci-cd --repository "$DEPOT" --repository-type tfsgit --branch main \
    --yml-path azure-pipelines.yml --skip-first-run --query id -o tsv)"
  for env in rdv-dev rdv-recette rdv-prod; do
    ENV_ID="$(rest GET "_apis/distributedtask/environments?name=$env&api-version=7.1-preview.1" | json "d['value'][0]['id'] if d['value'] else ''")"
    [ -n "$ENV_ID" ] || ENV_ID="$(rest POST "_apis/distributedtask/environments?api-version=7.1-preview.1" "{\"name\":\"$env\"}" | json "d['id']")"
    # l'équivalent de View > Permit : le pipeline est autorisé à utiliser l'environment
    rest PATCH "_apis/pipelines/pipelinePermissions/environment/$ENV_ID?api-version=7.1-preview.1" \
      "{\"pipelines\":[{\"id\":$CICD,\"authorized\":true}]}" > /dev/null
  done
  echo "  pipeline rdv-ci-cd créé ; environments rdv-dev, rdv-recette, rdv-prod créés et autorisés"
  RUN_CICD="$(azp pipelines run --id "$CICD" --branch main --parameters cible=simulation deployerProduction=false --query id -o tsv)"
  echo "  run $RUN_CICD : cible simulation, production décochée"
  attendre_run "$RUN_CICD"
  echo "  résultat : $(azp pipelines runs show --id "$RUN_CICD" --query result -o tsv)"
fi
NUMERO="$(azp pipelines runs show --id "$RUN_CICD" --query buildNumber -o tsv)"
for stage in Build Dev Recette; do echo "    $stage : $(stage_de "$RUN_CICD" "$stage")"; done
tp3 tests "$RUN_CICD"
azo boards work-item update --id "$BUG" --fields "Microsoft.VSTS.Build.IntegrationBuild=$NUMERO" -o none
echo "  bug #$BUG : Integrated in Build = $NUMERO"

etape "Étape 8 : re-tester et fermer (Léa)"
git switch -q main
g pull -q --prune
git branch -q -D "$BRANCHE"
construire
echo "  main à jour ($(git log -1 --format=%h), le code que $NUMERO a livré), API relancée"
tp3 retester
if [ "$(tp3 etat 'len(e["retest"]["echecs"])')" != 0 ]; then
  azo boards work-item update --id "$BUG" --state Active --discussion "Re-test en échec sur $NUMERO : voir le run de re-test." -o none
  echo "  re-test en échec : bug #$BUG repassé Active" >&2; exit 1
fi
azo boards work-item update --id "$BUG" --state Closed -o none
CAS_CASSE="$(tp3 etat 'e["cas"]["casse"]["id"]')"
azo boards work-item update --id "$CAS_CASSE" --fields "System.Tags=regression" -o none
echo "  bug #$BUG : Closed ; cas #$CAS_CASSE tagué regression"

etape "Étape 9 : la régression"
tp3 regression
NUIT="$(azp pipelines list --name rdv-nuit --query "[0].id" -o tsv)"
if [ -z "$NUIT" ]; then
  NUIT="$(azp pipelines create --name rdv-nuit --repository "$DEPOT" --repository-type tfsgit --branch main \
    --yml-path pipelines/nightly-regression.yml --skip-first-run --query id -o tsv)"
  echo "  pipeline rdv-nuit créé (pipelines/nightly-regression.yml, chaque nuit de semaine à 2 h UTC)"
fi
RUN_NUIT="$(azp pipelines run --id "$NUIT" --branch main --query id -o tsv)"
attendre_run "$RUN_NUIT"
echo "  run $RUN_NUIT ($(azp pipelines runs show --id "$RUN_NUIT" --query buildNumber -o tsv)) : $(azp pipelines runs show --id "$RUN_NUIT" --query result -o tsv)"
tp3 tests "$RUN_NUIT"
tp3 automatiser "$RUN_NUIT"

etape "État final"
echo "  plan « $PLAN » : $ORG/$PROJET_URL/_testPlans/execute?planId=$(tp3 etat 'e["plan"]')"
echo "  bug #$BUG : $(rest GET "_apis/wit/workItems/$BUG/updates?api-version=7.1" \
  | json "' -> '.join(u['fields']['System.State']['newValue'] for u in d['value'] if 'System.State' in u.get('fields', {}))")"
echo "  PR $PR, rdv-ci-cd $NUMERO, rdv-nuit $RUN_NUIT"
git log --oneline -3 | sed 's/^/    /'
echo "  copie de travail : $TRAVAIL (à garder ou supprimer ; le projet, lui, sert au module 4)"
exit
}
