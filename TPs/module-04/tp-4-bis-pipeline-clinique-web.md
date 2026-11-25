# TP 4 bis — Clinique : le pipeline de build et de test de clinique-web

> Module : 4 — Les builds
> Durée : environ 1 h 15
> Travail : individuel, dans votre projet `Clinique-<Prénom>`
> Après : TP 2 bis (dépôt `clinique-web`, `main` protégée, pipeline `clinique-ci`) et la démo 4.1, partie 2 (portée, trois syntaxes, sorties, paramètres, conditions)

## Mise en situation

Le pipeline `clinique-ci` du TP 2 bis lance les tests, et c'est tout. Pour la recette, John récupère la page sur le poste de celui qui l'a modifiée en dernier : il ne sait jamais quelle version il teste. Et le mot de passe du serveur de recette circule par messagerie.

Votre mission : écrire **vous-même** le pipeline `clinique-build`. Il vérifie le code, produit un paquet numéroté, puis le dépose en recette, mais seulement quand c'est `main` qui a changé. Le mot de passe de recette n'apparaît nulle part dans le dépôt.

Vous ne modifiez pas `azure-pipelines.yml` : `clinique-ci` continue de valider les pull requests.

## Ce que vous allez construire

| Stage | Jobs | Rôle |
|---|---|---|
| `Verifier` | `Syntaxe` et `Tests`, en parallèle | le code est-il correct ? |
| `Paqueter` | `Zip` | un paquet numéroté, publié comme artefact |
| `Recette` | `Deposer` | dépôt du paquet sur le serveur de recette (simulé), avec le mot de passe secret |

## Prérequis

| Élément | Détail |
|---|---|
| Projet | `Clinique-<Prénom>`, avec le dépôt `clinique-web` du TP 2 bis. Sans TP 2 bis : créez le projet et le dépôt `clinique-web`, puis poussez dans `main` le contenu de `tp/module-02/clinique-web/` |
| Parallel job | celui des TP 2 et 4. Avec un seul parallel job, les jobs « en parallèle » passent l'un après l'autre : c'est normal |
| Poste | Git et VS Code, ou l'éditeur web. Node.js est facultatif (pour lancer `node --test` en local) |
| Références | slides 10 à 42 du module 4 ; fichiers `02`, `03`, `04`, `05`, `06` et `08` de `demos/pipelines-yaml/` |

## Déroulé

| Étape | Contenu | Durée |
|---|---|---|
| 0 | Une tâche, une branche, un fichier | 5 min |
| 1 | Un premier stage qui teste | 10 min |
| 2 | Deux jobs en parallèle | 8 min |
| 3 | Numéroter et paqueter | 12 min |
| 4 | Un secret et une dépendance entre stages | 15 min |
| 5 | Des conditions | 12 min |
| 6 | Déclencheurs, puis fusion dans `main` | 10 min |

---

## Étape 0 — Une tâche, une branche, un fichier (5 min)

1. Boards > Sprints > `Sprint 1` : sous la User Story #1, ajoutez la tâche **T6 « Écrire le pipeline de build et de test »**, assignée à vous, en **Active**
2. Depuis T6 : **Create branch** > `feature/<T6>-pipeline-build`, basée sur `main`
3. Récupérez la branche dans votre clone (`git fetch`, puis `git switch feature/<T6>-pipeline-build`) et créez un fichier vide `pipelines/clinique-build.yml`

Chaque commit de ce TP cite la tâche : « Pipeline de build : stage Verifier #<T6> ».

## Étape 1 — Un premier stage qui teste (10 min)

Écrivez dans `pipelines/clinique-build.yml` un pipeline qui :

