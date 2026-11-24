# TP 2 bis — Du ticket au code : Azure Repos et Azure Boards pour la clinique

> Module : 2 — Le contrôleur de code source
> Programme ORSYS : « utiliser Git avec Azure DevOps » ; relier le code à la gestion de projet
> Durée : environ 1 h 00
> Modalité : individuelle ; votre voisin joue John, le testeur, qui relit vos pull requests
> Après : TP 1 bis (projet `Clinique-<Prénom>`, backlog et sprints) et TP 2 (Git, pull request, stratégies de branche)

## Mise en situation

Le Sprint 1 de la clinique a commencé lundi 23 novembre. Le backlog est prêt depuis le TP 1 bis ; il manque le code. Jim est absent cette semaine : vous reprenez ses tâches.

L'équipe se fixe trois règles :

- chaque ligne de code se rattache à une tâche du sprint ;
- rien n'entre dans `main` sans relecture, sans tâche liée et sans tests verts ;
- le tableau du sprint avance quand le code avance, sans double saisie.

John, le testeur QA, relit les pull requests et valide la story en recette. Votre voisin joue John.

## Objectifs

À la fin du TP, vous aurez :

- ajouté des tâches techniques au sprint, estimées et suivies sur le tableau des tâches ;
- créé le dépôt `clinique-web`, configuré la liaison des commits, protégé `main` et branché l'intégration continue ;
- créé des branches depuis des éléments de travail et lié chaque commit à sa tâche ;
- fait avancer les tâches et la story par un commit, puis par des pull requests ;
- retrouvé, depuis une tâche ou une requête, le code qui la réalise.

## Prérequis

