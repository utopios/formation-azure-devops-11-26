#!/usr/bin/env bash
# Rejoue le TP de synthèse ParkNord de bout en bout : Boards, Repos, Artifacts, Pipelines, Test Plans,
# puis la correction du bug trouvé en recette et la promotion du paquet dans la vue @Release.
#
# Usage :
#   ./rejouer-tp-synthese.sh <organisation> <prénom>        (projet créé : ParkNord-<prénom>)
#   ./rejouer-tp-synthese.sh mon-organisation Ihab
#
# Prérequis :
#   - az CLI avec l'extension azure-devops (az extension add -n azure-devops), puis az login
#     (ou un PAT, voir AZURE_DEVOPS_EXT_PAT) ;
#   - votre compte en Basic + Test Plans dans l'organisation, et un parallel job hébergé ;
#   - git, python3, curl et Node.js 20 ou plus récent ;
#   - le code de départ parknord-web : le script le cherche dans les supports (tp/synthese/parknord-web),
#     à côté du script, puis dans le dossier courant. Sinon : DEPART=<dossier> ./rejouer-tp-synthese.sh ...
#
# Le projet ParkNord-<prénom> ne doit pas exister : le TP part d'un projet neuf.
#
# Variables facultatives :
#   AZURE_DEVOPS_EXT_PAT=<PAT>  jeton d'accès personnel au lieu de az login (portée Full access, un jour)
#   GIT_AZ_TOKEN=1              git utilise le même jeton (az ou PAT) au lieu de Git Credential Manager
#   TRAVAIL=<dossier>           copie de travail locale (défaut : ~/parknord-solution)
#   DEPART=<dossier>            code de départ parknord-web
#
# Les cas de test sont joués comme dans le Test Runner : le script télécharge l'artefact « site » du
# run, charge sa page dans Node.js, saisit les valeurs de chaque itération, clique sur Calculer et
# compare le texte affiché au résultat attendu. Les résultats sont enregistrés dans Test Plans.
#
# Ce que le script ne fait pas : regarder les écrans (Taskboard, onglet Tests, historique des points),
# et les deux « Pour aller plus loin ».
# À donner après le TP : le script montre l'écart que les stagiaires doivent trouver eux-mêmes.

{ # Bash lit ce bloc en entier avant de l'exécuter : modifier le fichier pendant un run ne le casse pas.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '2,32p' "$0"; exit 1; }

ICI="$(cd "$(dirname "$0")" && pwd)"
ORG="https://dev.azure.com/$1"
PROJET="ParkNord-$2"
DEPOT="$PROJET"                       # le dépôt créé avec le projet porte son nom
TRAVAIL="${TRAVAIL:-$HOME/parknord-solution}"
SPRINT="$PROJET\\Sprint 1"
PIPELINE=parknord-ci
ETAT="$TRAVAIL/.git/synthese-etat.json"   # identifiants partagés avec la partie Python

if [ -z "${DEPART:-}" ]; then
  for d in "$ICI/../../../tp/synthese/parknord-web" "$ICI/parknord-web" "$PWD/parknord-web"; do
    [ -f "$d/js/tarifs.js" ] && { DEPART="$(cd "$d" && pwd)"; break; }
  done
fi
[ -n "${DEPART:-}" ] && [ -f "$DEPART/js/tarifs.js" ] || { echo "Code de départ parknord-web introuvable : DEPART=<dossier>." >&2; exit 1; }
[ ! -e "$TRAVAIL" ] || { echo "$TRAVAIL existe déjà : supprimez-le ou choisissez TRAVAIL=..." >&2; exit 1; }
for outil in az git python3 curl node; do
  command -v "$outil" > /dev/null || { echo "$outil est introuvable." >&2; exit 1; }
done
node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 20 ? 1 : 0)' \
  || { echo "Node.js 20 ou plus récent est nécessaire ($(node --version) installé)." >&2; exit 1; }

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
CONNEXION="$(curl -sS -H "$AUTH" "$ORG/_apis/connectionData")"
MOI="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["authenticatedUser"]["properties"]["Account"]["$value"])' "$CONNEXION")"
INSTANCE="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["instanceId"])' "$CONNEXION")"
PROJET_URL="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$PROJET")"
if az devops project show --project "$PROJET" --org "$ORG" -o none --only-show-errors 2>/dev/null; then
  echo "Le projet $PROJET existe déjà : supprimez-le (Project settings > Overview > Delete) ou changez de prénom." >&2
  exit 1
fi

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

# --- Boards, Artifacts, Test Plans et exécution des cas : la partie Python ------------------------

SYNTH_PY="$(mktemp "${TMPDIR:-/tmp}/synthese.XXXXXX")"
trap 'rm -f "$SYNTH_PY"' EXIT
cat > "$SYNTH_PY" <<'PY'
import datetime, glob, html, json, os, re, subprocess, sys, tempfile, time
import urllib.error, urllib.parse, urllib.request
from xml.sax.saxutils import escape

ORG, PROJET, ETAT, SPRINT, MOI = (os.environ[k] for k in ("ORG", "PROJET", "ETAT", "SPRINT", "MOI"))
ENTETE, JETON = os.environ["AUTH"].split(": ", 1)
ORG_NOM, P = ORG.rstrip("/").rsplit("/", 1)[1], urllib.parse.quote(PROJET)
HOTES = {"dev": f"{ORG}/{P}", "feeds": f"https://feeds.dev.azure.com/{ORG_NOM}/{P}",
         "pkgs": f"https://pkgs.dev.azure.com/{ORG_NOM}/{P}"}
FEED, PAQUET = "parknord", "parknord-tarifs"

class ErreurAdo(Exception):
    pass

def ado(methode, chemin, corps=None, type_contenu="application/json", hote="dev", fatal=True):
    requete = urllib.request.Request(HOTES[hote] + "/" + chemin, method=methode,
                                     data=None if corps is None else json.dumps(corps).encode(),
                                     headers={ENTETE: JETON, "Content-Type": type_contenu})
    try:
        with urllib.request.urlopen(requete) as reponse:
            texte = reponse.read().decode("utf-8-sig")
    except urllib.error.HTTPError as e:
        message = f"{methode} {chemin} : HTTP {e.code} {e.read().decode('utf-8', 'replace')[:600]}"
        if fatal:
            sys.exit(message)
        raise ErreurAdo(message)
    return json.loads(texte) if texte.strip() else None

def lien(relation, id_):
    return {"rel": relation, "url": f"{ORG}/_apis/wit/workItems/{id_}"}