- ne se déclenche **pas** automatiquement (pour l'instant) ;
- tourne sur un agent hébergé Ubuntu 24.04, image **épinglée** ;
- déclare à la **racine** une variable `versionNode` = `22.x` ;
- contient un stage `Verifier` (libellé « Vérifier le code »), avec un job `Tests` qui :
  - installe Node.js `$(versionNode)` (tâche `UseNode@1`, entrée `version`) ;
  - lance les tests avec deux rapporteurs, comme `azure-pipelines.yml` : `spec` vers la sortie standard, `junit` vers `resultats-tests.xml` ;
  - publie les résultats (tâche `PublishTestResults@2`, format JUnit) **même si des tests ont échoué**, avec un titre qui contient le numéro du run.

Poussez, puis créez le pipeline : Pipelines > New pipeline > Azure Repos Git > `clinique-web` > *Existing Azure Pipelines YAML file* > votre branche, `/pipelines/clinique-build.yml` > Continue > Run. Renommez-le `clinique-build` (menu ⋮ > Rename/move).

**Point de contrôle 1** :

- un run vert, avec le stage « Vérifier le code » et le job `Tests` ;
- l'onglet **Tests** affiche 5 tests réussis (3 si vous êtes parti du code de départ) ;
- le journal de `UseNode@1` indique une version `22.x`.

## Étape 2 — Deux jobs en parallèle (8 min)

1. Dans le stage `Verifier`, ajoutez un second job, `Syntaxe`. Il installe la même version de Node.js, puis vérifie la syntaxe de chaque fichier de `js/` avec `node --check`. Le script commence par `set -euo pipefail`
2. Les deux jobs n'ont pas de `dependsOn` entre eux : ils sont indépendants

Lancez un run.

Puis faites l'essai suivant : supprimez une accolade fermante dans `js/app.js`, poussez, lancez. Remettez l'accolade, poussez.

**Point de contrôle 2** :

- le stage `Verifier` montre deux jobs, sans flèche entre eux ;
- avec l'accolade manquante, `Syntaxe` échoue et cite `js/app.js`, tandis que `Tests` reste vert. Vous savez dire pourquoi les tests n'ont rien vu ;
- le stage `Verifier` est rouge dès qu'un de ses jobs l'est.

## Étape 3 — Numéroter et paqueter (12 min)

1. Déclarez à la racine `versionMajeure` = 1 et `versionMineure` = 0, et faites en sorte que le **nom du run** soit `majeure.mineure.compteur`
2. Ajoutez un stage `Paqueter` (libellé « Produire le paquet »), qui **dépend explicitement** de `Verifier`. Il déclare au niveau du **stage** une variable `dossierSite` = `$(Agent.TempDirectory)/site`
3. Son job `Zip` :
   - copie `index.html`, `css/` et `js/` dans `$(dossierSite)`, et **pas** `tests/` ni `pipelines/` ;
   - écrit dans ce dossier un fichier `version.json` qui contient le nom du run et le commit (`Build.BuildNumber`, `Build.SourceVersion`) ;
   - zippe le dossier (tâche `ArchiveFiles@2`, sans le dossier racine) en `$(Build.ArtifactStagingDirectory)/clinique-web-<nom du run>.zip` ;
   - publie `$(Build.ArtifactStagingDirectory)` comme artefact `clinique-web` (`PublishPipelineArtifact@1`).

Lancez deux runs.

**Point de contrôle 3** :

- les runs s'appellent `1.0.1`, puis `1.0.2` ;
- la vue du run montre `Verifier` puis `Paqueter`, reliés par une flèche ;
- l'artefact `clinique-web` contient `clinique-web-1.0.2.zip`. Une fois téléchargé, le zip contient `index.html`, `css/`, `js/` et `version.json`, et ce dernier porte `1.0.2` et le commit du run ;
- question : pourquoi `dossierSite` est-elle déclarée dans le stage, et non à la racine ?

## Étape 4 — Un secret et une dépendance entre stages (15 min)

1. **Le secret.** Pipelines > `clinique-build` > Edit > **Variables** > *New variable* : `motDePasseRecette`, une valeur de votre choix, **Keep this value secret** > OK > Save.
2. **Une variable de sortie.** Dans le job `Zip`, l'étape qui écrit `version.json` publie aussi le nom du zip comme **variable de sortie** `nomZip`. Utilisez `##vso[task.setvariable ...;isOutput=true]` et donnez un `name:` à l'étape, par exemple `paquet`.
3. **Le stage `Recette`** (libellé « Déposer en recette »). Il dépend de `Paqueter`. Son job `Deposer` :
   - déclare une variable de **job** `nomZip`, lue dans le stage `Paqueter` avec une expression d'exécution `$[ stageDependencies... ]` (démo, fichier `04`) ;
   - télécharge l'artefact `clinique-web` du run en cours (raccourci `download: current`) ;
   - simule le dépôt, dans un script `bash` qui :
     - commence par `set -euo pipefail` ;
     - vérifie que `$(Pipeline.Workspace)/clinique-web/$(nomZip)` existe ;
     - vérifie que le mot de passe a bien été reçu, puis affiche sa longueur ;
     - affiche « Dépôt de <nomZip> sur recette.clinique.local ».

     Le mot de passe arrive par la clé `env:` de l'étape, dans une variable d'environnement `MOT_DE_PASSE_RECETTE`.

Lancez un run.

**Point de contrôle 4** :

- trois stages enchaînés : `Verifier`, `Paqueter`, `Recette` ;
- le journal de `Deposer` affiche le nom exact du zip, la longueur du mot de passe, et `***` si vous l'affichez « par erreur » ;
- `git grep motDePasseRecette` ne trouve que le **nom** de la variable dans le dépôt, jamais sa valeur ;
- question : que contiendrait `$(nomZip)` si vous aviez écrit `$(paquet.nomZip)` dans le job `Deposer` ?

## Étape 5 — Des conditions (12 min)

1. **Déposer seulement depuis `main`.** Le stage `Recette` ne s'exécute que si tout a réussi, que le run porte sur `main`, et que ce n'est pas une validation de pull request (`Build.SourceBranch`, `Build.Reason`). Lancez sur votre branche.
2. **Pouvoir s'en passer au lancement.** Ajoutez un paramètre booléen `deposerEnRecette`, libellé « Déposer en recette », vrai par défaut. Le stage `Recette` n'est **inséré** que s'il est vrai (`${{ if }}`). Lancez avec la case décochée.
3. **Un test cassé.** Dans `tests/creneaux.test.js`, changez une valeur attendue (12 créneaux devient 13). Dans le job `Tests`, ajoutez une étape « Diagnostic » qui ne s'exécute **qu'en cas d'échec** et affiche la version de Node.js et la liste des fichiers de tests. Poussez, lancez, puis réparez le test.

**Point de contrôle 5** :

- run sur votre branche : `Recette` est **ignoré** (*skipped*) ;
- run avec « Déposer en recette » décoché : `Recette` **n'apparaît pas** dans le run. Vous savez dire quelle condition a été évaluée quand ;
- run avec le test cassé :
  - `Tests` est rouge, mais les résultats sont publiés et l'onglet Tests montre l'échec (attendu 13, obtenu 12) ;
  - « Diagnostic » s'est exécuté ;
  - `Paqueter` et `Recette` ne se sont pas exécutés ;
  - aucun artefact n'a été produit.

## Étape 6 — Déclencheurs, puis fusion dans `main` (10 min)

1. Remplacez le déclencheur « aucun » par un déclencheur CI :
   - sur `main` et sur les branches `feature/*` ;
   - qui ignore les commits ne modifiant que des fichiers Markdown (motif `'**/*.md'`, **entre apostrophes**).
2. Vérifiez-le : un commit qui ne touche que `README.md` ne lance rien, et un commit sur `js/app.js` (un commentaire) lance un run sans clic.
3. Ouvrez une pull request de votre branche vers `main`, liée à T6. Les règles du TP 2 bis s'appliquent : relecture, tâche liée, `clinique-ci` vert. Faites-la approuver, puis complétez-la.

**Point de contrôle 6** :

- le run de `main` déclenché par la fusion est **vert de bout en bout**, `Recette` compris ;
- sa raison de déclenchement est un déclencheur CI, pas `Manual` ;
- T6 est passée à **Closed** à la fusion.

## Pour aller plus loin (si vous avez fini)

Faites tourner le job `Tests` sur deux versions de Node.js, `20.x` et `22.x`, avec une **matrice** (`strategy: matrix`, démo, fichier `10`). Chaque entrée de la matrice redéfinit `versionNode` : la variable du job l'emporte sur celle de la racine. Le titre de la série de tests doit indiquer la version de Node.js.

