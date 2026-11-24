# TP 3 — Tests, bugs et régression

> Module : 3 — Mettre en place des tests
> Programme ORSYS : concevoir et implémenter des tests avec Azure ; gérer les bugs et la relivraison ; gestion de la régression
> Durée : 45 min en séance 
> Difficulté : 3 / 5
> Type : individuel (ou en binôme pour la revue de pull request), dans votre organisation Azure DevOps et sur votre poste

## Mise en situation

Sprint 1 de l'équipe RDV. Karim Benali a rédigé la user story « Réserver un créneau » et ses critères d'acceptation. Jusqu'ici, Léa Fontaine recettait dans un tableur Excel partagé et notait les anomalies dans `bugs.xlsx` ; deux fois sur trois, personne ne savait si une anomalie avait été corrigée, ni dans quelle version.

Claire Vasseur veut que la recette de ce sprint se fasse entièrement dans Azure DevOps : un plan de test, des cas de test liés à la story, un bug pour tout écart, une correction pilotée jusqu'à la relivraison et au re-test, et une régression qui tourne chaque nuit.

Vous jouez successivement **Léa** (conception et exécution des tests, bug, re-test), **Thomas** (correctif, pull request) et de nouveau **Léa** (régression).

### La user story

> **Réserver un créneau**
>
> En tant que patient, je veux réserver un créneau libre chez un praticien, afin d'obtenir un rendez-vous sans appeler le secrétariat.
>
> **Critères d'acceptation**
>
> 1. Un créneau libre, futur et prévu au planning d'un praticien connu se réserve : réponse 201 et en-tête `Location` vers le rendez-vous créé ; le créneau n'apparaît plus ensuite dans `GET /api/creneaux`.
> 2. Le planning va du lundi au vendredi de 8 h à 19 h et le samedi de 8 h à 12 h, en créneaux de 20 minutes à partir de 8 h ; aucun créneau le dimanche. Une demande hors planning est refusée (422).
> 3. Un créneau passé est refusé (422). Un créneau situé à plus de 90 jours est refusé (422).
> 4. Un créneau déjà réservé est refusé (409), quel que soit le patient qui le demande.
> 5. Un patient ne prend qu'un rendez-vous par jour chez un même praticien : une seconde demande pour le même jour et le même praticien est refusée (409). Il peut en revanche consulter deux praticiens différents le même jour.
> 6. L'identifiant patient n'est sensible ni à la casse ni aux espaces de début et de fin : deux saisies qui ne diffèrent que par la casse ou par ces espaces désignent le même patient.
> 7. Un praticien inconnu est refusé (404) ; une demande sans identifiant patient ou sans praticien est refusée (400).
>
> Chaque refus métier (404, 409, 422) renvoie une réponse *problem details* qui porte un champ `motif` ; une requête mal formée (400) n'en porte pas.

## Prérequis