def operations(champs, liens):
    ops = [{"op": "add", "path": "/fields/" + k, "value": v} for k, v in champs.items()]
    return ops + [{"op": "add", "path": "/relations/-", "value": l} for l in liens]

def creer_element(type_, champs, liens=()):
    return ado("POST", f"_apis/wit/workitems/${urllib.parse.quote(type_)}?api-version=7.1",
               operations(champs, liens), "application/json-patch+json")

def modifier_element(id_, champs, liens=()):
    return ado("PATCH", f"_apis/wit/workitems/{id_}?api-version=7.1", operations(champs, liens), "application/json-patch+json")

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

# --- Étape 1 : la feature, les stories, les tâches ------------------------------------------------
STORIES = {
    "us1": dict(titre="Calculer le prix d'un stationnement", points=3,
                description="En tant que client, je veux connaître le prix d'une durée de stationnement avant de me garer.",
                criteres=["Un stationnement de 15 minutes ou moins est gratuit.",
                          "Au-delà, chaque heure entamée coûte 2,50 € : 16 minutes coûtent 2,50 €, 1 h 01 coûte 5,00 €.",
                          "Une durée invalide est refusée avec un message, sans prix : minutes au-delà de 59, "
                          "valeur négative ou non entière."]),
    "us2": dict(titre="Plafonner le prix à 20 € par 24 heures", points=2,
                description="En tant que client qui stationne longtemps, je veux un prix plafonné à la journée.",
                criteres=["Sur une période de 24 heures, le prix ne dépasse jamais 20 €.",
                          "Au-delà de 24 heures, chaque période complète de 24 heures coûte 20 €, et le reste se paie "
                          "à l'heure entamée : 25 heures coûtent 22,50 €."]),
    "us3": dict(titre="Payer un ticket perdu", points=2,
                description="En tant que client qui a perdu son ticket, je veux savoir ce que je dois payer.",
                criteres=["Une case « Ticket perdu » est proposée à côté de la durée.",
                          "Case cochée, le prix est un forfait de 30 €, quelle que soit la durée saisie."]),
}

def boards():
    e = {}
    feature = creer_element("Feature", {"System.Title": "Simulateur de prix"})
    e["feature"] = feature["id"]
    print(f"  feature #{feature['id']} « Simulateur de prix »")
    for cle, s in STORIES.items():
        us = creer_element("User Story", {
            "System.Title": s["titre"], "System.IterationPath": SPRINT,
            "System.Description": f"<p>{html.escape(s['description'])}</p>",
            "Microsoft.VSTS.Common.AcceptanceCriteria": "<ol>" + "".join(f"<li>{html.escape(c)}</li>" for c in s["criteres"]) + "</ol>",
            "Microsoft.VSTS.Scheduling.StoryPoints": s["points"]},
            [lien("System.LinkTypes.Hierarchy-Reverse", feature["id"])])
        e[cle] = us["id"]
        print(f"  {cle.upper()} #{us['id']} « {s['titre']} », {s['points']} points, {len(s['criteres'])} critères")
    for cle, titre, reste in (("t1", "Écrire le test du forfait", 1), ("t2", "Coder le forfait", 2)):
        t = creer_element("Task", {"System.Title": titre, "System.IterationPath": SPRINT, "System.AssignedTo": MOI,
                                   "Microsoft.VSTS.Scheduling.RemainingWork": reste},
                          [lien("System.LinkTypes.Hierarchy-Reverse", e["us3"])])
        e[cle] = t["id"]
        print(f"  tâche #{t['id']} « {titre} » ({reste} h) sous US3")
    for cle in ("us1", "us2"):  # le code de départ les implémente : Resolved, pas Closed
        modifier_element(e[cle], {"System.State": "Resolved"})
    print("  US1 et US2 : Resolved (codées, pas encore recettées)")
    ecrire(e)

# --- Étape 3 : le feed, le droit de publier ----------------------------------------------------------
def feed(projet_id, instance):
    e = lire()
    npmjs = {"name": "npmjs", "protocol": "npm", "location": "https://registry.npmjs.org/", "upstreamSourceType": "public"}
    try:
        f = ado("POST", "_apis/packaging/feeds?api-version=7.1",
                {"name": FEED, "upstreamEnabled": True, "upstreamSources": [npmjs]}, hote="feeds", fatal=False)
        print(f"  feed « {FEED} » du projet, source amont npmjs", file=sys.stderr)
    except ErreurAdo as err:
        print(f"  (source amont refusée : {err} ; feed créé sans elle)", file=sys.stderr)
        f = ado("POST", "_apis/packaging/feeds?api-version=7.1", {"name": FEED}, hote="feeds")
    e["feed"] = f["id"]
    ecrire(e)
    chemin = f"_apis/packaging/Feeds/{f['id']}/permissions?api-version=7.1"
    droits = ado("GET", chemin + "&includeIds=true", hote="feeds")["value"]
    build = [d for d in droits if ":Build:" in json.dumps(d.get("identityDescriptor"))]
    if not any(projet_id in json.dumps(d["identityDescriptor"]) for d in build):
        build.append({"identityDescriptor": f"Microsoft.TeamFoundation.ServiceIdentity;{instance}:Build:{projet_id}"})
    for d in build:
        avant = d.get("role", "aucun")
        ado("PATCH", chemin, [{"identityDescriptor": d["identityDescriptor"], "role": "contributor"}], hote="feeds")
        print(f"  {d.get('displayName') or 'Build Service du projet'} : {avant} -> contributor (Feed Publisher)", file=sys.stderr)
    print(f"https://pkgs.dev.azure.com/{ORG_NOM}/{P}/_packaging/{FEED}/npm/registry/")

def paquets():
    e = lire()
    trouves = ado("GET", f"_apis/packaging/Feeds/{e['feed']}/packages?packageNameQuery={PAQUET}&includeAllVersions=true"
                         "&api-version=7.1", hote="feeds")["value"]
    versions = [v for p in trouves if p["name"] == PAQUET for v in p.get("versions", [])]
    if not versions:
        print(f"  feed « {FEED} » : aucune version de {PAQUET}")
    for v in sorted(versions, key=lambda v: [int(x) for x in v["version"].split(".")]):
        vues = ", ".join("@" + w["name"] for w in v.get("views") or [])
        print(f"  {PAQUET} {v['version']}" + (f" ({vues})" if vues else ""))

def promouvoir(version):
    e = lire()
    ado("PATCH", f"_apis/packaging/feeds/{e['feed']}/npm/{PAQUET}/versions/{version}?api-version=7.1",
        {"views": {"op": "add", "path": "/views/-", "value": "Release"}}, hote="pkgs")
    print(f"  {PAQUET} {version} promue dans @Release")

