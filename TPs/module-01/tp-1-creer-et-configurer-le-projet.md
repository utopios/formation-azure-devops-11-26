# TP 1 — Créer et configurer le projet RDV

> Module : 1 — Intégration continue et Azure DevOps
> Programme ORSYS : « Créer et configurer un nouveau projet »
> Durée : 75 minutes, plus un bonus de 15 minutes
> Modalité : individuelle, en binôme pour l'étape 6 (droits d'accès)

## Mise en situation

Claire Vasseur, DSI de Santinord, vient de valider le passage sur Azure DevOps Services. Vous êtes chargé d'ouvrir le projet qui accueillera l'API de prise de rendez-vous **RDV** : son code (module 2), ses tests (module 3), ses pipelines (modules 4 à 8).

Karim Benali, Product Owner, vous a transmis son backlog sous forme de fichier CSV. Thomas et Hugo développeront dans une équipe, Léa assurera la recette dans une autre. Inès Dubois, à l'exploitation, a une exigence : Hugo, arrivé en septembre, peut consulter les éléments de travail de l'exploitation mais ne doit pas les modifier.

## Objectifs

À la fin du TP, vous aurez :

- créé le projet `RDV` (processus Agile, privé, Git) dans votre organisation ;
- créé deux équipes, une zone `Exploitation` et six sprints de deux semaines ;
- importé le backlog hiérarchique de Karim et planifié le premier sprint ;
- réglé le tableau Kanban de l'équipe de développement ;
- accordé un accès à votre binôme, avec une exception de sécurité vérifiée ensemble ;
- construit le tableau de bord de l'équipe.

## Prérequis

