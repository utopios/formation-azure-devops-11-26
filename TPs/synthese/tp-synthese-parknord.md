# TP de synthèse — ParkNord : les cinq services d'Azure DevOps sur un nouveau projet

> Durée : une demi-journée, environ 3 h 30 pause comprise
> Travail : individuel, dans un nouveau projet `ParkNord-<Prénom>`
> Après : les TP des modules 1 à 4 ; le feed reprend le module 7
> Code de départ : le dossier `parknord-web`, fourni par le formateur

## Mise en situation

ParkNord exploite trois parkings à Lille et à Roubaix. Son site propose un simulateur de prix : le client saisit une durée de stationnement et voit ce qu'il paiera. Le code a été écrit sur un seul poste, sans suivi des demandes ni recette formelle. L'équipe des bornes de paiement veut réutiliser le même calcul de prix, plutôt que de le recoder.

Votre mission : installer ce projet dans Azure DevOps et mener un sprint complet, de la demande jusqu'au paquet validé. Vous allez réaliser les opérations suivantes :

- écrire les stories dans Boards ;
- pousser et protéger le code dans Repos ;
- construire le site et le paquet avec Pipelines ;
- publier le calcul comme paquet npm dans Artifacts ;
- faire la recette dans Test Plans, puis corriger ce qu'elle trouve.

## Le parcours

| Service | Ce que vous y faites |
|---|---|
| Boards | une feature, trois user stories avec leurs critères d'acceptation, le Sprint 1, des tâches |
| Repos | le dépôt, la branche `main` protégée, une branche par work item, des pull requests |
| Pipelines | un pipeline YAML : tests, site numéroté, publication du paquet ; la validation des pull requests |
| Artifacts | le feed du projet, le paquet `parknord-tarifs` versionné, la vue `@Release` |
| Test Plans | le plan du sprint, des cas de test tirés des critères, leur exécution, un bug |

```text
story (Boards) -> branche et pull request (Repos) -> run 1.0.N (Pipelines)
  -> site numéroté et paquet 1.0.N (Artifacts) -> recette (Test Plans)
  -> bug -> correction par pull request -> nouveau run -> vue @Release
```

## Prérequis

| Élément | Détail |
|---|---|
| Organisation | une organisation Azure DevOps dont vous êtes administrateur, celle des TP précédents |
| Parallel job | celui des TP précédents (agent hébergé par Microsoft) |
| Licence | **Basic + Test Plans** pour l'étape 7 : il faut ce niveau pour créer un plan et des suites, alors qu'exécuter des tests ne demande que Basic. Sans facturation, démarrez l'essai gratuit de 30 jours dans Organization settings > Billing ; le formateur vous indique la marche à suivre en salle |
| Poste | Git, VS Code ou un autre éditeur, Edge ou Chrome. Node.js 20 ou plus récent est facultatif : il permet de lancer les tests en local (`node --test`) |
| Code de départ | le dossier `parknord-web`, copié sur votre poste hors de tout dépôt Git |

## Déroulé

| Étape | Service | Contenu | Durée |
|---|---|---|---|
| 0 | | Créer le projet | 5 min |
| 1 | Boards | Le backlog du Sprint 1 | 25 min |
| 2 | Repos | Pousser le code de départ | 15 min |
| 3 | Artifacts | Le feed du projet | 15 min |
| 4 | Pipelines | Le pipeline d'intégration continue | 30 min |
| | | Pause | 15 min |
| 5 | Repos | Protéger `main` | 10 min |
| 6 | Boards, Repos, Pipelines | Une story livrée par pull request | 30 min |
| 7 | Test Plans | Recetter le Sprint 1 | 35 min |
| 8 | les cinq | Corriger, relivrer, promouvoir | 25 min |

Dans tout le TP, remplacez `<organisation>` par le nom de votre organisation, `<Prénom>` par votre prénom, et `<US1>`, `<US3>`, `<bug>` par les identifiants des work items que vous allez créer.

---

## Étape 0 — Créer le projet (5 min)

1. `https://dev.azure.com/<organisation>` > **New project** : nom `ParkNord-<Prénom>`, visibilité **Private**.
2. Sous **Advanced**, choisissez **Git** pour *Version control* et **Agile** pour *Work item process*, puis cliquez sur **Create**.

**Point de contrôle 0** :