# --- Étape 7 : plan, suites, étape partagée, cas de test -------------------------------------------
PARTAGEE = ("Ouvrir le index.html du site à recetter : l'artefact site du dernier run de main",
            "La page « Simulateur de prix » s'affiche, et le pied de page indique la version du run")
SAISIE = ("Saisir @heures heures et @minutes minutes, puis cliquer sur Calculer", "La page affiche @resultat")
INVALIDE = "Durée invalide (message en rouge, sans prix)"
CAS = [
    dict(cle="gratuit", suite="us1", titre="Les 15 premières minutes sont gratuites",
         lignes=[["0", "5", "Prix : 0,00 €"], ["0", "10", "Prix : 0,00 €"], ["0", "15", "Prix : 0,00 €"]]),
    dict(cle="heures", suite="us1", titre="Chaque heure entamée coûte 2,50 €",
         lignes=[["0", "16", "Prix : 2,50 €"], ["1", "0", "Prix : 2,50 €"], ["1", "1", "Prix : 5,00 €"], ["3", "30", "Prix : 10,00 €"]]),
    dict(cle="invalide", suite="us1", titre="Une durée invalide est refusée",
         lignes=[["1", "75", INVALIDE], ["-1", "0", INVALIDE]]),
    dict(cle="plafond", suite="us2", titre="Le prix est plafonné à 20 € par période de 24 heures",
         lignes=[["8", "0", "Prix : 20,00 €"], ["12", "0", "Prix : 20,00 €"], ["24", "0", "Prix : 20,00 €"], ["25", "0", "Prix : 22,50 €"]]),
    dict(cle="perdu", suite="us3", titre="Un ticket perdu coûte le forfait de 30 €",
         etape=("Cocher Ticket perdu, saisir 2 heures et 0 minute, puis cliquer sur Calculer", "Prix : 30,00 €"),
         saisie={"heures": "2", "minutes": "0", "ticketPerdu": True, "resultat": "Prix : 30,00 €"}),
]
PARAMETRES = ["heures", "minutes", "resultat"]
PAR_CLE = {c["cle"]: c for c in CAS}

def xml_texte(texte):  # du HTML, lui-même échappé dans le XML du champ Steps
    return '<parameterizedString isformatted="true">' + escape("<DIV><P>" + escape(texte) + "</P></DIV>") + "</parameterizedString>"

def xml_etapes(etapes, partagee):  # None = l'étape partagée
    morceaux = []
    for n, etape in enumerate(etapes, 2):
        if etape is None:
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

def etapes_du_cas(cas):
    return [None, cas.get("etape") or SAISIE]

def plan():
    e = lire()
    p = ado("POST", "_apis/testplan/plans?api-version=7.1", {"name": "ParkNord - Sprint 1", "areaPath": PROJET, "iteration": SPRINT})
    configs = ado("GET", "_apis/testplan/configurations?api-version=7.1")["value"]
    config = next((c for c in configs if c.get("isDefault")), configs[0])
    e.update(plan=p["id"], config=config["id"], suites={}, cas={}, runs={}, echecs={})
    print(f"  plan « ParkNord - Sprint 1 » #{p['id']}, configuration « {config['name']} »")
    for cle in ("us1", "us2", "us3"):
        s = ado("POST", f"_apis/testplan/Plans/{p['id']}/suites?api-version=7.1",
                {"suiteType": "requirementTestSuite", "name": STORIES[cle]["titre"],
                 "parentSuite": {"id": p["rootSuite"]["id"]}, "requirementId": e[cle]})
        e["suites"][cle] = s["id"]
        print(f"  suite basée sur l'exigence #{s['id']} « {s['name']} »")
    partagee = creer_element("Shared Steps", {"System.Title": "Ouvrir le simulateur à recetter", "System.AreaPath": PROJET,
                                              "Microsoft.VSTS.TCM.Steps": xml_etapes([PARTAGEE], 0)})
    e["partagee"] = {"id": partagee["id"], "rev": partagee["rev"]}
    print(f"  étape partagée « Ouvrir le simulateur à recetter » #{partagee['id']}")
    for cas in CAS:
        champs = {"System.Title": cas["titre"], "System.AreaPath": PROJET, "System.IterationPath": SPRINT,
                  "Microsoft.VSTS.TCM.Steps": xml_etapes(etapes_du_cas(cas), partagee["id"])}
        if cas.get("lignes"):
            champs["Microsoft.VSTS.TCM.Parameters"] = "<parameters>" + "".join(
                f'<param name="{n}" bind="default" />' for n in PARAMETRES) + "</parameters>"
            champs["Microsoft.VSTS.TCM.LocalDataSource"] = xml_donnees(PARAMETRES, cas["lignes"])
        tc = creer_element("Test Case", champs, [lien("Microsoft.VSTS.TestCase.SharedStepReferencedBy-Reverse", partagee["id"])])
        e["cas"][cas["cle"]] = {"id": tc["id"], "suite": cas["suite"]}
    # Ajouter un cas à une suite basée sur l'exigence crée le lien Tests vers la story. Sans
    # pointAssignments, la nouvelle API n'affecte aucune configuration : aucun point de test.
    for cle_suite, suite in e["suites"].items():
        chemin = f"_apis/testplan/Plans/{p['id']}/Suites/{suite}/TestCase?api-version=7.1"
        ids = [c["id"] for c in e["cas"].values() if c["suite"] == cle_suite]
        ajout = [{"workItem": {"id": i}, "pointAssignments": [{"configurationId": config["id"]}]} for i in ids]
        ado("POST", chemin, ajout)
        for _ in range(10):
            points = {int(pt["testCaseReference"]["id"]): pt["id"] for pt in ado(
                "GET", f"_apis/testplan/Plans/{p['id']}/Suites/{suite}/TestPoint?api-version=7.1")["value"]}
            if len(points) == len(ids):
                break
            ado("PATCH", chemin, ajout)
            time.sleep(2)
        for c in e["cas"].values():
            if c["suite"] == cle_suite:
                c["point"] = points[c["id"]]
    for cas in CAS:
        n = len(cas.get("lignes") or [])
        print(f"  #{e['cas'][cas['cle']]['id']} {cas['titre']} (suite {cas['suite'].upper()}" + (f", {n} itérations)" if n else ")"))
    ecrire(e)