- Un compte Microsoft (personnel ou professionnel) et une **organisation Azure DevOps** dont vous êtes administrateur. Si vous n'en avez pas : `https://dev.azure.com` > **Start free**, puis choisissez un nom d'organisation et une région (Europe de l'Ouest). L'organisation est gratuite jusqu'à cinq utilisateurs Basic.
- Le fichier `backlog-rdv.csv` fourni par le formateur (dossier `demos/module-01/`). Ouvrez-le dans VS Code ou un éditeur de texte, **pas dans Excel**.
- L'adresse du compte Microsoft de votre voisin : il jouera Hugo dans votre organisation, vous jouerez Hugo dans la sienne.
- Microsoft Edge ou Google Chrome.

Point de départ : une organisation sans projet `RDV`. Si un projet de ce nom existe déjà (session précédente), supprimez-le ou nommez le vôtre `RDV-<prénom>` et adaptez les chemins de zone et d'itération en conséquence.

## Déroulé et minutage

| Étape | Contenu | Durée |
|---|---|---|
| 0 | Vérifier l'organisation | 5 min |
| 1 | Créer le projet | 5 min |
| 2 | Créer les équipes | 10 min |
| 3 | Zones et sprints | 10 min |
| 4 | Importer et planifier le backlog | 10 min |
| 5 | Régler le tableau Kanban | 10 min |
| 6 | Droits d'accès, en binôme | 15 min |
| 7 | Tableau de bord de l'équipe | 10 min |
| Bonus | Processus hérité `Agile-Santinord` | 15 min |

## Étape 0 — Vérifier l'organisation (5 min)

1. Ouvrez `https://dev.azure.com/<votre-organisation>` puis **Organization settings** (en bas à gauche).
2. Dans **Permissions**, ouvrez le groupe **Project Collection Administrators** : votre compte doit en être membre.
3. Dans **Pipelines > Settings**, relevez l'état des réglages de création de pipelines classiques (build et release).
4. Dans **Repos**, relevez l'état du réglage de création de dépôts TFVC.
5. Dans **Policies**, relevez l'état de **External guest access** (si votre organisation est rattachée à un tenant Microsoft Entra ID).

**Point de contrôle 0** — Vous êtes membre de Project Collection Administrators et vous savez dire, pour votre organisation, si les pipelines classiques et TFVC peuvent encore être créés.

## Étape 1 — Créer le projet (5 min)

1. Depuis la page d'accueil de l'organisation : **New project**.
2. Renseignez : nom `RDV`, description `Prise de rendez-vous en ligne des centres Santinord`, visibilité **Private**.
3. Dépliez **Advanced** : contrôle de version **Git**, processus **Agile**.
4. **Create**.

**Point de contrôle 1** — Project settings > Overview affiche le processus **Agile** et la visibilité **Private**. Le menu de gauche montre Boards, Repos, Pipelines, Test Plans et Artifacts. Repos contient un dépôt vide nommé `RDV`.

## Étape 2 — Créer les équipes (10 min)

1. Project settings > **Teams** > **New team**.
2. Créez `RDV - Dev` (description : « Thomas, Hugo : développement de l'API »), en laissant cochée la création d'une zone au nom de l'équipe.
3. Créez `RDV - Qualité` (description : « Léa : recette et qualité »), même réglage.
4. Ouvrez chacune des deux équipes et vérifiez que vous en êtes administrateur.

**Point de contrôle 2** — La liste des équipes contient `RDV Team` (l'équipe par défaut), `RDV - Dev` et `RDV - Qualité`. Dans Project settings > Boards > Project configuration > **Areas**, les zones `RDV\RDV - Dev` et `RDV\RDV - Qualité` existent.

## Étape 3 — Zones et sprints (10 min)

1. Project settings > Boards > Project configuration > **Areas** : sous `RDV`, créez la zone enfant `Exploitation`.
2. Onglet **Iterations** : sous `RDV`, créez six itérations de deux semaines, du lundi au vendredi de la semaine suivante, en commençant le lundi de la formation : `Sprint 1` à `Sprint 6`. Si des itérations existent déjà par défaut, renommez-les et datez-les.
3. Project settings > **Team configuration** : sélectionnez l'équipe `RDV - Dev` (le sélecteur d'équipe est dans le fil d'Ariane, tout en haut de la page), onglet **Iterations**, et ajoutez `Sprint 1` à `Sprint 6`. Faites de même pour `RDV - Qualité`.
4. Toujours pour `RDV - Dev`, onglet **General** > **Backlogs** : cochez **Epics**. Ce niveau est décoché par défaut ; sans lui, le backlog n'affiche pas l'epic à l'étape 4.
5. Onglet **Areas** : vérifiez que `RDV - Dev` a pour zone `RDV\RDV - Dev`.

**Point de contrôle 3** — Boards > **Sprints**, équipe `RDV - Dev` : `Sprint 1` apparaît comme sprint en cours (**Current**), avec ses dates. La zone `RDV\Exploitation` figure dans l'arborescence des zones.

## Étape 4 — Importer et planifier le backlog (10 min)

1. Ouvrez `backlog-rdv.csv` dans VS Code et repérez les colonnes `Title 1`, `Title 2`, `Title 3` : elles portent la hiérarchie epic, feature, user story.
2. Boards > **Queries** > **Import work items** > **Choose file** > `backlog-rdv.csv` > **Import**. (Selon la version de l'interface, le bouton peut aussi figurer sur la page Boards > Work items.)
3. Vérifiez qu'aucune ligne n'est signalée en erreur, puis **Save items**.
4. Sélectionnez les 17 éléments enregistrés et modifiez-les en masse : **Area Path** = `RDV\RDV - Dev`.
5. Créez à la main une user story `Surveiller la sonde /sante en production`, avec **Area Path** = `RDV\Exploitation`.
6. Boards > **Backlogs**, équipe `RDV - Dev`, niveau **Stories** : placez en tête « Réserver un créneau le samedi matin », puis « Annuler un rendez-vous jusqu'à 24 h avant » et « Consulter les créneaux libres d'un praticien ».
7. Ouvrez le volet de planification et glissez ces trois stories dans `Sprint 1`.

**Point de contrôle 4** — Au niveau **Epics** du backlog `RDV - Dev`, l'epic « Prise de rendez-vous en ligne » se déplie en 4 features et 12 user stories. Le backlog du `Sprint 1` contient les trois stories prioritaires. La story « Surveiller la sonde /sante en production » n'apparaît pas dans le backlog de `RDV - Dev` (elle est dans une autre zone).

## Étape 5 — Régler le tableau Kanban (10 min)

1. Boards > **Boards**, équipe `RDV - Dev`, niveau **Stories**, puis les paramètres du tableau (icône d'engrenage).
2. Onglet **Columns** : obtenez les colonnes suivantes.

| Colonne | État | Limite de travail en cours | Réglages |
|---|---|---|---|
| New | New | — | — |
| Analyse | Active | 3 | — |
| Développement | Active | 4 | colonne scindée en Doing / Done ; définition de fini : « tests xUnit verts, pull request approuvée » |
| Recette | Resolved | 3 | définition de fini : « validée par Léa sur rdv-recette » |
| Closed | Closed | — | — |

3. Onglet **Fields** des cartes (section Cards) : affichez **Tags** et **Priority** sur les cartes de user story.
4. Onglet **Styles** : ajoutez une règle qui colore les cartes dont **Priority** = 1.
5. Enregistrez, puis déplacez « Réserver un créneau le samedi matin » dans la colonne **Analyse**.

**Point de contrôle 5** — Le tableau montre cinq colonnes ; Développement est scindée en Doing et Done ; la limite apparaît en tête des colonnes Analyse, Développement et Recette ; les cartes de priorité 1 sont colorées et affichent leurs tags.

## Étape 6 — Droits d'accès, en binôme (15 min)

Votre voisin joue Hugo dans votre organisation, et inversement.

1. Organization settings > **Users** > **Add users** : l'adresse de votre voisin, niveau d'accès **Stakeholder**, projet `RDV`, groupe **Project Contributors**.
2. Project settings > **Teams** > `RDV - Dev` : ajoutez votre voisin comme membre.
3. Project settings > Boards > Project configuration > **Areas** : sur la zone `Exploitation`, ouvrez **Security**, ajoutez votre voisin et réglez **Edit work items in this node** sur **Deny**. Laissez **View work items in this node** tel qu'il est hérité.
4. Votre voisin, depuis son navigateur, ouvre votre projet `RDV` :
   - il modifie le titre d'une story de `RDV - Dev` et enregistre ;
   - il ouvre la story « Surveiller la sonde /sante en production » et tente de modifier son titre ;
   - il tente de glisser une story vers le haut du backlog de `RDV - Dev` ;
   - il ouvre **Repos**.
5. Inversez les rôles dans l'organisation de votre voisin.

**Point de contrôle 6** — Votre voisin enregistre la modification de la story de `RDV - Dev`, voit la story de la zone `Exploitation` mais ne peut pas l'enregistrer : un message lui indique qu'il n'a pas la permission. Il ne peut ni réordonner le backlog ni ouvrir Repos. Notez la cause de chaque comportement : niveau d'accès ou permission.

## Étape 7 — Tableau de bord de l'équipe (10 min)

1. Boards > **Queries** > **New query** : type de work item = User Story, Priority = 1, State différent de Closed. Enregistrez-la dans **Shared Queries** sous le nom `Stories P1 ouvertes`.
2. Overview > **Dashboards** : sélectionnez l'équipe `RDV - Dev`, créez ou ouvrez son tableau de bord.
3. Ajoutez quatre widgets : **Query Results** (requête `Stories P1 ouvertes`), **Chart for Work Items** (même requête, camembert par état), un widget de sprint (avancement ou burndown du sprint en cours), **Markdown** (la définition de fini de l'équipe).
4. Enregistrez.

**Point de contrôle 7** — Le tableau de bord de `RDV - Dev` affiche les quatre widgets ; la liste des stories P1 et le camembert concordent.

## Bonus — Processus hérité `Agile-Santinord` (15 min)

Léa souhaite distinguer les stories qui attendent la validation d'un centre de santé.

1. Organization settings > Boards > **Process** : à partir du processus **Agile**, créez un processus hérité nommé `Agile-Santinord`.
2. Dans `Agile-Santinord`, type **User Story** > **States** : ajoutez l'état `En attente de validation` dans la catégorie **Resolved**.
3. Basculez le projet `RDV` sur `Agile-Santinord` (depuis l'onglet **Projects** du processus Agile).
4. Revenez au tableau de `RDV - Dev` : le nouvel état n'est associé à aucune colonne. Associez-le à la colonne **Recette**.

**Point de contrôle bonus** — Une story peut passer à l'état `En attente de validation` et reste visible dans la colonne Recette.