- Un navigateur **Edge** ou **Chrome** (fenêtres surgissantes autorisées pour `dev.azure.com` : le Test Runner s'ouvre dans une nouvelle fenêtre)
- SDK .NET 10 (`dotnet --version` → `10.0.x`), Git, et un moyen d'envoyer des requêtes HTTP : VS Code avec l'extension REST Client, Visual Studio 2022 (fichiers `.http`), ou `curl`
- Votre compte en **Basic + Test Plans** dans votre organisation (Organization settings > Users > Access level). Créer un plan, des suites, des configurations et des paramètres l'exige ; exécuter des tests ne demande que Basic. Si votre organisation n'a pas de facturation, l'essai gratuit de 30 jours se démarre dans Organization settings > Billing ; le formateur vous indique la marche à suivre en salle
- Avoir suivi la démo 3.1

## Point de départ

Le TP part du projet `RDV` (processus Agile) dans lequel vous avez importé le dépôt `rdv-api` au TP 2, avec `main` protégée par la stratégie *Build validation* qui lance le pipeline `rdv-pr`.

**Si vous partez de zéro** (TP 2 non fait, ou nouvelle organisation) :

1. Créez le projet `RDV` : processus **Agile**, visibilité privée, contrôle de version Git.
2. Repos > **Import repository** : l'URL du dépôt `rdv-api` donnée par le formateur. Renommez le dépôt `rdv-api` si nécessaire.
3. Pipelines > **New pipeline** > Azure Repos Git > `rdv-api` > **Existing Azure Pipelines YAML file** > branche `main`, chemin `/pipelines/pr-validation.yml` > **Save** (menu à côté de Run). Renommez le pipeline `rdv-pr`.
4. Repos > Branches > `main` > Branch policies > **Build validation** > `+` : pipeline `rdv-pr`, déclenchement automatique, obligatoire.
5. Boards > Project configuration : vérifiez que l'itération `Sprint 1` existe et qu'elle est sélectionnée pour votre équipe.

Clonez le dépôt sur votre poste et vérifiez qu'il compile :

```bash
git clone <url-https-de-votre-depot> rdv-api
cd rdv-api
dotnet test
```

**Point de contrôle 0** : `dotnet test` affiche deux lignes « Réussi! » (domaine et API), 29 tests au total, aucun échec.

## Étapes

### Étape 1 — La user story et ses critères (5 min)

1. Boards > Backlogs > **New Work Item** > User Story : titre `Réserver un créneau`.
2. Itération `Sprint 1` ; si le backlog du TP 1 est importé, rattachez-la à la feature « Réservation en ligne » (lien Parent).
3. Champ **Description** : la phrase « En tant que patient… ». Champ **Acceptance Criteria** : les sept critères ci-dessus, numérotés.
4. **Save**.

**Point de contrôle 1** : la story apparaît dans le backlog du Sprint 1, avec ses sept critères dans le champ Acceptance Criteria.

### Étape 2 — Le plan de test et la suite de la story (5 min)

1. Test Plans > Test plans > **New Test Plan** : nom `RDV - Sprint 1`, Area Path `RDV`, Iteration `RDV\Sprint 1` > **Create**.
2. Menu `⋮` de la suite racine > **New Suite** > **Requirement based suite**. Lancez la requête proposée, cochez « Réserver un créneau » > **Create suites**.
3. Test Plans > **Configurations** : créez une variable de configuration `Cible` avec la valeur `API locale`, puis une configuration de test `API locale` qui utilise `Cible = API locale`.
4. Menu `⋮` de la suite « Réserver un créneau » > **Assign configurations** : cochez `API locale` et décochez la configuration par défaut.

**Point de contrôle 2** : le plan `RDV - Sprint 1` contient une suite `<id> : Réserver un créneau`, vide, à laquelle seule la configuration `API locale` est affectée.

### Étape 3 — Dériver les cas de test des critères (20 min)

Votre objectif : **au moins un cas de test par critère d'acceptation**, chacun avec des étapes vérifiables (action et résultat attendu : statut HTTP, motif, contenu utile). Pour chaque critère, cherchez les classes d'équivalence (les valeurs qui doivent se comporter pareil) et les valeurs limites (juste avant, sur, juste après la frontière).

Règles de rédaction :

- Le titre est une phrase qui décrit le comportement attendu (`Un créneau déjà réservé est refusé`).
- Toutes les dates sont des **dates futures** dans les 90 jours : notez J un jour ouvré à venir (par exemple demain), S et D le samedi et le dimanche qui suivent. La date `2026-11-24` livrée dans `rdv-api.http` est déjà passée l'après-midi du TP : adaptez `@jour`.
- L'agenda de l'API est **en mémoire** : redémarrer l'API remet tout à zéro. Prévoyez-le dans vos étapes quand un cas dépend d'un état vide.
- Les praticiens existants : `DR-LV-01`, `DR-LV-02`, `DR-RG-01`, `DR-RG-02`, `DR-VA-01`, `DR-VA-02`.

**3.1 — Un cas complet, à reproduire tel quel.** Onglet **Define** de la suite > **New Test Case**, titre `Un créneau libre se réserve et disparaît des créneaux libres` :

| Étape | Action | Résultat attendu |
|---|---|---|
| 1 | Démarrer l'API : `dotnet run --project src/Santinord.Rdv.Api --urls http://localhost:5080`, puis `GET /sante` | 200, `{"statut":"ok"}` |
| 2 | `GET /api/creneaux?praticienId=DR-LV-01&date=J` | 200, la liste contient `JT10:00:00` |
| 3 | `POST /api/rendez-vous` avec `{"praticienId":"DR-LV-01","patientId":"P-104233","debut":"JT10:00:00"}` | 201, en-tête `Location: /api/rendez-vous/<guid>` |
| 4 | `GET /api/creneaux?praticienId=DR-LV-01&date=J` | 200, `JT10:00:00` n'est plus dans la liste |

Transformez l'étape 1 en **étape partagée** : sélectionnez-la > icône **Create shared steps** > nom `Démarrer l'API et vérifier /sante`. Vous l'insérerez dans les cas suivants avec l'icône **Insert shared steps**.

**3.2 — Un cas paramétré, à reproduire.** Titre `Une demande hors planning est refusée` :

| Étape | Action | Résultat attendu |
|---|---|---|
| 1 | Étape partagée `Démarrer l'API et vérifier /sante` | 200 |
| 2 | `POST /api/rendez-vous` avec `DR-LV-01`, `P-104233`, `"debut":"@debut"` | 422, `"motif":"HorsPlanning"` |

Dans la grille **Parameter values** sous les étapes, une ligne par valeur de `@debut` : un horaire non aligné sur la grille de 20 minutes, un horaire avant l'ouverture, l'heure exacte de fermeture en semaine, le samedi à 12 h, un dimanche.

**3.3 — À vous : les critères 3 à 7.** Écrivez les cas qui manquent. Utilisez des paramètres chaque fois que plusieurs valeurs doivent produire le même résultat. Ne vous limitez pas à la valeur « évidente » : relisez chaque critère mot par mot et demandez-vous quelles saisies un patient, un secrétariat ou une application mobile pourraient réellement envoyer.

**Point de contrôle 3** : la suite contient au moins **7 cas de test**, tous en état *Design* et tous liés à la story (onglet Links du cas : lien *Tests*) ; au moins deux cas ont une grille de paramètres ; l'étape partagée apparaît dans au moins trois cas.

### Étape 4 — Exécuter contre l'API locale (10 min)

1. Lancez l'API dans un terminal, à la racine du dépôt :

   ```bash
   dotnet run --project src/Santinord.Rdv.Api --urls http://localhost:5080
   ```

2. Ouvrez `rdv-api.http`, réglez `@jour` sur J, envoyez « Santé » puis « Version et environnement » : notez la réponse de `/version`.
3. Suite « Réserver un créneau » > onglet **Execute** > sélectionnez tous les points de test > **Run for web application**.
4. Pour chaque étape : envoyez la requête, comparez au résultat attendu, marquez l'étape réussie ou échouée. Sur une étape échouée, écrivez dans le commentaire **la requête envoyée et la réponse obtenue** (statut et corps). Pour un cas paramétré, le runner présente les itérations l'une après l'autre.
5. Sur tout écart, passez à l'étape 5 avant de clore le run.

**Point de contrôle 4** : dans l'onglet Execute, chaque point de test a un résultat (Passed, Failed ou Blocked) ; l'en-tête du plan affiche un pourcentage de points exécutés.

### Étape 5 — Un bug par écart (5 min)

Pour chaque écart constaté, depuis l'étape en échec du runner : **Create bug**.

1. **Titre** : un fait observable, compréhensible sans ouvrir le bug. Pas d'hypothèse sur la cause.
2. **Repro Steps** : pré-remplies par le runner ; complétez avec la requête exacte, la réponse obtenue et la réponse attendue (critère d'acceptation concerné).
3. **Found in Build** : la réponse de `/version` et le SHA du commit testé (`git log -1 --format=%h`).
4. **Severity** : votre évaluation de l'impact pour les patients et les secrétariats. **Priority** : votre proposition ; Karim tranchera.
5. **Save & Close**, puis terminez le run (**Save and close** dans le runner).

**Point de contrôle 5** : chaque bug est en état *New*, lié au cas de test (onglet Links) ; le point de test correspondant est *Failed* ; un second testeur pourrait reproduire le bug avec vos seules Repro Steps.

### Étape 6 — Piloter la correction (15 min)

Vous êtes maintenant Thomas. Le bug porte l'identifiant `<id>`.

1. Bug : état **Active**, assigné à vous.
2. Branche de correction :

   ```bash
   git switch main && git pull
   git switch -c bugfix/<id>-<mot-cle>
   ```

3. **Le test d'abord.** Dans `tests/Santinord.Rdv.Domain.Tests/AgendaTests.cs`, ajoutez un test xUnit qui reproduit le scénario de votre bug au niveau du domaine. Il porte le trait de régression et un nom qui décrit le comportement attendu :

   ```csharp
   [Fact]
   [Trait("Category", "Regression")]
   public void <Comportement_attendu_en_une_phrase>()
   ```

   Inspirez-vous des tests existants du fichier (`NouvelAgenda()`, les constantes `Leroy` et `Mardi`). Vérifiez qu'il **échoue** :

   ```bash
   dotnet test --filter "Category=Regression"
   ```

4. Commitez et poussez le test seul, puis ouvrez la pull request vers `main` ; dans la section **Work items** de la PR, ajoutez le bug `<id>` :

   ```bash
   git commit -am "Test de non-régression du bug #<id>"
   git push -u origin bugfix/<id>-<mot-cle>
   ```

5. Attendez le build de validation `rdv-pr`.
6. **Le correctif.** Corrigez la règle dans `src/Santinord.Rdv.Domain/`, au plus près de la règle métier. Vérifiez en local que tous les tests passent (`dotnet test`), commitez, poussez. Le build de validation se relance.
7. Faites approuver la PR (votre binôme, ou selon la stratégie posée au TP 2), puis **Complete** : type de fusion *Squash commit*, **décochez** « Complete associated work items after merging », supprimez la branche.
8. Bug : état **Resolved**, raison *Fixed*.

**Point de contrôle 6** : la PR montre deux exécutions de `rdv-pr`, la première **en échec** (onglet Tests du run : votre test en échec), la seconde **réussie** ; la PR est fusionnée et liée au bug ; le bug est *Resolved*.

### Étape 7 — Relivrer (10 min)

La fusion dans `main` doit produire une version relivrée. Si le pipeline `rdv-ci-cd` existe déjà dans votre projet, la fusion l'a déclenché : allez au point 3.

1. Pipelines > **New pipeline** > Azure Repos Git > `rdv-api` > **Existing Azure Pipelines YAML file** > branche `main`, chemin `/azure-pipelines.yml` > **Continue**.
2. **Run** : laissez `cible` = `simulation` et **décochez** « Inclure le stage de production ». Renommez ensuite le pipeline `rdv-ci-cd`.
3. Si le run affiche « This pipeline needs permission to access a resource », ouvrez **View** > **Permit** (environments créés au premier run).
4. Si la production est incluse (run déclenché automatiquement), le run s'arrête sur « Vérification avant production » : **Resume**. En mode simulation, la « production » est une API démarrée sur l'agent.
5. Reportez le numéro du run (`1.4.N`) dans le champ **Integrated in Build** du bug.

**Point de contrôle 7** : le run `1.4.N` est vert ; stage Build, onglet **Tests** : tous les tests réussis, dont le vôtre ; stages Dev et Recette réussis, avec l'étape « Test de fumée (/sante, /version) ».

### Étape 8 — Re-tester et fermer (5 min)

Vous êtes de nouveau Léa. En mode simulation, l'environnement de recette n'existe que le temps du stage : le re-test se fait sur l'API construite depuis `main` à jour, c'est-à-dire le code que le run `1.4.N` a livré. (En mode `azure`, Léa re-testerait sur `app-rdv-recette`.)

1. Arrêtez l'API (Ctrl+C), puis `git switch main && git pull`, et relancez-la.
2. Test Plans > suite > Execute > le point *Failed* > **Run for web application** : rejouez le cas. Marquez le résultat.
3. Si le re-test passe : bug **Closed**. S'il échoue : bug **Active** avec un commentaire, et retour à l'étape 6.
4. Ajoutez le tag `regression` au cas de test qui a trouvé le bug.

**Point de contrôle 8** : le point de test est *Passed* et son historique de résultats (volet de détail du point) montre *Failed* puis *Passed* ; le bug est *Closed* et ses liens mènent au cas de test, à la story, à la PR et au commit.

### Étape 9 — La régression (10 min)

1. Ajoutez le tag `regression` à deux autres cas de test qui protègent une règle critique (par exemple le créneau déjà réservé et le hors planning).
2. Dans le plan `RDV - Sprint 1`, menu `⋮` de la suite racine > **New Suite** > **Query based suite**. Gardez la clause qui limite aux cas de test et ajoutez : `Tags` `Contains` `regression`. **Run query**, puis **Create suite**. Renommez la suite `Régression`.
3. Ajoutez le tag `regression` à un quatrième cas, puis rouvrez la suite `Régression` : il y figure sans aucune autre action.
4. Pipelines > **New pipeline** > Azure Repos Git > `rdv-api` > **Existing Azure Pipelines YAML file** > `/pipelines/nightly-regression.yml` > **Save**. Renommez le pipeline `rdv-nuit`, puis **Run pipeline** une première fois à la main.
5. À la fin du run, ouvrez l'onglet **Tests**.
6. (Bonus) Dans cet onglet, sélectionnez votre test de non-régression > **Associate Test Case** > l'identifiant du cas de test qui a trouvé le bug. Ouvrez le cas : onglet **Associated Automation**, champ *Automation status*.

**Point de contrôle 9** : la suite `Régression` contient les quatre cas tagués ; le run de `rdv-nuit` est vert, et son onglet Tests montre deux exécutions : la suite complète, puis « Non-régression (second passage) » qui ne contient **que les tests marqués** `Regression` ; dans Pipelines > `rdv-nuit` > `⋯` > **Scheduled runs**, la prochaine exécution est annoncée à 2 h UTC.

