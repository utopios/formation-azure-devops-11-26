# Corrigé du TP 1 : créer et configurer le projet RDV

> Module 1 : Intégration continue et Azure DevOps
> À lire après le TP, énoncé à côté.

Ce corrigé reprend le TP étape par étape : où cliquer, ce que vous devez obtenir, et pourquoi. Les points de contrôle de l'énoncé restent la référence : comparez votre projet à chacun d'eux.

Si votre projet s'appelle `RDV-<prénom>`, remplacez `RDV` par ce nom dans tous les chemins de zone et d'itération ci-dessous.

## Étape 0 : vérifier l'organisation

- Vous avez créé l'organisation, vous êtes donc automatiquement membre de **Project Collection Administrators**. Rien à ajouter.
- **Pipelines > Settings** : sur une organisation récente, les deux réglages *Disable creation of classic build pipelines* et *Disable creation of classic release pipelines* sont activés. Autrement dit, on ne peut plus créer de pipelines classiques : tout se fera en YAML, et c'est ce que nous ferons à partir du module 4.
- **Repos** : le réglage qui désactive la création de dépôts TFVC est activé lui aussi. Toute nouvelle équipe démarre en Git.
- **Policies > External guest access** : ce réglage n'apparaît que si l'organisation est rattachée à un tenant Microsoft Entra ID. Une organisation créée avec un compte Microsoft personnel ne l'est en général pas : n'importe quel compte Microsoft peut alors y être invité. Si elle est rattachée et que la politique est désactivée, vous ne pourrez pas inviter votre voisin à l'étape 6 s'il vient d'un autre tenant.

## Étape 1 : créer le projet

**New project** > nom `RDV`, la description, **Private** > **Advanced** : **Git**, **Agile** > **Create**.

L'assistant crée en même temps :

- l'équipe par défaut `RDV Team`, avec la zone racine `RDV` ;
- un dépôt Git vide nommé `RDV`.

Si TFVC apparaît dans la liste des contrôles de version, votre organisation est ancienne ou le réglage a été modifié. Ne le choisissez pas : le TP 2 suppose Git, et il faudrait recréer le projet.

## Étape 2 : créer les équipes

Project settings > **Teams** > **New team**, deux fois :

| Équipe | Description | Zone créée |
|---|---|---|
| `RDV - Dev` | Thomas, Hugo : développement de l'API | `RDV\RDV - Dev` |
| `RDV - Qualité` | Léa : recette et qualité | `RDV\RDV - Qualité` |

Laissez cochée la case qui crée une zone au nom de l'équipe : c'est elle qui donne à chaque équipe son propre backlog. Le créateur d'une équipe en devient administrateur, vous n'avez rien à faire de plus.

Une équipe, dans Azure DevOps, c'est un backlog, un tableau, des sprints et une ou plusieurs zones. Deux équipes qui partagent un projet ne voient pas le même backlog : ce qui les sépare, c'est la zone.

## Étape 3 : zones et sprints

**Zone Exploitation.** Project settings > Boards > Project configuration > **Areas** > sur `RDV`, **New child** > `Exploitation`.

**Sprints.** Onglet **Iterations**. Le projet contient déjà des itérations sans dates (`Iteration 1`, `Iteration 2`…) : renommez-les et datez-les, puis créez les suivantes avec **New child** sous `RDV`.

| Sprint | Début | Fin |
|---|---|---|
| Sprint 1 | lundi 23/11/2026 | vendredi 04/12/2026 |
| Sprint 2 | lundi 07/12/2026 | vendredi 18/12/2026 |
| Sprint 3 | lundi 21/12/2026 | vendredi 01/01/2027 |
| Sprint 4 | lundi 04/01/2027 | vendredi 15/01/2027 |
| Sprint 5 | lundi 18/01/2027 | vendredi 29/01/2027 |
| Sprint 6 | lundi 01/02/2027 | vendredi 12/02/2027 |

**Sprints de l'équipe.** Créer une itération dans le projet ne suffit pas : chaque équipe choisit les siennes. Project settings > **Team configuration**, sélectionnez `RDV - Dev` dans le fil d'Ariane en haut de la page, onglet **Iterations** > **Select iteration(s)** > `Sprint 1` à `Sprint 6`. Même chose pour `RDV - Qualité`.

L'erreur la plus courante de l'étape : sélectionner les sprints pour `RDV Team`, l'équipe affichée par défaut, au lieu de `RDV - Dev`. Regardez toujours le nom de l'équipe dans le fil d'Ariane avant de cliquer.

**Niveau Epics.** Même page, onglet **General** > **Backlogs** : cochez **Epics**. Il est décoché par défaut ; sans lui, vous ne verrez pas l'epic à l'étape 4.

**Zone de l'équipe.** Onglet **Areas** : `RDV\RDV - Dev` est bien la zone de `RDV - Dev`.