# --- Étapes 7 et 8 : jouer les cas sur le site produit par le pipeline ------------------------------
SIMULATEUR_JS = r"""
const fs = require("fs"), vm = require("vm"), path = require("path");
const site = process.argv[2], entrees = JSON.parse(process.argv[3]);
const page = fs.readFileSync(path.join(site, "index.html"), "utf8");
const elements = {};
for (const [, id] of page.matchAll(/id="([^"]+)"/g)) {
  elements[id] = { value: "", checked: false, textContent: "", className: "", ecouteurs: {},
                   addEventListener(type, f) { this.ecouteurs[type] = f; } };
}
const contexte = vm.createContext({ document: { getElementById: (id) => elements[id] || null } });
for (const [, src] of page.matchAll(/<script src="([^"]+)"/g)) {
  vm.runInContext(fs.readFileSync(path.join(site, src), "utf8"), contexte, { filename: src });
}
const sorties = entrees.map(({ heures, minutes, ticketPerdu }) => {
  if (ticketPerdu && !elements["ticket-perdu"]) return { texte: "pas de case Ticket perdu dans la page", classe: "" };
  elements.heures.value = heures;
  elements.minutes.value = minutes;
  if (elements["ticket-perdu"]) elements["ticket-perdu"].checked = Boolean(ticketPerdu);
  elements.resultat.textContent = "";
  elements.resultat.className = "";
  try {
    elements.simulateur.ecouteurs.submit({ preventDefault() {} });
  } catch (erreur) {
    return { texte: "erreur JavaScript : " + erreur.message, classe: "" };
  }
  return { texte: elements.resultat.textContent, classe: elements.resultat.className };
});
console.log(JSON.stringify(sorties));
"""

def simuler(site, entrees):
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
        f.write(SIMULATEUR_JS)
    try:
        return json.loads(subprocess.check_output(["node", f.name, site, json.dumps(entrees)], text=True))
    finally:
        os.unlink(f.name)

def conforme(sortie, attendu):
    if attendu == INVALIDE:
        return sortie["classe"] == "erreur" and sortie["texte"].startswith("Durée invalide")
    return sortie["classe"] == "prix" and sortie["texte"] == attendu

def executer(site, retest="0"):
    e = lire()
    retest = retest == "1"
    page = open(os.path.join(site, "index.html"), encoding="utf-8").read()
    m = re.search(r"Version (\d+\.\d+\.\d+)", page)
    version = m.group(1) if m else None
    cles = [c["cle"] for c in CAS if not retest or c["cle"] in e["echecs"]]
    # Les saisies de tous les cas, jouées d'un coup dans la page.
    saisies = []
    for cle in cles:
        cas = PAR_CLE[cle]
        lignes = [dict(zip(PARAMETRES, l)) for l in cas["lignes"]] if cas.get("lignes") else [cas["saisie"]]
        saisies += [(cle, i, l) for i, l in enumerate(lignes, 1)]
    sorties = simuler(site, [{"heures": l["heures"], "minutes": l["minutes"], "ticketPerdu": l.get("ticketPerdu", False)} for _, _, l in saisies])
    obtenu = {(cle, i): (l, s) for (cle, i, l), s in zip(saisies, sorties)}
    print(f"  site téléchargé : pied de page « Version {version or '?'} »")
    partagee, echecs, par_suite = e["partagee"], {}, {}
    for cle in cles:
        par_suite.setdefault(PAR_CLE[cle]["suite"], []).append(cle)
    for cle_suite, cles_suite in par_suite.items():
        titre = ("Re-test" if retest else "Recette") + f" de « {STORIES[cle_suite]['titre']} », site {version}"
        run = ado("POST", "_apis/test/runs?api-version=7.1", {
            "name": titre, "plan": {"id": str(e["plan"])}, "isAutomated": False, "state": "InProgress",
            "pointIds": [e["cas"][c]["point"] for c in cles_suite], "comment": f"Site de l'artefact du run {version}"})
        resultats = {int(r["testCase"]["id"]): r["id"] for r in ado("GET", f"_apis/test/Runs/{run['id']}/results?api-version=7.1")["value"]}
        mises_a_jour = []
        for cle in cles_suite:
            cas, iterations = PAR_CLE[cle], []
            n_lignes = len(cas["lignes"]) if cas.get("lignes") else 1
            for i in range(1, n_lignes + 1):
                ligne, sortie = obtenu[(cle, i)]
                debut = horodatage()
                ok_page = version is not None
                ok = ok_page and conforme(sortie, ligne["resultat"])
                attendu = ligne["resultat"]
                actions = [
                    {"actionPath": "00000002", "iterationId": i, "stepIdentifier": "2", "outcome": "Passed" if ok_page else "Failed",
                     "sharedStepModel": {"id": partagee["id"], "revision": partagee["rev"]}},
                    {"actionPath": "0000000200000002", "iterationId": i, "stepIdentifier": "2;2", "outcome": "Passed" if ok_page else "Failed"},
                ]
                saisie = {"actionPath": "00000003", "iterationId": i, "stepIdentifier": "3", "outcome": "Passed" if ok else "Failed"}
                if not ok:  # ce que la recette écrit dans le commentaire de l'étape : ce que la page a affiché
                    saisie["errorMessage"] = saisie["comment"] = f"La page affiche « {sortie['texte']} » ; attendu : {attendu}"
                actions.append(saisie)
                iteration = {"id": i, "outcome": "Passed" if ok else "Failed", "startedDate": debut, "completedDate": horodatage(),
                             "actionResults": actions}
                if cas.get("lignes"):
                    iteration["parameters"] = [{"parameterName": k, "value": ligne[k], "iterationId": i, "actionPath": "00000003",
                                                "stepIdentifier": "3"} for k in PARAMETRES]
                if not ok:
                    iteration["comment"] = saisie["comment"]
                    echecs.setdefault(cle, []).append({"iteration": i, "ligne": ligne, "obtenu": sortie["texte"], "attendu": attendu})
                iterations.append(iteration)
            resultat = {"id": resultats[e["cas"][cle]["id"]], "outcome": "Failed" if cle in echecs else "Passed",
                        "state": "Completed", "iterationDetails": iterations}
            if cle in echecs:
                resultat["comment"] = f"{len(echecs[cle])} itération(s) sur {len(iterations)} en échec"
            mises_a_jour.append(resultat)
            e["cas"][cle]["resultat"] = {"run": run["id"], "id": resultats[e["cas"][cle]["id"]]}
            detail = f", {len(iterations)} itérations" if len(iterations) > 1 else ""
            detail += f", dont {len(echecs[cle])} en échec" if cle in echecs else ""
            print(f"  {'ÉCHEC ' if cle in echecs else 'réussi'} #{e['cas'][cle]['id']} {cas['titre']}{detail}")
            for ech in echecs.get(cle, []):
                l = ech["ligne"]
                print(f"           {l['heures']} h {l['minutes']} min : la page affiche « {ech['obtenu']} », attendu « {ech['attendu']} »")
        ado("PATCH", f"_apis/test/Runs/{run['id']}/results?api-version=7.1", mises_a_jour)
        en_echec = any(c in echecs for c in cles_suite)
        if en_echec and not retest:  # le run reste ouvert : le bug se crée depuis le runner
            e["runs"][str(run["id"])] = "ouvert"
        else:
            ado("PATCH", f"_apis/test/runs/{run['id']}?api-version=7.1", {"state": "Completed"})
        print(f"  run de test #{run['id']} « {titre} »")
    if retest:
        e["echecs_retest"] = echecs
    else:
        e.update(echecs=echecs, version_recette=version)
    ecrire(e)