- Project settings > Overview affiche le processus Agile et la visibilité Private ;
- le menu de gauche montre Boards, Repos, Pipelines, Test Plans et Artifacts ;
- Repos contient un dépôt vide, `ParkNord-<Prénom>`.

## Étape 1 — Boards : le backlog du Sprint 1 (25 min)

1. **Le sprint.**
   - Project settings > Boards > Project configuration > **Iterations**. Si `Sprint 1` n'existe pas, créez-le sous la racine avec **New child**.
   - Donnez-lui des dates avec **Set dates** : du jour du TP à 13 jours plus tard.
   - Project settings > **Team configuration**, équipe `ParkNord-<Prénom> Team`, onglet **Iterations** : `Sprint 1` doit figurer dans la liste. Sinon, ajoutez-le avec **+ Select iteration(s)**.
2. **La feature.** Boards > **Backlogs**. Dans le sélecteur de niveau, en haut à droite, choisissez **Features**. Puis **New Work Item** : `Simulateur de prix` > **Add to top**.
3. **Les stories.**
   - Sur la ligne de la feature, cliquez sur **+** > *User Story* et créez les trois stories ci-dessous.
   - Ouvrez chacune et remplissez *Description*, *Acceptance Criteria* et *Story Points*. Réglez *Iteration* sur `Sprint 1`.

| Story | Description | Critères d'acceptation | Points |
|---|---|---|---|
| US1 — Calculer le prix d'un stationnement | En tant que client, je veux connaître le prix d'une durée de stationnement avant de me garer. | 1. Un stationnement de 15 minutes ou moins est gratuit.<br>2. Au-delà, chaque heure entamée coûte 2,50 € : 16 minutes coûtent 2,50 €, 1 h 01 coûte 5,00 €.<br>3. Une durée invalide est refusée avec un message, sans prix : minutes au-delà de 59, valeur négative ou non entière. | 3 |
| US2 — Plafonner le prix à 20 € par 24 heures | En tant que client qui stationne longtemps, je veux un prix plafonné à la journée. | 1. Sur une période de 24 heures, le prix ne dépasse jamais 20 €.<br>2. Au-delà de 24 heures, chaque période complète de 24 heures coûte 20 €, et le reste se paie à l'heure entamée : 25 heures coûtent 22,50 €. | 2 |
| US3 — Payer un ticket perdu | En tant que client qui a perdu son ticket, je veux savoir ce que je dois payer. | 1. Une case « Ticket perdu » est proposée à côté de la durée.<br>2. Case cochée, le prix est un forfait de 30 €, quelle que soit la durée saisie. | 2 |

4. **Les tâches de US3.**
   - Boards > **Sprints** > `Sprint 1` > onglet **Taskboard**.
   - Sur la carte de US3, cliquez sur **+** > *Task* et créez `Écrire le test du forfait` (*Remaining Work* 1) puis `Coder le forfait` (*Remaining Work* 2).
   - Assignez les deux tâches à vous.
5. **US1 et US2 sont déjà codées** dans le code de départ. Passez-les à l'état **Resolved**, mais pas Closed : elles le seront une fois recettées.

**Point de contrôle 1** :

- Backlogs, niveau Features : `Simulateur de prix` ; dépliée, elle montre ses trois stories ;
- Sprints > `Sprint 1` > Backlog : les trois stories, avec leurs points ;
- Taskboard : US3 et ses deux tâches, dans la colonne *New* ;
- US1 et US2 sont *Resolved*, US3 est *New*.

## Étape 2 — Repos : pousser le code de départ (15 min)

1. Repos > Files : le dépôt est vide, et la page propose *Push an existing repository from command line*.
   - Copiez l'URL HTTPS.
   - Si Git vous demande un mot de passe, utilisez **Generate Git Credentials**, sur cette même page.
2. Dans un terminal, depuis le dossier `parknord-web`, lancez les commandes suivantes. Remplacez `<US1>` et `<US2>` par les identifiants de vos stories : un `#1234` dans un message de commit relie le commit au work item.

   ```bash
   git init -b main
   git add .
   git commit -m "Code de départ du simulateur de prix #<US1> #<US2>"
   git remote add origin <URL copiée>
   git push -u origin main
   ```

3. Facultatif : lancez `node --test`, puis ouvrez `index.html` dans le navigateur et calculez le prix de 1 h 30.

**Point de contrôle 2** :