Le sprint dont les dates encadrent la date du jour devient automatiquement **Current**. Aujourd'hui, c'est `Sprint 1`. S'il n'y a pas de sprint en cours, soit les dates manquent, soit les sprints ont été sélectionnés pour une autre équipe.

## Étape 4 : importer et planifier le backlog

**Import.** Boards > **Queries** > **Import work items** > **Choose file** > `backlog-rdv.csv` > **Import**, puis **Save items**.

Les colonnes `Title 1`, `Title 2` et `Title 3` portent la hiérarchie : une ligne avec `Title 1` est un epic, avec `Title 2` une feature enfant de l'epic au-dessus, avec `Title 3` une user story enfant de la feature au-dessus. Vous obtenez 17 éléments, reliés parent-enfant et tous à l'état New :

| Type | Nombre |
|---|---|
| Epic | 1 |
| Feature | 4 |
| User Story | 12 |

**Zone.** L'import place tous les éléments à la racine `RDV` : ils n'appartiennent donc à aucune équipe, et le backlog de `RDV - Dev` paraît vide. Dans la liste des éléments importés, sélectionnez les 17 lignes > clic droit > **Edit** > **Area Path** = `RDV\RDV - Dev` > **Save**.

**Story d'exploitation.** Boards > Work items > **New Work Item** > User Story : `Surveiller la sonde /sante en production`, **Area Path** = `RDV\Exploitation`.

**Ordre et sprint.** Boards > **Backlogs**, équipe `RDV - Dev`, niveau **Stories** :

1. glissez « Réserver un créneau le samedi matin » en tête, puis « Annuler un rendez-vous jusqu'à 24 h avant », puis « Consulter les créneaux libres d'un praticien » ;
2. options d'affichage > **Planning** : le volet des sprints s'ouvre à droite ;
3. glissez les trois stories sur `Sprint 1`.

Pour vérifier la hiérarchie d'un coup d'œil, une requête de type **Tree of work items** :

```text
Éléments de premier niveau : Work Item Type = Epic
Éléments liés : Work Item Type In Feature, User Story
Résultat : 1 epic, 4 features, 12 user stories
```

La story « Surveiller la sonde /sante en production » n'apparaît pas dans le backlog de `RDV - Dev` : elle est dans la zone `RDV\Exploitation`, qui n'appartient pas à l'équipe. C'est le comportement attendu.

Si l'import échoue, regardez d'abord si le fichier a été ouvert et réenregistré dans Excel. En français, Excel remplace les virgules par des points-virgules et peut changer l'encodage. Reprenez le fichier d'origine et éditez-le dans VS Code.

## Étape 5 : régler le tableau Kanban

Boards > **Boards**, équipe `RDV - Dev`, niveau Stories > engrenage > **Columns**.

Le tableau Agile part avec quatre colonnes : New, Active, Resolved, Closed. Pour arriver au résultat demandé :

1. renommez **Active** en `Développement`, limite 4, cochez la scission **Doing / Done**, définition de fini « tests xUnit verts, pull request approuvée » ;
2. ajoutez avant elle une colonne `Analyse`, état **Active**, limite 3 ;
3. renommez **Resolved** en `Recette`, limite 3, définition de fini « validée par Léa sur rdv-recette ».

| Colonne | État | Limite | Réglages |
|---|---|---|---|
| New | New | — | — |
| Analyse | Active | 3 | — |
| Développement | Active | 4 | Doing / Done, définition de fini |
| Recette | Resolved | 3 | définition de fini |
| Closed | Closed | — | — |

Deux colonnes peuvent porter le même état : Analyse et Développement sont toutes deux en Active. La colonne raconte où en est le travail pour l'équipe ; l'état, lui, est ce que lisent les requêtes et les graphiques.

Une limite de travail en cours ne bloque rien : au-delà, le compteur en tête de colonne passe en rouge. C'est un signal pour l'équipe, pas un verrou.

**Cartes.** Section Cards > **Fields** : cochez **Tags** et **Priority** pour les user stories. **Styles** > nouvelle règle, critère `Priority = 1`, couleur au choix.

En déplaçant « Réserver un créneau le samedi matin » dans **Analyse**, vous la passez à l'état **Active**. Gardez-le en tête pour l'étape 7.

## Étape 6 : droits d'accès, en binôme

1. Organization settings > **Users** > **Add users** : l'adresse du voisin, **Stakeholder**, projet `RDV`, groupe **Project Contributors**.
2. Project settings > **Teams** > `RDV - Dev` > **Add** : le voisin.
3. Project configuration > **Areas** > menu de `Exploitation` > **Security** > ajoutez le voisin > **Edit work items in this node** = **Deny**. Ne touchez pas à **View work items in this node**.

Ce que votre voisin doit constater, et pourquoi :