| Élément | Détail |
|---|---|
| Projet | `Clinique-<Prénom>` du TP 1 bis : la User Story #1 dans `Sprint 1` (23/11 – 04/12/2026), avec ses trois tâches. Sans TP 1 bis : créez un projet Agile `Clinique-<Prénom>`, datez `Iteration 1` du 23/11 au 04/12/2026, renommez-la `Sprint 1` et vérifiez qu'elle est sélectionnée pour l'équipe (Team configuration > Iterations), puis créez dans ce sprint la user story « Prendre rendez-vous en ligne » et les trois tâches T1, T2 et T3 du tableau de l'étape 1 |
| John | votre voisin, membre de votre organisation avec le niveau d'accès **Basic** : un Stakeholder n'ouvre pas Repos dans un projet privé (Organization settings > Users > menu de l'utilisateur > **Change access level**). Sans voisin : vous vous approuverez vous-même (étape 4) |
| Parallel job | celui qui a servi au pipeline `rdv-pr` du TP 2 |
| Poste | Git configuré (TP 2, étape 1), VS Code, Edge ou Chrome ; Node.js 20 ou plus récent si vous voulez lancer les tests en local (facultatif) |
| Code | le dossier `tp/module-02/clinique-web/` du support de formation |

Dans les commandes, remplacez `<organisation>` par le nom de votre organisation et `<Prénom>` par votre prénom.

## Les éléments de travail du TP

Vous remplirez la colonne « ID » à l'étape 1. Dans la suite, `<T1>` signifie « l'ID de la tâche T1 », par exemple `412` : le message `Fixes #<T0>` devient `Fixes #411`.

| Repère | Élément | ID |
|---|---|---|
| US1 | User Story #1 « Prendre rendez-vous en ligne » | |
| T0 | Rédiger le README du dépôt clinique-web | |
| T1 | Créer la maquette de l'interface utilisateur pour la prise de rendez-vous | |
| T2 | Développer l'interface utilisateur selon la maquette approuvée | |
| T3 | Intégrer l'API de calendrier pour afficher les disponibilités des médecins | |
| T4 | Écrire les tests unitaires du calcul des créneaux | |
| T5 | Mettre en place l'intégration continue du dépôt | |

## Déroulé et minutage

| Étape | Contenu | Durée |
|---|---|---|
| A — 1 | Le sprint de la semaine : réattribuer, ajouter et estimer les tâches | 15 min |
| B — 2 | Créer le dépôt et pousser le code de départ | 10 min |
| B — 3 | Une tâche fermée par un commit | 10 min |
| B — 4 | Configurer le dépôt et protéger `main` | 15 min |
| B — 5 | L'intégration continue | 15 min |
| C — 6 | Une branche née d'une tâche | 15 min |
| C — 7 | Première pull request : la maquette | 15 min |
| C — 8 | Deuxième pull request : les tests d'abord | 15 min |
| C — 9 | Deuxième pull request : le code, puis la fusion | 15 min |
| D — 10 | Suivre la trace, du ticket au code | 15 min |
| D — 11 | La recette de John | 5 min |

---

## Partie A — Le sprint côté Boards

### Étape 1 — Le sprint de la semaine (15 min)

1. Boards > **Sprints** > `Sprint 1` > onglet **Taskboard** : la User Story #1 et ses trois tâches. Au TP 1 bis (section J), vous avez fait avancer la story et fermé la tâche de la maquette : ramenez-les toutes les deux à l'état **New**. Le travail commence vraiment aujourd'hui.
2. Jim est absent : ouvrez T2 et T3 et assignez-les-vous (**Assigned To**).
3. Sur la ligne de la story, **+** > **Task** : créez T0, T4 et T5 avec les titres du tableau ci-dessus, assignées à vous.
4. Estimez les six tâches : ouvrez chacune et renseignez **Activity** et **Remaining Work** (en heures).

| Repère | Activity | Remaining Work |
|---|---|---|
| T0 | Documentation | 1 |
| T1 | Design | 3 |
| T2 | Development | 4 |
| T3 | Development | 4 |
| T4 | Testing | 2 |
| T5 | Deployment | 2 |

5. Reportez l'ID de chaque élément dans le tableau « Les éléments de travail du TP ».

**Point de contrôle 1** — Le Taskboard montre la story et six tâches à l'état New, toutes assignées à vous. Le volet **Work details** (bouton en haut à droite du sprint) affiche 16 heures de travail restant pour vous.

---

## Partie B — Le dépôt et ses règles

### Étape 2 — Créer le dépôt et pousser le code de départ (10 min)

1. **Repos** > sélecteur de dépôt en haut de la page > **New repository** : type Git, nom `clinique-web`, **Add a README décoché**, *Add a .gitignore* sur None > **Create**.
2. Copiez le code de départ dans un dossier de travail, puis poussez-le :

```bash
mkdir -p ~/tp2bis
cp -R <chemin-du-support>/tp/module-02/clinique-web ~/tp2bis/clinique-web
cd ~/tp2bis/clinique-web
git init -b main
git add .
git commit -m "Code de départ de la page de prise de rendez-vous"
git remote add origin https://dev.azure.com/<organisation>/Clinique-<Prénom>/_git/clinique-web
git push -u origin main
```

Sous Windows (PowerShell) : `Copy-Item -Recurse <chemin-du-support>\tp\module-02\clinique-web $HOME\tp2bis\clinique-web`.

3. Ouvrez `index.html` dans le navigateur (double-clic) : un bandeau, et une page encore vide.
4. Lisez `README.md`, puis `azure-pipelines.yml` : vous les utiliserez aux étapes 3 et 5.

**Point de contrôle 2** — Repos > Files affiche neuf fichiers, dont `.gitignore`, `azure-pipelines.yml` et les dossiers `css`, `js` et `tests`. Repos > Commits : un commit.

### Étape 3 — Une tâche fermée par un commit (10 min)

1. Taskboard : glissez T0 dans la colonne **Active**.
2. À la fin de `README.md`, ajoutez :

```markdown
## Conventions de l'équipe

- Une branche par élément de travail, créée depuis Boards : `feature/<id>-<sujet>`, `bugfix/<id>-<sujet>`.
- Chaque message de commit cite sa tâche : « Ajoute le formulaire #123 ».
- Rien n'entre dans `main` sans pull request : un relecteur, une tâche liée, des tests verts.
```

3. Committez et poussez directement sur `main` :

```bash
git commit -am "Ajoute les conventions de l'équipe au README. Fixes #<T0>"
git push
```

4. Rechargez le Taskboard, puis ouvrez T0.

**Point de contrôle 3** — T0 est passée seule à l'état **Closed**, son **Remaining Work** est vide, et sa zone **Development** affiche le commit. L'onglet **History** de T0 indique qui l'a fermée et avec quelle raison. Work details : 15 heures.

Profitez-en : c'est le dernier push direct sur `main` de ce TP.

### Étape 4 — Configurer le dépôt et protéger `main` (15 min)

1. Project settings > **Repositories** > `clinique-web` > onglet **Settings**. Repérez et lisez :
   - **Commit mention linking** : un `#ID` dans un message de commit lie le commit à l'élément ;
   - **Commit mention work item resolution** : un `Fixes #ID` ferme l'élément.

   Tous deux sont activés, sinon l'étape 3 n'aurait pas fonctionné.
2. **Repos > Branches** > menu de `main` > **Branch policies** :

| Stratégie | Réglage |
|---|---|
| Require a minimum number of reviewers | On, 1 ; *Allow requestors to approve their own changes* décoché (avec John) ou coché (seul) ; *When new changes are pushed* : *Reset all approval votes (does not reset votes to reject or wait)* |
| Check for linked work items | On, *Required* |
| Check for comment resolution | On, *Required* |
| Limit merge types | On, seul *Squash merge* coché |

La validation par le build vient à l'étape 5, une fois le pipeline créé.

**Point de contrôle 4** — `main` porte l'icône des stratégies dans Repos > Branches ; la page des stratégies rappelle qu'une stratégie requise impose les pull requests.

### Étape 5 — L'intégration continue (15 min)

1. Taskboard : T5 dans **Active**.
2. **Pipelines > New pipeline** > *Azure Repos Git* > `clinique-web` > *Existing Azure Pipelines YAML file* > branche `main`, chemin `/azure-pipelines.yml` > **Continue** > **Run**.
3. Pendant le run : menu du pipeline (trois points) > *Rename/move* > `clinique-ci`.
4. À la fin du run, ouvrez son onglet **Tests**.
5. Branch policies de `main` > **Build validation** > **+** : *Build pipeline* `clinique-ci`, *Trigger* Automatic, *Policy requirement* Required, *Build expiration* Immediately when main is updated, *Display name* `clinique-ci` > **Save**.
6. T5 ne produit aucun code. Dans sa zone **Discussion**, collez l'URL du run réussi, puis passez-la à **Closed** sur le Taskboard.

**Point de contrôle 5** — Le run de `clinique-ci` est vert ; l'onglet Tests affiche 3 tests réussis. Les stratégies de `main` en comptent cinq. T5 est fermée. Work details : 13 heures.

---

## Partie C — Du ticket au code

### Étape 6 — Une branche née d'une tâche (15 min)

1. Boards > **Boards**, niveau Stories : glissez la User Story #1 dans **Active**. Taskboard : T1 dans **Active**.
2. Ouvrez T1 > zone **Development** > **Create branch** : nom `feature/<T1>-maquette`, *Based on* `main`, dépôt `clinique-web` > **Create branch**.
3. En local :

```bash
git fetch
git switch feature/<T1>-maquette
```

4. Dans `index.html`, remplacez la ligne `<!-- Formulaire de prise de rendez-vous : à ajouter -->` par :

```html
      <h2>Choisir un créneau</h2>

      <label for="medecin">Médecin</label>
      <select id="medecin"></select>

      <h3>Créneaux libres aujourd'hui</h3>
      <ul id="creneaux"></ul>
      <p id="message"></p>

      <label for="motif">Motif de la consultation</label>
      <textarea id="motif" rows="3"></textarea>
```

5. Rechargez `index.html` dans le navigateur et choisissez « Dr Lefèvre ». Comparez les créneaux affichés avec `js/disponibilites.js`.
6. Committez et poussez :

```bash
git commit -am "Ajoute le formulaire de prise de rendez-vous #<T1>"
git push
```

**Point de contrôle 6** — La zone Development de T1 affiche la branche et le commit. Le formulaire s'affiche, mais le Dr Lefèvre propose 12 créneaux, y compris 08:00, déjà réservé : c'est le travail de T3.

### Étape 7 — Première pull request : la maquette (15 min)

1. **Repos > Pull requests** > **New pull request** : `feature/<T1>-maquette` vers `main`.
   - *Title* : `Maquette du formulaire de prise de rendez-vous`.
   - *Description* : ce que fait la PR et comment la tester (« ouvrir index.html, choisir un médecin »).
   - *Reviewers* : John.
   - *Work items* : vérifiez que T1 y figure ; sinon, ajoutez-la par son ID.
   - **Create**.
2. Dans la zone *Work items* de la PR, retirez T1. Observez la liste des stratégies, puis remettez T1.
3. John ouvre l'onglet **Files** et commente la ligne du `<textarea>` : « Le motif doit-il être obligatoire ? ». Répondez « Facultatif pour cette première version », puis **Reply & resolve**.
4. John vote **Approve** (seul : votez vous-même).
5. Quand toutes les stratégies sont vertes : **Complete** > *Merge type* **Squash commit**. Cochez **Complete associated work items after merging** et **Delete feature/<T1>-maquette after merging** > **Complete merge**.
6. En local :

```bash
git switch main
git pull --prune
git branch -D feature/<T1>-maquette
```

**Point de contrôle 7** — Retirer T1 a fait échouer *Check for linked work items* ; la remettre l'a rétablie. T1 est **Closed** sans que vous l'ayez touchée. Repos > Commits sur `main` : trois commits, le dernier commençant par `Merged PR`. Work details : 10 heures.

### Étape 8 — Deuxième pull request : les tests d'abord (15 min)

T2, T3 et T4 sont étroitement liées : une seule branche, une seule pull request, née de la story.

1. Taskboard : T2, T3 et T4 dans **Active**.
2. Ouvrez la User Story #1 > **Development** > **Create branch** : `feature/<US1>-creneaux-libres`, *Based on* `main`.
3. En local :

```bash
git fetch
git switch feature/<US1>-creneaux-libres
```

4. À la fin de `tests/creneaux.test.js`, ajoutez :

```js

describe("Créneaux déjà réservés", () => {
  test("un créneau réservé n'est pas proposé", () => {
    assert.deepEqual(creneauxLibres("09:00", "10:00", ["09:20"]), ["09:00", "09:40"]);
  });

  test("une journée complète ne propose aucun créneau", () => {
    assert.deepEqual(creneauxLibres("09:00", "10:00", ["09:00", "09:20", "09:40"]), []);
  });
});
```

5. Facultatif, si Node.js est installé : `node --test`.
6. Committez et poussez :

```bash
git commit -am "Ajoute les tests des créneaux réservés #<T4>"
git push -u origin feature/<US1>-creneaux-libres
```

7. Créez la pull request vers `main` :
   - *Title* : `Ne proposer que les créneaux libres` ;
   - *Description*, en remplaçant les repères par vos ID :

```text
Les créneaux déjà réservés ne sont plus proposés au patient.

Closed:#<T2>
Closed:#<T3>
Closed:#<T4>
Resolved:#<US1>
```

   - *Reviewers* : John ;
   - *Work items* : T2, T3, T4 et la User Story #1 (ajoutez celles qui manquent) ;
   - **Create**.

**Point de contrôle 8** — Le build `clinique-ci` de la PR est rouge ; son onglet Tests montre 5 tests, dont 2 en échec, ceux que vous venez d'écrire. La PR ne peut pas être terminée.

### Étape 9 — Deuxième pull request : le code, puis la fusion (15 min)

1. Dans `js/creneaux.js`, remplacez la fonction `creneauxLibres` par :

```js
function creneauxLibres(ouverture, fermeture, reservations) {
  return creneauxDeLaJournee(ouverture, fermeture)
    .filter((heure) => !reservations.includes(heure));
}
```

```bash
git commit -am "Retire les créneaux déjà réservés #<T3>"
```

2. Dans `js/app.js`, à la fin de la fonction `afficher`, juste après la ligne `    }));`, ajoutez :

```js

    const message = document.getElementById("message");
    message.textContent = libres.length === 0
      ? "Plus aucun créneau libre aujourd'hui pour ce médecin."
      : libres.length + " créneau(x) libre(s).";
```

```bash
git commit -am "Affiche le nombre de créneaux libres #<T2>"
git push
```

3. Rechargez `index.html` : le Dr Lefèvre propose 8 créneaux, le Dr Moreau n'en propose plus aucun.
4. Dans la PR, le build se relance seul. Pendant qu'il tourne : **Set auto-complete** > *Merge type* **Squash commit** ; **décochez** *Complete associated work items after merging* ; cochez *Delete feature/… after merging* > **Set auto-complete**.
5. John relit et vote **Approve** (seul : votez vous-même). La PR se termine seule quand le build est vert.
6. En local : `git switch main`, `git pull --prune`, `git branch -D feature/<US1>-creneaux-libres`.

**Point de contrôle 9** — T2, T3 et T4 sont **Closed** ; la User Story #1 est **Resolved**, et non Closed. Work details : 0 heure.

---

## Partie D — La traçabilité

### Étape 10 — Suivre la trace, du ticket au code (15 min)

1. Ouvrez T3 > zone **Development** : ce qui y figure, et d'où vient chaque lien.
2. **Repos > Commits**, branche `main` : combien de commits ? Où sont passés les commits de vos branches ? (Indice : onglet **Commits** de la deuxième pull request.)
3. **Pipelines** > `clinique-ci` : le run déclenché par la fusion sur `main`. Quel est son déclencheur ? Combien de tests ?
4. **Boards > Queries** > **New query**, enregistrées dans **Shared Queries** :

| Requête | Clauses |
|---|---|
| `Clinique - Tâches liées au code` | Work Item Type = Task ; Iteration Path = `Clinique-<Prénom>\Sprint 1` ; External Link Count > 0 |
| `Clinique - Fermées sans trace` | Work Item Type = Task ; State = Closed ; External Link Count = 0 |

**Point de contrôle 10** — La première requête renvoie cinq tâches : T0 à T4. La seconde renvoie T5. Vous savez dire pourquoi T5 y figure, et ce que signifierait une tâche de développement dans cette liste.

### Étape 11 — La recette de John (5 min)

1. Jouez John : `git pull` sur `main`, puis ouvrez `index.html`. Le Dr Moreau n'a plus de créneau, et le message le dit.
2. Recette validée : la story attend maintenant le retour de la clinique. Boards > Boards : John glisse la User Story #1 dans la colonne **Attente client** (état `En attente de validation`, TP 1 bis section G.1). Sans cette colonne, passez-la à **Closed**.

**Point de contrôle 11** — Le Taskboard du Sprint 1 n'a plus que des tâches fermées ; la story est dans `Attente client` (ou Closed). Son onglet **History** raconte le sprint : Active à l'étape 6, Resolved à la fusion, puis la décision de John.