def bug():
    e = lire()
    if list(e["echecs"]) != ["gratuit"] or len(e["echecs"]["gratuit"]) != 1:
        sys.exit("Écarts inattendus : un seul écart était attendu, sur 15 minutes. Vérifiez le dépôt et le site téléchargé.")
    cle = "gratuit"
    cas, ech = e["cas"][cle], e["echecs"][cle][0]
    l = ech["ligne"]
    titre = f"{l['heures']} h {l['minutes']} min de stationnement : la page affiche « {ech['obtenu']} » au lieu de « {ech['attendu']} »"
    repro = (f"<p>Cas de test #{cas['id']} « {html.escape(PAR_CLE[cle]['titre'])} », itération {ech['iteration']}, "
             f"site de l'artefact du run {html.escape(e['version_recette'])}.</p>"
             "<ol><li>Ouvrir le index.html de l'artefact site.</li>"
             f"<li>Saisir {l['heures']} heure et {l['minutes']} minutes, puis cliquer sur Calculer.</li></ol>"
             f"<p><b>Obtenu</b> : {html.escape(ech['obtenu'])}. <b>Attendu</b> : {html.escape(ech['attendu'])} "
             "(critère d'acceptation 1 de « Calculer le prix d'un stationnement » : 15 minutes ou moins, c'est gratuit).</p>"
             "<p>Les itérations 5 et 10 minutes donnent bien 0,00 €.</p>")
    b = creer_element("Bug", {
        "System.Title": titre, "System.AreaPath": PROJET, "System.IterationPath": SPRINT,
        "Microsoft.VSTS.TCM.ReproSteps": repro, "Microsoft.VSTS.Build.FoundIn": e["version_recette"],
        "Microsoft.VSTS.Common.Severity": "3 - Medium", "Microsoft.VSTS.Common.Priority": 2},
        [lien("Microsoft.VSTS.Common.TestedBy-Forward", cas["id"]), lien("System.LinkTypes.Related", e["us1"])])
    # Le bug rattaché au résultat : c'est ce que fait Create bug dans le runner.
    r = cas["resultat"]
    ado("PATCH", f"_apis/test/Runs/{r['run']}/results?api-version=7.1", [{"id": r["id"], "associatedBugs": [{"id": str(b["id"])}]}])
    for run in [k for k, v in e["runs"].items() if v == "ouvert"]:
        ado("PATCH", f"_apis/test/runs/{run}?api-version=7.1", {"state": "Completed"})
        e["runs"][run] = "terminé"
    e["bug"] = b["id"]
    ecrire(e)
    print(f"  bug #{b['id']} « {titre} »", file=sys.stderr)
    print(f"  Found in Build {e['version_recette']}, Severity 3 - Medium ; liens : cas #{cas['id']}, US1 #{e['us1']}", file=sys.stderr)
    print(b["id"])

def points():
    e = lire()
    bilan = {}
    for suite in e["suites"].values():
        for p in ado("GET", f"_apis/testplan/Plans/{e['plan']}/Suites/{suite}/TestPoint?api-version=7.1")["value"]:
            issue = p["results"].get("outcome", "?")
            bilan[issue] = bilan.get(issue, 0) + 1
    print("  points de test du plan : " + ", ".join(f"{n} {k}" for k, n in sorted(bilan.items())))

def tests(build):
    runs = ado("GET", f"_apis/test/runs?buildUri=vstfs:///Build/Build/{build}&includeRunDetails=true&api-version=7.1")["value"]
    for r in sorted(runs, key=lambda r: r["id"]):
        total, reussis = r.get("totalTests", 0), r.get("passedTests", 0)
        print(f"    onglet Tests : « {r['name']} » : {total} test(s), {reussis} réussi(s)")
        if total != reussis:
            for res in ado("GET", f"_apis/test/Runs/{r['id']}/results?outcomes=Failed&api-version=7.1")["value"]:
                print(f"      en échec : {res.get('testCaseTitle')}")

def etat(expression):
    print(eval(expression, {}, {"e": lire()}))

commande, *arguments = sys.argv[1:]
{"boards": boards, "feed": feed, "paquets": paquets, "promouvoir": promouvoir, "plan": plan, "executer": executer,
 "bug": bug, "points": points, "tests": tests, "etat": etat}[commande](*arguments)
PY
synth() {
  ORG="$ORG" PROJET="$PROJET" AUTH="$AUTH" ETAT="$ETAT" SPRINT="$SPRINT" MOI="$MOI" python3 "$SYNTH_PY" "$@"
}