| Action | Résultat | Cause |
|---|---|---|
| Modifier une story de `RDV - Dev` | enregistré | un Stakeholder peut modifier des éléments de travail, et Contributors donne Allow sur la zone |
| Ouvrir la story d'Exploitation | visible | View work items in this node est hérité en Allow |
| Modifier la story d'Exploitation | refusé | le Deny explicite posé sur la zone l'emporte sur l'Allow hérité de Contributors |
| Réordonner le backlog | impossible | niveau d'accès Stakeholder |
| Ouvrir Repos | aucun accès | niveau d'accès Stakeholder dans un projet privé |

C'est le point le plus important du TP. Deux verrous se superposent :

- le **niveau d'accès** (Stakeholder, Basic, Basic + Test Plans) dit à quels services la personne a droit. C'est une question de licence ;
- les **permissions** (groupes, Allow, Deny, Not set) disent ce qu'elle peut faire sur chaque objet.

Une permission ne débloque jamais un service que le niveau d'accès ferme. Mettre Hugo dans Contributors ne lui ouvre pas Repos : il lui faut Basic.

Si le résultat diffère :

- **le voisin peut modifier la story d'Exploitation** : le Deny est posé sur une autre zone, ou la story n'est pas dans `RDV\Exploitation` ;
- **le voisin ne peut rien modifier du tout** : il a été ajouté sans groupe, il n'a donc que Project Valid Users. Ajoutez-le à Project Contributors.

Pour l'invitation : si le voisin ne reçoit pas le courriel ou se connecte avec un autre compte, envoyez-lui directement l'URL du projet et faites-le ouvrir une fenêtre de navigation privée avec l'adresse invitée.

## Étape 7 : tableau de bord de l'équipe

**Requête.** Boards > **Queries** > **New query** :

| Champ | Opérateur | Valeur |
|---|---|---|
| Work Item Type | = | User Story |
| Priority | = | 1 |
| State | <> | Closed |

**Save query** > dossier **Shared Queries** > `Stories P1 ouvertes`. Shared, et pas My Queries : un widget de tableau de bord affiche ce que toute l'équipe peut voir. En WIQL, la même requête :

```sql
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'User Story'
  AND [Microsoft.VSTS.Common.Priority] = 1
  AND [System.State] <> 'Closed'
ORDER BY [Microsoft.VSTS.Common.StackRank]
```

Elle renvoie quatre stories :

- Consulter les créneaux libres d'un praticien ;
- Réserver un créneau le samedi matin ;
- Refuser un créneau déjà réservé ou passé ;
- Annuler un rendez-vous jusqu'à 24 h avant.

**Tableau de bord.** Overview > **Dashboards**, équipe `RDV - Dev` > **Edit** :

| Widget | Réglage |
|---|---|
| Query Results | requête `Stories P1 ouvertes` |
| Chart for Work Items | même requête, **Pie**, regroupé par **State** |
| Sprint Overview ou Sprint Burndown | sprint en cours de `RDV - Dev` |
| Markdown | la définition de fini de l'équipe |

Le camembert a deux parts : trois stories New et une Active, « Réserver un créneau le samedi matin », que vous avez placée dans Analyse à l'étape 5. Si vous ne voyez qu'une part, cette story n'a pas changé de colonne.

Le burndown est encore plat, et c'est normal : rien n'a été fermé et aucune tâche n'est estimée. Il prendra vie quand l'équipe découpera ses stories en tâches et renseignera leur reste à faire.

## Bonus : le processus hérité `Agile-Santinord`

1. Organization settings > Boards > **Process** > menu « … » d'**Agile** > **Create inherited process** > `Agile-Santinord`.
2. `Agile-Santinord` > **User Story** > **States** > **New state** : `En attente de validation`, catégorie **Resolved**.
3. Retour au processus **Agile** > onglet **Projects** > menu de `RDV` > **Change process** > `Agile-Santinord`.
4. Tableau de `RDV - Dev` > engrenage > **Columns** : ajoutez la colonne `Validation centre` entre Recette et Closed, reliée à l'état `En attente de validation` > **Save**.

On ne modifie jamais un processus système : Agile, Scrum, CMMI et Basic sont en lecture seule. On en hérite, et on personnalise l'héritier. Comme `Agile-Santinord` hérite d'Agile, le changement de processus ne demande aucune reprise : les types, les états et les champs existants sont les mêmes.

Pourquoi une nouvelle colonne, et pas Recette ? Une colonne ne porte qu'un état par type d'élément, et Recette porte déjà Resolved. L'inverse est possible, on l'a vu à l'étape 5 : plusieurs colonnes pour un même état.

## À retenir

- Le projet porte le processus et le contrôle de version ; l'équipe porte le backlog, le tableau et les sprints ; la zone fait le lien entre les deux.
- Une itération n'existe pour une équipe que si l'équipe l'a sélectionnée.
- Un import CSV pose tout à la racine : pensez à la modification en masse.
- Niveau d'accès et permissions sont deux verrous indépendants. Quand quelqu'un « ne voit pas » un service, regardez d'abord son niveau d'accès.
- Le projet `RDV` sert toute la semaine : gardez-le.
