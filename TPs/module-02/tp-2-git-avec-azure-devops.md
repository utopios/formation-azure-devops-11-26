# TP 2 — Utiliser Git avec Azure DevOps

> Module : 2 — Le contrôleur de code source
> Programme ORSYS : « utiliser Git avec Azure DevOps »
> Durée : 2 h en deux parties — partie 1 le jour 1 (50 min), partie 2 le jour 2 (70 min)
> Travail individuel, avec un voisin pour la revue de code (voir l'étape 9)

## Mise en situation

Santinord quitte TFS 2015. Thomas Lemaire a extrait la dernière version de `$/RDV/Main` : c'est le dossier `rdv-api` fourni avec la formation, un code qui compile et dont les 29 tests passent, mais qui n'a pas encore d'historique Git. Claire Vasseur a fixé deux exigences : le code vit dans Azure Repos, et plus rien n'entre dans `main` sans pull request relue, liée à une demande et vérifiée par un build. Hugo Martin, arrivé en septembre, a l'habitude de pousser directement sur la branche principale : la protection doit l'en empêcher, sans le bloquer dans son travail.

Vous jouez Thomas : vous importez le code, vous le clonez, vous protégez `main`, puis vous livrez une modification par pull request, conflit compris, jusqu'au tag de version.

## Objectifs

- Pousser un dossier local dans un dépôt Azure Repos vide et vérifier ce qui y est entré
- Cloner un dépôt depuis la ligne de commande et depuis VS Code ou Visual Studio ; synchroniser deux clones
- Créer le pipeline de validation `rdv-pr` et protéger `main` par des stratégies de branche
- Livrer une modification par branche et pull request : work item lié, build de validation, revue, fusion squash
- Résoudre un conflit de fusion et poser un tag annoté de version

## Prérequis

| Élément | Détail |
|---|---|
| Organisation Azure DevOps | la vôtre (créée au module 1), avec l'accès **Basic** ; vous êtes Project Administrator du projet |
| Projet | `RDV`, processus Agile (TP 1). Si vous partez de zéro : *New project*, nom `RDV`, *Version control* Git, *Work item process* Agile |
| User story | « Réserver un créneau le samedi matin » (importée au TP 1). Sans backlog : créez-la dans *Boards > Work items > New Work Item > User Story*. Notez son **ID** : il est écrit `<id>` dans la suite |
| Parallel job | *Organization settings > Pipelines > Parallel jobs* : au moins 1 job Microsoft-hosted. Une organisation neuve n'en a pas : la gratuité s'active en reliant l'organisation à une souscription Azure (*Organization settings > Billing*) ; à défaut, elle se demande (`https://aka.ms/azpipelines-parallelism-request`, plusieurs jours ouvrés) ; votre formateur vous indique la solution retenue pour la salle |
| Poste | Git 2.40 ou plus récent avec Git Credential Manager (fourni avec Git pour Windows ; `brew install --cask git-credential-manager` sur macOS), VS Code ou Visual Studio 2022 / 2026 ; SDK .NET 10 facultatif |
| Code | le dossier `demos/fil-rouge/rdv-api/` du support de formation |

Ce TP est autonome : il part d'un projet `RDV` existant ou vide, et du dossier `rdv-api`. Dans les commandes, remplacez `<organisation>` par le nom de votre organisation (`https://dev.azure.com/<organisation>`).

---

## Partie 1 (jour 1) — Importer et cloner `rdv-api`

### Étape 1 — Configurer Git (5 min)

```bash
git --version
git config --global user.name "Prénom Nom"
git config --global user.email "prenom.nom@exemple.fr"
git config --global init.defaultBranch main
```

Utilisez l'adresse de votre compte Azure DevOps : c'est elle qui relie vos commits à votre profil.

**Point de contrôle 1** — `git config --global --list` affiche votre nom et votre adresse.

### Étape 2 — Créer le dépôt vide `rdv-api` (5 min)

1. Ouvrez le projet `RDV`, puis **Repos**.
2. Sélecteur de dépôt en haut de la page > **New repository**.
3. *Repository type* : Git ; *Repository name* : `rdv-api`.
4. **Décochez « Add a README »** et laissez *Add a .gitignore* sur None : le dépôt doit être vide.
5. **Create**.

**Point de contrôle 2** — La page du dépôt `rdv-api` indique qu'il est vide et propose des commandes pour y pousser un dépôt existant.

### Étape 3 — Pousser le dossier local (10 min)

Copiez le dossier du fil rouge dans un dossier de travail, en dehors du support de formation :

```bash
mkdir -p ~/tp2
cp -R <chemin-du-support>/demos/fil-rouge/rdv-api ~/tp2/rdv-api
cd ~/tp2/rdv-api
```

Sous Windows (PowerShell) : `Copy-Item -Recurse <chemin-du-support>\demos\fil-rouge\rdv-api $HOME\tp2\rdv-api`.

```bash
git init -b main
git add .
git status --short
git commit -m "Import initial de rdv-api depuis TFS 2015"
git remote add origin https://dev.azure.com/<organisation>/RDV/_git/rdv-api
git push -u origin main
```

Au premier `push`, Git Credential Manager ouvre une fenêtre de connexion : connectez-vous avec le compte de votre organisation.

**Point de contrôle 3** — `git status --short` liste 39 fichiers, aucun sous `bin/` ni `obj/` ; le `push` se termine par `* [new branch]      main -> main`.

### Étape 4 — Explorer le dépôt dans Azure Repos (5 min)

1. **Repos > Files** : parcourez l'arborescence ; ouvrez `pipelines/pr-validation.yml` et `.gitignore`.
2. **Repos > Commits** : un seul commit, votre nom, son SHA court.
3. **Repos > Branches** : `main`, marquée *Default*.
4. *Project settings > Repositories > rdv-api > Settings* : repérez **Commit mention linking**.

**Point de contrôle 4** — Aucun dossier `bin/` ni `obj/` dans Repos > Files ; *Commit mention linking* est activé.

### Étape 5 — Cloner une seconde fois depuis l'IDE (10 min)

1. **Repos > Files > Clone** : copiez l'URL HTTPS.
2. **VS Code** : palette de commandes > *Git: Clone*, collez l'URL, choisissez le dossier `~/tp2/clone-ide`. **Visual Studio** : fenêtre de démarrage > *Clone a repository*, collez l'URL, même dossier.
3. Dans ce second clone, ouvrez `rdv-api.http` et ajoutez à la fin :

```http

### Créneaux du samedi (dernier créneau attendu : 11 h 40)
GET {{base}}/api/creneaux?praticienId=DR-LV-01&date=2026-11-28
```

4. Committez avec le message `Ajoute la requête des créneaux du samedi #<id>`, puis poussez (*Commit*, puis *Sync Changes* dans VS Code ; *Commit All*, puis *Push* dans Visual Studio).

**Point de contrôle 5** — Repos > Commits affiche deux commits ; le second est relié à la user story (ouvrez-la : sa zone *Development* mentionne le commit).

### Étape 6 — Synchroniser le premier clone (5 min)

```bash
cd ~/tp2/rdv-api
git fetch origin
git status
git log --oneline main origin/main
git pull
git log --oneline --graph --decorate
```

**Point de contrôle 6** — Après `git fetch`, `git status` indique que votre branche est en retard d'un commit (*behind*) ; après `git pull`, les deux clones et Repos > Commits montrent les mêmes deux commits, dans le même ordre.

Remarque : aujourd'hui, vous avez poussé directement sur `main`, sans relecture. C'est exactement ce que la partie 2 va interdire.

### Pour aller plus loin (partie 1)

- Créez une branche locale `essai`, faites-y un commit, revenez sur `main` (`git switch main`), fusionnez-la (`git merge essai`) puis supprimez-la (`git branch -d essai`) ; ne poussez rien.
- Comparez `git log --oneline --graph --all` avant et après la fusion.

---

## Partie 2 (jour 2) — Protéger `main` et livrer par pull request

Avant de commencer, mettez vos deux clones à jour (`git pull` dans chacun).

### Étape 7 — Créer le pipeline `rdv-pr` (10 min)

1. **Pipelines > New pipeline** > *Azure Repos Git* > `rdv-api`.
2. *Existing Azure Pipelines YAML file* : branche `main`, chemin `/pipelines/pr-validation.yml` > *Continue*.
3. Lisez le YAML affiché : `trigger: none`, et l'en-tête qui explique que la clé `pr:` est ignorée sur Azure Repos.
4. Liste déroulante du bouton **Run** > **Save**.
5. Menu du pipeline (trois points) > *Rename/move* : `rdv-pr`.
6. Lancez-le une fois à la main (**Run pipeline**, branche `main`) pour vérifier que votre organisation dispose d'un agent.

**Point de contrôle 7** — Le run de `rdv-pr` sur `main` est vert en 3 à 5 minutes ; son onglet **Tests** affiche 29 tests réussis.

### Étape 8 — Organiser la revue (5 min)

Une pull request doit être approuvée par quelqu'un d'autre que son auteur. Deux options :

- **Option A, en binôme (recommandée)** : invitez votre voisin dans votre organisation (*Organization settings > Users > Add users*, niveau d'accès Basic, projet `RDV`, groupe *Contributors*) ; il fera de même avec vous. Chacun relira les PR de l'autre. Si l'organisation refuse les comptes extérieurs à son annuaire, passez à l'option B.
- **Option B, seul** : à l'étape 9, cochez *Allow requestors to approve their own changes*. C'est un **compromis de salle** : il vous permet de voir le mécanisme complet, mais il retire l'essentiel de la protection, puisque l'auteur peut s'approuver seul. On ne le coche jamais sur un dépôt réel.

### Étape 9 — Protéger `main` (10 min)

**Repos > Branches** > menu (trois points) de `main` > **Branch policies**. Réglez :

| Stratégie | Réglage |
|---|---|
| Require a minimum number of reviewers | On ; *Minimum number of reviewers* : 1 ; *Allow requestors to approve their own changes* : décoché (option A) ou coché (option B) ; *When new changes are pushed* : *Reset all approval votes (does not reset votes to reject or wait)* |
| Check for linked work items | On, *Required* |
| Check for comment resolution | On, *Required* |
| Limit merge types | On ; seul *Squash merge* coché |
| Build validation | **+** ; *Build pipeline* : `rdv-pr` ; *Trigger* : Automatic ; *Policy requirement* : Required ; *Build expiration* : Immediately when main is updated ; *Display name* : `rdv-pr` ; **Save** |

**Point de contrôle 9** — Dans Repos > Branches, `main` porte l'icône des stratégies ; la page des stratégies rappelle qu'une stratégie requise impose les pull requests et interdit la suppression de la branche.

### Étape 10 — Jouer Hugo : un push direct sur `main` (5 min)

```bash
cd ~/tp2/rdv-api
git switch main
echo "" >> README.md
git commit -am "Retouche directe du README"
git push
```

**Point de contrôle 10** — Le push est refusé avec le message `TF402455: Pushes to this branch are not permitted; you must use a pull request to update this branch.`

Annulez ce commit local :

```bash
git reset --hard origin/main
```

### Étape 11 — Une branche de fonctionnalité (5 min)

```bash
git switch -c feature/<id>-doc-samedi
```

Dans `README.md`, ligne « Règles », remplacez `samedi 8 h - 12 h,` par `samedi 8 h - 12 h (dernier créneau à 11 h 40),`. La ligne devient :

```text
Règles : lundi-vendredi 8 h - 19 h, samedi 8 h - 12 h (dernier créneau à 11 h 40), créneaux de 20 minutes
```

```bash
git commit -am "Documente le dernier créneau du samedi #<id>"
git push -u origin feature/<id>-doc-samedi
```

### Étape 12 — La pull request (10 min)

1. **Repos > Files** : le bandeau signale votre branche ; **Create a pull request**.
2. *Title* : `Documenter le dernier créneau du samedi` ; *Description* : une phrase sur le pourquoi.
3. *Reviewers* : votre voisin (option A).
4. *Work Items* : vérifiez que la user story `<id>` est présente ; sinon, ajoutez-la par son ID.
5. **Create** (et non *Create as draft* : une PR brouillon ne déclenche pas le build de validation).
6. Ouvrez le build `rdv-pr` lancé par la PR ; repérez la référence construite, `refs/pull/<numéro>/merge`.
7. Option A : votre voisin ajoute un commentaire sur la ligne modifiée, par exemple « Préciser aussi la durée ? ». Répondez, puis **Reply & resolve**.

**Ne terminez pas encore la PR.**

**Point de contrôle 12** — La page *Overview* de la PR liste les stratégies : réviseur en attente, work item lié, commentaires résolus, `rdv-pr` en cours puis réussi.

### Étape 13 — Un collègue modifie la même ligne (10 min)

Léa met à jour la même phrase du `README.md` et sa modification arrive dans `main` avant la vôtre. Jouez-la depuis votre second clone :

```bash
cd ~/tp2/clone-ide
git switch main
git pull
git switch -c docs/<id>-duree-par-defaut
```

Dans `README.md`, ligne « Règles », remplacez `créneaux de 20 minutes` par `créneaux de 20 minutes par défaut`, puis :

```bash
git commit -am "Précise la durée de créneau par défaut #<id>"
git push -u origin docs/<id>-duree-par-defaut
```

Créez la pull request de cette branche vers `main`, faites-la approuver (voisin, ou vous-même en option B), attendez `rdv-pr` vert, puis **Complete** en *Squash commit*, avec *Delete docs/… after merging*.

Revenez sur votre première pull request.

**Point de contrôle 13** — La PR `feature/<id>-doc-samedi` signale un conflit sur `README.md` ; elle ne peut plus être terminée.

### Étape 14 — Résoudre le conflit (10 min)

```bash
cd ~/tp2/rdv-api
git switch feature/<id>-doc-samedi
git fetch origin
git merge origin/main
```

Git s'arrête sur `CONFLICT (content): Merge conflict in README.md`. Ouvrez le fichier : la ligne « Règles » apparaît deux fois, entre les marqueurs `<<<<<<<`, `=======` et `>>>>>>>`. Remplacez tout le bloc, marqueurs compris, par une seule ligne qui garde les deux intentions :

```text
Règles : lundi-vendredi 8 h - 19 h, samedi 8 h - 12 h (dernier créneau à 11 h 40), créneaux de 20 minutes par défaut
```

```bash
git add README.md
git commit --no-edit
git push
```

VS Code et Visual Studio proposent aussi un éditeur de fusion (*Accept Current*, *Accept Incoming*, *Accept Both*) : ici, aucune des deux versions seule n'est juste, il faut écrire la ligne combinée.

**Point de contrôle 14** — `grep -c '<<<<<<<' README.md` affiche 0 ; la PR n'affiche plus de conflit et `rdv-pr` est relancé automatiquement.

### Étape 15 — Approuver et fusionner (5 min)

1. Votre voisin (option A), ou vous-même (option B), vote **Approve**.
2. Quand toutes les stratégies sont vertes : **Complete**, *Merge type* : **Squash commit** ; cochez *Complete associated work items after merging* et *Delete feature/… after merging* ; **Complete merge**.
3. Variante : si le build tourne encore, choisissez **Set auto-complete** ; la PR se terminera seule.

**Point de contrôle 15** — Repos > Commits sur `main` : un commit `Merged PR …` par pull request, aucun commit intermédiaire de la branche ; la user story est dans un état terminé et sa zone *Development* liste la PR.

### Étape 16 — Le tag de version (5 min)

```bash
git switch main
git pull --prune
git branch -D feature/<id>-doc-samedi
git log --oneline --graph --decorate
git tag -a v1.4.0 -m "RDV 1.4.0 : règles du samedi documentées"
git push origin v1.4.0
```

**Point de contrôle 16** — **Repos > Tags** affiche `v1.4.0`, son message et le commit visé, qui est le dernier de `main`.

### Pour aller plus loin (partie 2)

- Ajoutez une stratégie *Automatically included reviewers* : votre voisin, requis, pour le chemin `/pipelines/*` ; ouvrez une PR qui modifie un commentaire de `pipelines/pr-validation.yml` et constatez qu'il est ajouté d'office.
- *Project settings > Repositories > Policies > Branch Policies* : protégez le motif `release/*` pour tous les dépôts du projet.
- Créez `release/1.4` depuis le tag `v1.4.0` (*Repos > Branches > New branch*, *Based on* : le tag), corrigez une coquille dans `main` par PR, puis utilisez **Cherry-pick** sur la PR terminée pour reporter le correctif vers `release/1.4`.
- Verrouillez `main` (*Lock*), tentez de compléter une PR, puis déverrouillez.