# --- Repos et pipelines ----------------------------------------------------------------------------

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
etat() { azo boards work-item update --id "$1" --state "$2" -o none; }
etat_de() { azo boards work-item show --id "$1" --query 'fields."System.State"' -o tsv; }
pr_statut() { azo repos pr show --id "$1" --query status -o tsv; }
attendre_pr() { # attendre_pr <id> : jusqu'à la fusion
  for _ in $(seq 1 60); do [ "$(pr_statut "$1")" = completed ] && return 0; sleep 10; done
  echo "  la PR $1 n'est pas terminée" >&2; return 1
}
build_de_la_pr() { azo repos pr policy list --id "$1" --query "[?configuration.type.displayName=='Build'].status | [0]" -o tsv; }
dernier_build_pr() { azo repos pr policy list --id "$1" --query "[?configuration.type.displayName=='Build'].context.buildId | [0]" -o tsv; }
attendre_build_pr() { # attendre_build_pr <id> : approved ou rejected
  local s
  for _ in $(seq 1 90); do
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
fusionner() { # fusionner <pr> : squash, branche supprimée, work items laissés dans leur état
  azo repos pr update --id "$1" --auto-complete true --squash true --delete-source-branch true --transition-work-items false -o none
  azo repos pr set-vote --id "$1" --vote approve -o none
}
attendre_run() { # attendre_run <id> : jusqu'à la fin du run
  for _ in $(seq 1 120); do
    [ "$(azp pipelines runs show --id "$1" --query status -o tsv)" = completed ] && return 0
    sleep 10
  done
  echo "  le run $1 n'est pas terminé" >&2; return 1
}
stage_de() { # stage_de <run> <stage> : « completed succeeded », « completed skipped »…
  rest GET "_apis/build/builds/$1/timeline?api-version=7.1" \
    | json "next((r['state'] + ' ' + str(r['result']) for r in d['records'] if r['type'] == 'Stage' and r['identifier'] == '$2'), 'absent')"
}
bilan_run() { # bilan_run <run> : nom, résultat, stages, tests
  echo "  run $(azp pipelines runs show --id "$1" --query buildNumber -o tsv) : $(azp pipelines runs show --id "$1" --query result -o tsv)"
  for stage in Verifier Site Paquet; do echo "    $stage : $(stage_de "$1" "$stage")"; done
  synth tests "$1"
}
run_de_main() { # run_de_main <commit> : le run de parknord-ci déclenché par la fusion
  local run=""
  for _ in $(seq 1 30); do
    run="$(azp pipelines runs list --pipeline-ids "$PIPE" --branch main --query "[?sourceVersion=='$1'].id | [0]" -o tsv)"
    [ -n "$run" ] && { echo "$run"; return 0; }
    sleep 5
  done
  echo "  aucun run de $PIPELINE pour le commit $1" >&2; return 1
}
telecharger_site() { # telecharger_site <run> <dossier vide> : l'artefact site, décompressé ; affiche le dossier de index.html
  local page
  azp pipelines runs artifact download --run-id "$1" --artifact-name site --path "$2" -o none
  python3 - "$2" <<'PY'
import glob, sys, zipfile
for z in glob.glob(sys.argv[1] + "/**/*.zip", recursive=True):
    zipfile.ZipFile(z).extractall(sys.argv[1])
PY
  page="$(find "$2" -name index.html | head -1)"
  [ -n "$page" ] || { echo "  index.html absent de l'artefact site du run $1" >&2; return 1; }
  dirname "$page"
}
tests_locaux() { # le bilan de node --test ; échoue, avec les tests en échec, si un test échoue
  local sortie rc=0
  sortie="$(node --test --test-reporter=tap 2>&1)" || rc=$?
  echo "  node --test : $(printf '%s\n' "$sortie" | grep -E '^# (tests|pass|fail) ' | sed 's/^# //' | tr '\n' ' ')"
  [ "$rc" = 0 ] || { printf '%s\n' "$sortie" | grep -E '^ *not ok' | sed 's/^ */    en échec : /' >&2; return "$rc"; }
}

# ==================================================================================================

etape "Étape 0 : créer le projet"
azo devops project create --name "$PROJET" --process Agile --source-control git --visibility private -o none
PROJET_ID="$(az devops project show --project "$PROJET" --org "$ORG" --query id -o tsv)"
EQUIPE="$(az devops project show --project "$PROJET" --org "$ORG" --query defaultTeam.name -o tsv)"
echo "  projet $PROJET (Agile, Git, privé), équipe « $EQUIPE »"

etape "Étape 1 : Boards, le backlog du Sprint 1"
read -r DEBUT FIN <<< "$(python3 -c 'import datetime as d; t = d.date.today(); print(t, t + d.timedelta(days=13))')"
CHEMIN_SPRINT="\\$PROJET\\Iteration\\Sprint 1"
SPRINT_ID="$(azp boards iteration project show --path "$CHEMIN_SPRINT" --query identifier -o tsv 2>/dev/null || true)"
if [ -z "$SPRINT_ID" ]; then
  SPRINT_ID="$(azp boards iteration project create --name "Sprint 1" --start-date "$DEBUT" --finish-date "$FIN" --query identifier -o tsv)"
else
  azp boards iteration project update --path "$CHEMIN_SPRINT" --start-date "$DEBUT" --finish-date "$FIN" -o none
fi
azp boards iteration team add --team "$EQUIPE" --id "$SPRINT_ID" -o none 2>/dev/null || true
echo "  Sprint 1 du $DEBUT au $FIN, sélectionné pour l'équipe"
RID="$(azp repos show -r "$DEPOT" --query id -o tsv)"
URL="$(azp repos show -r "$DEPOT" --query remoteUrl -o tsv)"
cp -R "$DEPART" "$TRAVAIL"
rm -rf "$TRAVAIL/.git" "$TRAVAIL/node_modules"
cd "$TRAVAIL"
git init -q -b main
synth boards
for v in US1 US2 US3 T1 T2; do printf -v "$v" '%s' "$(synth etat "e['$(echo "$v" | tr 'A-Z' 'a-z')']")"; done

etape "Étape 2 : Repos, pousser le code de départ"
git add .
git commit -q -m "Code de départ du simulateur de prix #$US1 #$US2"
git remote add origin "$URL"
g push -q -u origin main
tests_locaux
echo "  main poussée ; le commit est lié à US1 #$US1 et US2 #$US2"

etape "Étape 3 : Artifacts, le feed du projet"
REGISTRE="$(synth feed "$PROJET_ID" "$INSTANCE")"
printf 'registry=%s\n' "$REGISTRE" > .npmrc
git add .npmrc
git commit -q -m "Feed npm du projet"
g push -q
echo "  .npmrc : registry=$REGISTRE (aucun secret)"

etape "Étape 4 : Pipelines, le pipeline d'intégration continue"
cat > azure-pipelines.yml <<'YAML'
# Intégration continue de parknord-web : vérifier le code, produire le site
# numéroté, publier le calcul comme paquet npm dans le feed du projet.
# La validation des pull requests passe par la stratégie de branche de main.

name: 1.0.$(Rev:r)

trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-24.04

variables:
  versionNode: 22.x

stages:
  - stage: Verifier
    displayName: Vérifier le code
    jobs:
      - job: Tests
        steps:
          - task: UseNode@1
            displayName: Node.js $(versionNode)
            inputs:
              version: $(versionNode)

          - script: >
              node --test
              --test-reporter=spec --test-reporter-destination=stdout
              --test-reporter=junit --test-reporter-destination=resultats-tests.xml
            displayName: Tests unitaires

          - task: PublishTestResults@2
            displayName: Publier les résultats des tests
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: resultats-tests.xml
              testRunTitle: parknord $(Build.BuildNumber)

  - stage: Site
    displayName: Produire le site
    dependsOn: Verifier
    jobs:
      - job: Site
        steps:
          - bash: |
              set -euo pipefail
              site="$(Build.ArtifactStagingDirectory)/site"
              mkdir -p "$site"
              cp -R index.html css js "$site/"
              sed -i "s/__VERSION__/$(Build.BuildNumber)/" "$site/index.html"
            displayName: Copier le site et y inscrire la version

          - task: PublishPipelineArtifact@1
            displayName: Publier l'artefact site
            inputs:
              targetPath: $(Build.ArtifactStagingDirectory)/site
              artifact: site

  - stage: Paquet
    displayName: Publier le paquet
    dependsOn: Site
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: Npm
        steps:
          - task: UseNode@1
            displayName: Node.js $(versionNode)
            inputs:
              version: $(versionNode)

          - task: npmAuthenticate@0
            displayName: S'authentifier auprès du feed
            inputs:
              workingFile: .npmrc

          - bash: |
              set -euo pipefail
              npm version "$(Build.BuildNumber)" --no-git-tag-version --allow-same-version
              npm publish
            displayName: Publier parknord-tarifs $(Build.BuildNumber)
YAML
git add azure-pipelines.yml
git commit -q -m "Pipeline d'intégration continue"
g push -q
# --skip-first-run : sans lui, la commande renvoie le run et non le pipeline
PIPE="$(azp pipelines create --name "$PIPELINE" --repository "$DEPOT" --repository-type tfsgit --branch main \
  --yml-path azure-pipelines.yml --skip-first-run --query id -o tsv)"
RUN1="$(azp pipelines run --id "$PIPE" --branch main --query id -o tsv)"
echo "  pipeline $PIPELINE créé, premier run lancé sur main"
attendre_run "$RUN1"
bilan_run "$RUN1"
if [ "$(azp pipelines runs show --id "$RUN1" --query result -o tsv)" != succeeded ]; then
  echo "  premier run en échec : parallel job hébergé absent, ou droit Feed Publisher manquant (voir Dépannage)." >&2
  echo "  $ORG/$PROJET_URL/_build/results?buildId=$RUN1" >&2
  exit 1
fi
echo "  artefacts : $(azp pipelines runs artifact list --run-id "$RUN1" --query "join(', ', [].name)" -o tsv)"
synth paquets

etape "Étape 5 : Repos, protéger main"
azp repos policy approver-count create --repository-id "$RID" --branch main --minimum-approver-count 1 \
  --creator-vote-counts true --allow-downvotes false --reset-on-source-push true --blocking true --enabled true -o none
azp repos policy work-item-linking create --repository-id "$RID" --branch main --blocking true --enabled true -o none
azp repos policy build create --repository-id "$RID" --branch main --build-definition-id "$PIPE" \
  --display-name "$PIPELINE" --queue-on-source-update-only false --manual-queue-only false --valid-duration 0 \
  --blocking true --enabled true -o none
echo "  main protégée : $(azp repos policy list --repository-id "$RID" --branch main --query "join(', ', [].type.displayName)" -o tsv)"
echo "" >> README.md
git commit -q -am "Essai de push direct sur main"
if REFUS="$(g push -q 2>&1)"; then
  echo "  le push direct sur main est passé : les stratégies ne sont pas actives." >&2; exit 1
fi
echo "  push direct refusé : $(printf '%s\n' "$REFUS" | grep -o 'TF402455[^.]*' | head -1)"
git reset -q --hard HEAD~1

etape "Étape 6 : US3 livrée par pull request"
azo boards work-item update --id "$US3" --state Active --assigned-to "$MOI" -o none
etat "$T1" Active
branche_depuis "$US3" "feature/$US3-ticket-perdu"
python3 - <<'PY'
fichier = "tests/tarifs.test.js"
texte = open(fichier, encoding="utf-8").read()
ancre = '''    assert.equal(prixEnCentimes(25 * 60), 2250);
  });
'''
assert ancre in texte, "test des 25 heures introuvable"
texte = texte.replace(ancre, ancre + '''
  test("un ticket perdu coûte le forfait de 30 €, quelle que soit la durée", () => {
    assert.equal(prixEnCentimes(10, true), 3000);
    assert.equal(prixEnCentimes(3 * 24 * 60, true), 3000);
  });
''', 1)
open(fichier, "w", encoding="utf-8").write(texte)
PY
if node --test --test-reporter=tap > /dev/null 2>&1; then echo "  le test du forfait passe sans le code : il ne teste rien." >&2; exit 1; fi
echo "  le test d'abord : il échoue sans le code"
etat "$T1" Closed
etat "$T2" Active
python3 - <<'PY'
def remplacer(fichier, ancre, nouveau):
    texte = open(fichier, encoding="utf-8").read()
    assert ancre in texte, f"{fichier} : « {ancre.strip()} » introuvable"
    open(fichier, "w", encoding="utf-8").write(texte.replace(ancre, nouveau, 1))

remplacer("js/tarifs.js", "const MINUTES_PAR_JOUR = 24 * 60;\n",
          "const MINUTES_PAR_JOUR = 24 * 60;\nconst FORFAIT_TICKET_PERDU_CENTIMES = 3000;\n")
remplacer("js/tarifs.js", "function prixEnCentimes(dureeMinutes) {\n",
          "function prixEnCentimes(dureeMinutes, ticketPerdu = false) {\n  if (ticketPerdu) {\n"
          "    return FORFAIT_TICKET_PERDU_CENTIMES;\n  }\n")
remplacer("js/app.js", "  evenement.preventDefault();\n",
          "  evenement.preventDefault();\n\n  if (document.getElementById(\"ticket-perdu\").checked) {\n"
          "    afficher(\"Prix : \" + enEuros(prixEnCentimes(0, true)), \"prix\");\n    return;\n  }\n")
remplacer("index.html", "        <li>20 € au maximum par période de 24 heures.</li>\n",
          "        <li>20 € au maximum par période de 24 heures.</li>\n        <li>Ticket perdu : forfait de 30 €.</li>\n")
remplacer("index.html", 'max="59" step="1" value="0"></label>\n',
          'max="59" step="1" value="0"></label>\n'
          '        <label class="case"><input id="ticket-perdu" type="checkbox"> Ticket perdu</label>\n')
PY
tests_locaux
git add .
git commit -q -m "Ticket perdu : forfait de 30 € #$US3"
g push -q -u origin "feature/$US3-ticket-perdu"
PR1="$(azp repos pr create -r "$DEPOT" -s "feature/$US3-ticket-perdu" -t main --title "Ticket perdu : forfait de 30 €" \
  --description "Case Ticket perdu : forfait de 30 €, quelle que soit la durée." --work-items "$US3" --query pullRequestId -o tsv)"
fusionner "$PR1"
echo "  PR $PR1 (US3 dans Work items), build de validation : $(attendre_build_pr "$PR1") (attendu : approved)"
VALID1="$(dernier_build_pr "$PR1")"
echo "  run de validation : Verifier $(stage_de "$VALID1" Verifier) ; Paquet $(stage_de "$VALID1" Paquet) (attendu : skipped)"
attendre_pr "$PR1"
FUSION1="$(azo repos pr show --id "$PR1" --query lastMergeCommit.commitId -o tsv)"
etat "$T2" Closed
etat "$US3" Resolved
echo "  PR $PR1 fusionnée (squash) ; tâches #$T1 #$T2 Closed ; US3 #$US3 Resolved"
git switch -q main
g pull -q --prune
git branch -q -D "feature/$US3-ticket-perdu"
RUN2="$(run_de_main "$FUSION1")"
attendre_run "$RUN2"
bilan_run "$RUN2"
VERSION_N="$(azp pipelines runs show --id "$RUN2" --query buildNumber -o tsv)"
synth paquets

etape "Étape 7 : Test Plans, recetter le Sprint 1 sur le site $VERSION_N"
synth plan
TELECHARGE="$(mktemp -d "${TMPDIR:-/tmp}/site.XXXXXX")"
synth executer "$(telecharger_site "$RUN2" "$TELECHARGE")"
rm -rf "$TELECHARGE"
BUG="$(synth bug)"
synth points

etape "Étape 8 : corriger, relivrer, promouvoir"
azo boards work-item update --id "$BUG" --state Active --assigned-to "$MOI" -o none
BRANCHE="bugfix/$BUG-tarif"
branche_depuis "$BUG" "$BRANCHE"
python3 - <<'PY'
fichier = "tests/tarifs.test.js"
texte = open(fichier, encoding="utf-8").read()
ancre = '  test("16 minutes coûtent une heure entamée, 2,50 €", () => {\n'
assert ancre in texte, "test des 16 minutes introuvable"
texte = texte.replace(ancre, '''  test("15 minutes exactement sont gratuites", () => {
    assert.equal(prixEnCentimes(15), 0);
  });

''' + ancre, 1)
open(fichier, "w", encoding="utf-8").write(texte)
PY
if node --test --test-reporter=tap > /dev/null 2>&1; then echo "  le test des 15 minutes passe sans correctif : il ne reproduit pas le bug." >&2; exit 1; fi
echo "  test « 15 minutes exactement sont gratuites » ajouté : il échoue"
git commit -q -am "Test du bug #$BUG"
g push -q -u origin "$BRANCHE"
PR2="$(azp repos pr create -r "$DEPOT" -s "$BRANCHE" -t main --title "15 minutes exactement sont gratuites (bug #$BUG)" \
  --description "Le test d'abord, puis le correctif : la première validation doit échouer." --work-items "$BUG" \
  --query pullRequestId -o tsv)"
echo "  PR $PR2 (bug dans Work items), build de validation : $(attendre_build_pr "$PR2") (attendu : rejected)"
synth tests "$(dernier_build_pr "$PR2")"
python3 - <<'PY'
fichier = "js/tarifs.js"
texte = open(fichier, encoding="utf-8").read()
ancre = "if (dureeMinutes < MINUTES_GRATUITES) {"
assert ancre in texte, "règle des minutes gratuites introuvable"
open(fichier, "w", encoding="utf-8").write(texte.replace(ancre, "if (dureeMinutes <= MINUTES_GRATUITES) {", 1))
PY
echo "  correctif : dureeMinutes <= MINUTES_GRATUITES"
tests_locaux
git commit -q -am "15 minutes ou moins : gratuit #$BUG"
g push -q
attendre_push_dans_pr "$PR2"
for _ in $(seq 1 20); do # le build rouge précédent doit laisser la place au nouveau run
  case "$(build_de_la_pr "$PR2")" in queued|running) break ;; esac
  sleep 3