- Repos > Files montre `index.html`, `css/`, `js/`, `tests/` et `package.json`. Le `README.md` est affiché sous la liste ;
- la zone **Development** de US1 affiche le commit ;
- en local, si vous avez lancé les tests : 10 tests réussis, et la page affiche « Prix : 5,00 € » pour 1 h 30.

## Étape 3 — Artifacts : le feed du projet (15 min)

L'équipe des bornes de paiement installera le calcul avec `npm install parknord-tarifs`. Le pipeline publiera ce paquet dans un feed du projet, à l'étape 4.

1. **Le feed.** Artifacts > **+ Create Feed** :
   - nom `parknord` ;
   - *Upstream sources* : cochez **Include packages from common public sources** ;
   - *Scope* : **Project: ParkNord-<Prénom>** ;
   - puis **Create**.
2. **Le droit de publier.**
   - Ouvrez **Feed settings** (icône d'engrenage), onglet **Permissions**.
   - L'identité du pipeline, `ParkNord-<Prénom> Build Service (<organisation>)`, a par défaut le rôle **Feed and Upstream Reader (Collaborator)** : elle peut lire le feed, mais pas y publier.
   - **Add users/groups** : choisissez cette identité, rôle **Feed Publisher (Contributor)** > **Save**.
3. **Le fichier `.npmrc`.**
   - Revenez au feed > **Connect to feed** > **npm**. Dans *Project setup*, copiez la ligne `registry=...`.
   - À la racine de votre clone, créez un fichier `.npmrc` qui contient cette ligne :

   ```ini
   registry=https://pkgs.dev.azure.com/<organisation>/ParkNord-<Prénom>/_packaging/parknord/npm/registry/
   ```

   - Si la page affiche aussi `always-auth=true`, vous pouvez garder cette ligne.
   - Le fichier ne contient ni jeton ni mot de passe : le pipeline ajoutera le sien au moment du run.
4. Poussez le fichier :

   ```bash
   git add .npmrc
   git commit -m "Feed npm du projet"
   git push
   ```

**Point de contrôle 3** :

- le feed `parknord` existe et il est vide ;
- dans ses Permissions, `ParkNord-<Prénom> Build Service (<organisation>)` a le rôle Feed Publisher (Contributor) ;
- dans Repos, `.npmrc` ne contient que l'adresse du feed ;
- question : pourquoi aucun mot de passe ne doit-il figurer dans ce fichier ?

## Étape 4 — Pipelines : le pipeline d'intégration continue (30 min)

1. À la racine du clone, créez `azure-pipelines.yml` :

   ```yaml
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
   ```

   Les lignes à comprendre :

   | Ligne | Rôle |
   |---|---|
   | `name: 1.0.$(Rev:r)` | le nom du run, qui sert aussi de version : `1.0.1`, `1.0.2`, etc. Le compteur augmente à chaque run du pipeline |
   | `--test-reporter=junit` et `PublishTestResults@2` | les résultats apparaissent dans l'onglet Tests du run, même si un test échoue |
   | `sed ... __VERSION__` | le site produit affiche le numéro du run : la recette sait quelle version elle teste |
   | `condition: ... 'refs/heads/main'` | le paquet n'est publié que depuis `main`, jamais depuis une pull request |
   | `npmAuthenticate@0` | ajoute au `.npmrc`, le temps du job, un jeton qui donne au pipeline l'accès au feed |
   | `npm version` puis `npm publish` | la version du paquet est le nom du run. Une version publiée ne peut plus être remplacée |

2. Poussez le fichier :

   ```bash
   git add azure-pipelines.yml
   git commit -m "Pipeline d'intégration continue"
   git push
   ```

3. Créez le pipeline :
   - Pipelines > **New pipeline** > **Azure Repos Git** > `ParkNord-<Prénom>` > **Existing Azure Pipelines YAML file** ;
   - branche `main`, chemin `/azure-pipelines.yml` > **Continue** > **Run** ;
   - renommez ensuite le pipeline `parknord-ci` (menu ⋮ > *Rename/move*).
4. Une fois le run terminé :
   - lisez son onglet **Tests** ;
   - dans le résumé, ouvrez **1 published** et téléchargez l'artefact `site` (menu ⋮ > *Download artifacts*) ;
   - décompressez-le et ouvrez son `index.html` ;
   - ouvrez Artifacts > `parknord`.

**Point de contrôle 4** :

- le run s'appelle `1.0.1`, et ses trois stages sont enchaînés : *Vérifier le code*, *Produire le site*, *Publier le paquet* ;
- l'onglet Tests affiche 10 tests réussis ;
- le pied de la page téléchargée affiche « Version 1.0.1 » ;
- le feed `parknord` contient `parknord-tarifs` en version `1.0.1` ;
- questions :
  - pourquoi le stage *Publier le paquet* ne s'exécutera-t-il pas pour une pull request ?
  - pourquoi le paquet ne contient-il ni `index.html` ni les tests ? Regardez `package.json`.

## Étape 5 — Repos : protéger `main` (10 min)

1. Repos > **Branches** > menu ⋮ de `main` > **Branch policies** :

| Stratégie | Réglage |
|---|---|
| Require a minimum number of reviewers | On, 1. Cochez *Allow requestors to approve their own changes*, puisque vous travaillez seul. *When new changes are pushed* : *Reset all approval votes* |
| Check for linked work items | On, *Required* |
| Build validation > **+** | *Build pipeline* `parknord-ci`, *Trigger* Automatic, *Policy requirement* Required, *Build expiration* Immediately when main is updated, *Display name* `parknord-ci` > **Save** |

2. Vérifiez la protection :
   - modifiez une ligne de `README.md`, commitez, puis lancez `git push` ;
   - lisez le message ;
   - annulez ensuite ce commit avec `git reset --hard HEAD~1`.

**Point de contrôle 5** :

- le push est refusé avec l'erreur `TF402455` (*Pushes to this branch are not permitted; you must use a pull request to update this branch*) ;
- dans Repos > Branches, `main` porte l'icône des stratégies.

## Étape 6 — Une story livrée par pull request (30 min)

1. **Démarrer le travail sur US3.**
   - Ouvrez US3 : passez-la à l'état **Active** et assignez-la à vous.
   - Zone **Development** > **Create branch** : `feature/<US3>-ticket-perdu`, *Based on* `main` > **Create branch**.
   - Passez la tâche « Écrire le test du forfait » à **Active**.
2. En local, récupérez la branche :

   ```bash
   git fetch
   git switch feature/<US3>-ticket-perdu
   ```

3. **Le test d'abord.**
   - Dans `tests/tarifs.test.js`, groupe « Prix d'un stationnement », ajoutez ce test après le dernier :

   ```js
     test("un ticket perdu coûte le forfait de 30 €, quelle que soit la durée", () => {
       assert.equal(prixEnCentimes(10, true), 3000);
       assert.equal(prixEnCentimes(3 * 24 * 60, true), 3000);
     });
   ```

   - Lancez `node --test` : le nouveau test échoue (attendu 3000, obtenu 0). Sans Node.js sur votre poste, passez ce contrôle : le pipeline le fera.
   - Passez la tâche du test à **Closed** et celle du code à **Active**.
4. **Le code.** Quatre modifications :

   - `js/tarifs.js`, sous `const MINUTES_PAR_JOUR = 24 * 60;`, ajoutez :

     ```js
     const FORFAIT_TICKET_PERDU_CENTIMES = 3000;
     ```

   - `js/tarifs.js` : remplacez la ligne `function prixEnCentimes(dureeMinutes) {` par ces quatre lignes. Le reste de la fonction ne change pas :

     ```js
     function prixEnCentimes(dureeMinutes, ticketPerdu = false) {
       if (ticketPerdu) {
         return FORFAIT_TICKET_PERDU_CENTIMES;
       }
     ```

   - `js/app.js`, juste après `evenement.preventDefault();`, ajoutez :

     ```js
       if (document.getElementById("ticket-perdu").checked) {
         afficher("Prix : " + enEuros(prixEnCentimes(0, true)), "prix");
         return;
       }
     ```

   - `index.html` :
     - dans la liste des tarifs, ajoutez la ligne `<li>Ticket perdu : forfait de 30 €.</li>` ;
     - dans le `fieldset`, ajoutez sous le champ *Minutes* la case à cocher :

     ```html
             <label class="case"><input id="ticket-perdu" type="checkbox"> Ticket perdu</label>
     ```

5. Vérifiez en local :
   - `node --test` : 11 tests réussis ;
   - ouvrez `index.html`, cochez *Ticket perdu*, puis **Calculer** : « Prix : 30,00 € ».
6. Poussez la branche :

   ```bash
   git add .
   git commit -m "Ticket perdu : forfait de 30 € #<US3>"
   git push -u origin feature/<US3>-ticket-perdu
   ```

7. **La pull request.**
   - Repos > **Pull requests** > **New pull request**, ou le bandeau *Create a pull request* : de `feature/<US3>-ticket-perdu` vers `main`.
   - Titre `Ticket perdu : forfait de 30 €`. Vérifiez que US3 figure dans la section *Work items*, puis **Create**.
8. Le build de validation `parknord-ci` démarre seul. Quand il est vert :
   - **Approve** ;
   - puis **Complete** : *Merge type* **Squash commit** ;
   - **décochez** *Complete associated work items after merging*, et cochez *Delete feature/<US3>-ticket-perdu after merging* ;
   - enfin **Complete merge**.
9. Dans Boards :
   - passez la tâche « Coder le forfait » à **Closed** ;
   - passez US3 à **Resolved**. Elle n'est pas encore recettée.

**Point de contrôle 6** :

- avant la fusion, les trois stratégies de la PR sont vertes ;
- le run de validation montre *Vérifier le code* et *Produire le site* réussis, et *Publier le paquet* ignoré (*skipped*) ;
- la fusion a lancé un run sur `main`, `1.0.N`, avec trois stages verts et 11 tests ;
- Artifacts > `parknord-tarifs` > **Versions** : `1.0.1` et `1.0.N` ;
- question : pourquoi les versions du feed ne se suivent-elles pas ?

## Étape 7 — Test Plans : recetter le Sprint 1 (35 min)

Vous êtes maintenant la recette. Vous testez **ce que le pipeline a produit**, pas votre clone.

1. **Le plan.** Test Plans > Test plans > **New Test Plan** :
   - nom `ParkNord - Sprint 1` ;
   - Area Path `ParkNord-<Prénom>` ;
   - Iteration `ParkNord-<Prénom>\Sprint 1` ;
   - puis **Create**.
2. **Les suites.** Menu ⋮ de la suite racine > **New Suite** > **Requirement based suite** > **Run query** > cochez US1, US2 et US3 > **Create suites**.
3. **Le premier cas, avec une étape partagée.** Dans la suite de US1, onglet **Define** > **New Test Case**, titre `Les 15 premières minutes sont gratuites` :

| Étape | Action | Résultat attendu |
|---|---|---|
| 1 | Ouvrir le `index.html` du site à recetter : l'artefact `site` du dernier run de `main` | la page « Simulateur de prix » s'affiche, et le pied de page indique la version du run |
| 2 | Saisir `@heures` heures et `@minutes` minutes, puis cliquer sur **Calculer** | la page affiche `@resultat` |

Dans la grille **Parameter values**, sous les étapes :

| heures | minutes | resultat |
|---|---|---|
| 0 | 5 | Prix : 0,00 € |
| 0 | 10 | Prix : 0,00 € |
| 0 | 15 | Prix : 0,00 € |

   Transformez ensuite l'étape 1 en étape partagée : sélectionnez-la > icône **Create shared steps** > nom `Ouvrir le simulateur à recetter`. Puis **Save & Close**.

4. **Les autres cas.**
   - Chaque cas suit le même modèle : l'étape partagée, insérée avec l'icône **Insert shared steps**, puis l'étape 2 et sa grille de paramètres.
   - Dans la colonne des paramètres, chaque ligne donne les heures et les minutes, puis le résultat attendu.

| Suite | Titre du cas | Paramètres : heures, minutes → `resultat` |
|---|---|---|
| US1 | Chaque heure entamée coûte 2,50 € | 0, 16 → Prix : 2,50 €<br>1, 0 → Prix : 2,50 €<br>1, 1 → Prix : 5,00 €<br>3, 30 → Prix : 10,00 € |
| US1 | Une durée invalide est refusée | 1, 75 → Durée invalide (message en rouge, sans prix)<br>-1, 0 → Durée invalide (message en rouge, sans prix) |
| US2 | Le prix est plafonné à 20 € par période de 24 heures | 8, 0 → Prix : 20,00 €<br>12, 0 → Prix : 20,00 €<br>24, 0 → Prix : 20,00 €<br>25, 0 → Prix : 22,50 € |
| US3 | Un ticket perdu coûte le forfait de 30 € | pas de paramètres. Étape 2 : cocher *Ticket perdu*, saisir 2 heures et 0 minute, puis **Calculer**. Résultat attendu : « Prix : 30,00 € » |

5. **Récupérer le site à recetter.**
   - Pipelines > `parknord-ci` > le dernier run de `main` (`1.0.N`) > **1 published** > artefact `site` > menu ⋮ > *Download artifacts*.
   - Décompressez le fichier : c'est **ce** `index.html` que vous ouvrez dans Edge ou Chrome.
6. **Exécuter.**
   - Pour chaque suite : onglet **Execute** > sélectionnez tous les points de test > **Run for web application**.
   - Le runner s'ouvre dans une fenêtre séparée : autorisez les fenêtres pop-up.
   - Suivez chaque étape dans la page, puis marquez-la réussie ou échouée. Un cas paramétré se rejoue une fois par ligne de la grille.
   - Sur une étape échouée, notez en commentaire ce que la page a affiché.
7. **Un bug par écart.** Depuis l'étape échouée, dans le runner : **Create bug**.
   - *Title* : le fait observé, sans hypothèse sur la cause ;
   - *Repro Steps* : elles sont pré-remplies. Complétez-les avec la saisie, le résultat obtenu, le résultat attendu et le critère d'acceptation concerné ;
   - *Found in Build* : la version du pied de page, `1.0.N` ;
   - *Severity* : votre évaluation de l'impact pour les clients.

   Puis **Save & Close**, et **Save and close** dans le runner.

**Point de contrôle 7** :

- le plan contient trois suites et cinq cas de test ; l'étape partagée apparaît dans les cinq ;
- dans l'onglet Execute de chaque suite, chaque point de test a un résultat ; la page du plan affiche le pourcentage de points exécutés ;
- chaque point *Failed* a son bug, à l'état *New*, lié au cas de test (onglet **Links** du bug) ;
- un collègue pourrait reproduire votre bug avec vos seules Repro Steps.

## Étape 8 — Corriger, relivrer, promouvoir (25 min)

1. **Démarrer la correction.**
   - Ouvrez le bug : état **Active**, assigné à vous.
   - Zone **Development** > **Create branch** : `bugfix/<bug>-tarif`, *Based on* `main`.
   - En local : `git fetch`, puis `git switch bugfix/<bug>-tarif`.
2. **Le test d'abord.**
   - Dans `tests/tarifs.test.js`, groupe « Prix d'un stationnement », ajoutez un test qui reproduit le cas en échec. Nommez-le d'après le comportement attendu :

   ```js
     test("<le comportement attendu, en une phrase>", () => {
       assert.equal(prixEnCentimes(<durée en minutes>), <prix attendu en centimes>);
     });
   ```

   - Commitez et poussez **ce test seul** :

   ```bash
   git commit -am "Test du bug #<bug>"
   git push -u origin bugfix/<bug>-tarif
   ```

   - Ouvrez la pull request vers `main`, avec le bug dans la section *Work items*.

3. **Le build de validation échoue** : l'onglet Tests du run montre votre test en échec, et la PR ne peut pas être complétée.
4. **Le correctif.**
   - Dans `js/tarifs.js`, relisez la règle des minutes gratuites de `prixEnCentimes` et comparez-la au critère 1 de US1.
   - Corrigez, puis lancez `node --test` : 12 tests réussis.
   - Commitez avec `#<bug>` dans le message, puis poussez : la validation se relance.
5. **Fusionner.** Quand la validation est verte :
   - **Approve**, puis **Complete** : Squash commit ;
   - décochez *Complete associated work items after merging*, et supprimez la branche ;
   - passez le bug à **Resolved**.
6. La fusion lance le run `1.0.M` sur `main`. Téléchargez son artefact `site`.
7. **Re-tester.**
   - Test Plans > la suite de US1 > **Execute** > le point *Failed* > **Run for web application**, sur le nouveau site. Rejouez le cas.
   - S'il passe, fermez le bug (**Closed**), puis passez US1, US2 et US3 à **Closed**.
8. **Promouvoir le paquet recetté.** Artifacts > `parknord` > `parknord-tarifs` (la page affiche la dernière version, `1.0.M`) > **Promote** > vue `@Release` > **Promote**.

**Point de contrôle 8** :

- la PR du bug montre deux runs de validation : le premier en échec sur votre test, le second réussi ;
- le point re-testé est *Passed*. Son historique, dans le volet de détail du point, montre *Failed* puis *Passed* ;
- le bug est *Closed*, et ses liens mènent au cas de test, à la branche et à la pull request ;
- Artifacts : trois versions de `parknord-tarifs`. Avec la vue `@Release` sélectionnée en haut du feed, seule `1.0.M` reste ;
- Boards > Sprints > `Sprint 1` : stories et tâches *Closed* ;
- questions :
  - pourquoi les 10 tests unitaires du départ n'ont-ils rien vu ?
  - pourquoi publier une nouvelle version, plutôt que remplacer `1.0.N` par une version corrigée ?
  - quelle version l'équipe des bornes de paiement doit-elle installer, et comment la reconnaît-elle ?

## Pour aller plus loin (si vous avez fini)

**A. Consommer le paquet depuis le feed.**

- Dans `azure-pipelines.yml`, job `Npm`, ajoutez cette étape après la publication. `main` est protégée : passez par une branche et une pull request liée à une tâche.

```yaml
          - bash: |
              set -euo pipefail
              client="$(Agent.TempDirectory)/client"
              mkdir -p "$client"
              cp .npmrc "$client/"
              cd "$client"
              npm init -y > /dev/null
              npm install "parknord-tarifs@$(Build.BuildNumber)"
              node -e "const t = require('parknord-tarifs'); console.log('90 minutes :', t.enEuros(t.prixEnCentimes(90)))"
            displayName: Installer le paquet depuis le feed
```

- Après la fusion, le journal du run sur `main` affiche « 90 minutes : 5,00 € ». Le paquet vient du feed, pas du dépôt.
- Question : pourquoi copier le `.npmrc` du dépôt dans le dossier du client ?

**B. Un tableau de bord du sprint.** Overview > **Dashboards** > **New Dashboard** `ParkNord - Sprint 1`. Ajoutez trois widgets :

- *Sprint Burndown* ;
- *Build History*, sur `parknord-ci` ;
- *Test Results Trend*, sur `parknord-ci`.

Pour chaque widget, dites à qui il sert, entre le Product Owner, les développeurs et la recette.

## Livrable

Le projet `ParkNord-<Prénom>`, à la fin de l'étape 8 :

- Boards : la feature et ses trois stories, à l'état *Closed* ;
- Repos : deux pull requests fusionnées, chacune liée à son work item ;
- Pipelines : `parknord-ci` avec au moins quatre runs, dont un run de validation en échec ;
- Artifacts : le feed `parknord`, trois versions de `parknord-tarifs`, la dernière dans `@Release` ;
- Test Plans : le plan `ParkNord - Sprint 1`, cinq cas de test tous *Passed*, un bug *Closed*.

## Dépannage

| Symptôme | Cause et remède |
|---|---|
| *No hosted parallelism has been purchased or granted* | l'organisation n'a pas de parallel job hébergé : faites la demande gratuite, ou utilisez un agent auto-hébergé (module 8) |
| Test Plans ou Artifacts absent du menu | le service est désactivé dans le projet : activez-le dans Project settings > Overview > *Azure DevOps services* |
| *Publier le paquet* : `403 Forbidden` ou `E403` | l'identité Build Service n'est pas Feed Publisher (étape 3, point 2). Si l'erreur persiste, donnez le même rôle à `Project Collection Build Service (<organisation>)` |
| `ENEEDAUTH` ou `E401` | `npmAuthenticate@0` est absente ou placée après `npm publish`, ou `workingFile` ne désigne pas le `.npmrc` de la racine |
| `E404` sur le feed | la ligne `registry=` ne correspond pas au feed : recopiez-la depuis *Connect to feed*. Elle se termine par `/npm/registry/` |
| relance (*Rerun*) du stage *Publier le paquet* refusée : la version existe déjà | une relance garde le même nom de run, donc la même version, et une version publiée ne peut pas être remplacée. Lancez plutôt un nouveau run avec **Run pipeline** |
| `git push` refusé avec `TF402455` | c'est normal après l'étape 5 : passez par une branche et une pull request |
| PR : *Check for linked work items* en échec | ajoutez la story ou le bug dans la section *Work items* de la PR |
| **New Test Plan** grisé, ou message sur la licence | votre niveau d'accès n'est pas Basic + Test Plans (voir les prérequis) |
| le pied de page affiche `Version __VERSION__` | vous avez ouvert le `index.html` de votre clone, pas celui de l'artefact `site` |
| le runner ne s'ouvre pas | le navigateur bloque la fenêtre pop-up : autorisez-la pour `dev.azure.com` |

## Nettoyage

Project settings > Overview > **Delete** : le projet disparaît avec son dépôt, ses pipelines, son feed et ses plans de test.