done
fusionner "$PR2"
echo "  build de validation : $(attendre_build_pr "$PR2") (attendu : approved)"
synth tests "$(dernier_build_pr "$PR2")"
attendre_pr "$PR2"
FUSION2="$(azo repos pr show --id "$PR2" --query lastMergeCommit.commitId -o tsv)"
azo boards work-item update --id "$BUG" --state Resolved --reason Fixed -o none
echo "  PR $PR2 fusionnée ; bug #$BUG Resolved"
git switch -q main
g pull -q --prune
git branch -q -D "$BRANCHE"
RUN3="$(run_de_main "$FUSION2")"
attendre_run "$RUN3"
bilan_run "$RUN3"
VERSION_M="$(azp pipelines runs show --id "$RUN3" --query buildNumber -o tsv)"
TELECHARGE="$(mktemp -d "${TMPDIR:-/tmp}/site.XXXXXX")"
synth executer "$(telecharger_site "$RUN3" "$TELECHARGE")" 1
rm -rf "$TELECHARGE"
if [ "$(synth etat 'len(e["echecs_retest"])')" != 0 ]; then
  azo boards work-item update --id "$BUG" --state Active --discussion "Re-test en échec sur $VERSION_M." -o none
  echo "  re-test en échec : bug #$BUG repassé Active" >&2; exit 1
fi
azo boards work-item update --id "$BUG" --state Closed --fields "Microsoft.VSTS.Build.IntegrationBuild=$VERSION_M" -o none
for us in "$US1" "$US2" "$US3"; do etat "$us" Closed; done
echo "  bug #$BUG Closed (Integrated in Build $VERSION_M) ; US1, US2, US3 Closed"
synth points
synth promouvoir "$VERSION_M"
synth paquets

etape "État final"
for v in US1 US2 US3 T1 T2 BUG; do printf '  %-4s #%-6s %s\n' "$v" "${!v}" "$(etat_de "${!v}")"; done
echo "  PR $PR1 (US3) et PR $PR2 (bug) fusionnées"
echo "  runs de $PIPELINE :"
azp pipelines runs list --pipeline-ids "$PIPE" --query "sort_by(@, &id)[].[buildNumber, sourceBranch, result]" -o tsv | sed 's/^/    /'
echo "  projet : $ORG/$PROJET_URL"
echo "  copie de travail : $TRAVAIL (à garder ou supprimer)"
exit
}
