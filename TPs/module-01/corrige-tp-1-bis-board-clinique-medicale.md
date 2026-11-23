# Corrigé du TP 1 bis : piloter un projet dans Azure Boards, la clinique médicale

> Module 1 : Intégration continue et Azure DevOps
> À lire après le TP, énoncé à côté.

Ce corrigé suit les sections de l'énoncé, de A à M. Pour chacune : où cliquer, ce que vous devez obtenir, et les pièges que je vois le plus souvent. Partout, `<Prénom>` est votre prénom.

## A : le projet

Page d'accueil de l'organisation > **New project** :

- nom `Clinique-<Prénom>` ;
- description : « Permettre aux patients de prendre et de gérer leurs rendez-vous médicaux en ligne. » ;
- **Private** ;
- **Advanced** : **Git**, **Agile**.

Project settings > Overview affiche le processus Agile. Le prénom dans le nom n'est pas décoratif : si plusieurs stagiaires partagent une organisation, deux projets ne peuvent pas porter le même nom.

## B et C : l'équipe et les sprints

L'équipe se construit à la section E. Ici, on ne fait que les sprints.

**Itérations du projet.** Project settings > Boards > Project configuration > **Iterations**. Le projet a été créé avec `Iteration 1` à `Iteration 3`, sans dates. Renommez-les plutôt que d'en créer de nouvelles :

| Itération | Nouveau nom | Début | Fin |
|---|---|---|---|
| Iteration 1 | Sprint 1 | lundi 23/11/2026 | vendredi 04/12/2026 |
| Iteration 2 | Sprint 2 | lundi 07/12/2026 | vendredi 18/12/2026 |
| Iteration 3 | Sprint 3 | lundi 21/12/2026 | vendredi 01/01/2027 |

**Itérations de l'équipe.** Project settings > **Team configuration**. L'équipe affichée dans le fil d'Ariane est `Clinique-<Prénom> Team`. Onglet **Iterations** : vérifiez que les trois sprints y figurent. S'il en manque un, **Select iteration(s)**.

**Niveau Epics.** Même page, onglet **General** > **Backlogs** : cochez **Epics**. Sans ça, la section H commence mal : pas de niveau Epics dans le backlog.

Boards > **Sprints** affiche `Sprint 1` en **Current**, du 23/11 au 04/12/2026.

Pourquoi trois sprints et pas six ? Parce qu'on ne sait pas à quoi ressemblera le sprint 6 dans deux mois. On planifie l'horizon qu'on voit, et on ajoute un sprint à chaque revue.

## D : la présentation du projet

**Wiki.** Overview > **Wiki** > **Create project wiki**. Une page d'accueil possible :

```markdown
# Clinique : prise de rendez-vous en ligne

## Contexte

| | |
|---|---|
| Début | lundi 23 novembre 2026 |
| Fin prévue | vendredi 19 février 2027 |
| Objectif | permettre aux patients de prendre et de gérer leurs rendez-vous médicaux en ligne |

## Équipe

| Membre | Rôle |
|---|---|
| <Prénom> | Développeur, administrateur du projet |
| Jim | Développeur FullStack |
| John | Testeur QA |

## Sprints

| Sprint | Du | Au | Objectif |
|---|---|---|---|
| Sprint 1 | 23/11/2026 | 04/12/2026 | prise de rendez-vous en ligne |
| Sprint 2 | 07/12/2026 | 18/12/2026 | rappels par courriel |
| Sprint 3 | 21/12/2026 | 01/01/2027 | tests de la gestion des rendez-vous |
```

**Summary.** Overview > **Summary** > icône de modification de la description : la phrase de la section A, et **Wiki** comme contenu de « About this project ». Summary affiche alors la description, puis la page d'accueil du wiki.

L'autre choix possible est le README d'un dépôt. Pour un projet qui a du code, le README est souvent le meilleur choix ; ici, le projet n'a que du travail planifié, le wiki convient mieux.

## E : membres et permissions

1. Organization settings > **Users** > **Add users** :
   - Jim : son adresse Gmail ;
   - John : l'adresse de votre voisin ;
   - **Basic** (Stakeholder si vos cinq Basic gratuits sont déjà pris) ;
   - projet `Clinique-<Prénom>` ;
   - groupe **Project Contributors**.
2. Project settings > **Teams** > `Clinique-<Prénom> Team` > **Add** : Jim et John.

L'équipe compte trois membres. Ajouter quelqu'un à l'organisation ne l'ajoute pas à l'équipe : sans la deuxième étape, Jim n'apparaîtra pas dans la capacité du sprint.

Si votre organisation est rattachée à un tenant Microsoft Entra ID, l'adresse Gmail de Jim devient un compte invité. Si la politique **External guest access** est désactivée, l'invitation est refusée : assignez les tâches de Jim à votre voisin et continuez, ce n'est pas bloquant pour la suite.

Stakeholder ou Basic, pour ce TP, ça ne change presque rien : un Stakeholder peut créer, modifier et commenter des éléments de travail. Il ne pourrait pas réordonner le backlog ni ouvrir Repos, mais le TP ne lui demande ni l'un ni l'autre.

## F : le nouveau processus

1. Organization settings > Boards > **Process** > menu « … » d'**Agile** > **Create inherited process** > `AgileCustom<Prénom>`.
2. Processus **Agile** > onglet **Projects** > menu « … » de `Clinique-<Prénom>` > **Change process** > `AgileCustom<Prénom>`.

Project settings > Overview affiche maintenant `AgileCustom<Prénom>`, et rien d'autre n'a bougé. C'est normal : un processus hérité d'Agile a exactement les mêmes types, états et champs qu'Agile tant qu'on ne l'a pas personnalisé. Passer d'Agile à Scrum, en revanche, demanderait de reprendre les types et les états des éléments existants.

Le processus est un objet de l'organisation, pas du projet. Tout ce que vous ferez en G s'applique à tous les projets qui utilisent `AgileCustom<Prénom>`.

## G : personnaliser le processus

### G.1 : un nouvel état et sa colonne

1. `AgileCustom<Prénom>` > **User Story** > **States** > **New state** : `En attente de validation`, catégorie **Resolved**.
2. Dans le projet : Boards > **Boards**, niveau Stories > engrenage > **Columns** > ajoutez `Attente client` entre Resolved et Closed, état `En attente de validation` > **Save**.

La deuxième étape est indispensable. Une colonne ne porte qu'un état par type d'élément : le processus crée l'état, mais c'est chaque équipe qui décide dans quelle colonne de son tableau il apparaît.

### G.2 : 5 Story Points par défaut

`AgileCustom<Prénom>` > **User Story** > champ **Story Points** > **Edit** > **Options** > **Default value** = `5` > **Save**.

Une valeur par défaut ne s'applique qu'aux éléments créés après elle. Si vous avez créé vos stories avant, elles n'ont pas de points : saisissez 5 à la main sur celles-ci.

### G.3 : le type Documentation

**Le type.** **New work item type** > `Documentation`, une icône et une couleur au choix.

**Les états.** Un nouveau type naît avec New, Active et Closed. Le résultat attendu :

| État | Catégorie |
|---|---|
| Nouveau | Proposed |
| En cours | In Progress |
| En révision | Resolved |
| Complété | Completed |

Ajoutez les quatre états, puis supprimez New et Active. Closed disparaît de lui-même : la catégorie Completed n'accepte qu'un état, et `Complété` y prend sa place.

**Les champs.**

| Champ | Comment | Options |
|---|---|---|
| Titre, Responsable, État | Title, Assigned To, State : déjà sur le formulaire | — |
| Priorité | **New field** > **Use an existing field** > **Priority** | — |
| Date d'échéance | **New field** > nom `Date d'échéance`, type **Date/Time** | **Required** |
| Type de documentation | **New field** > nom `Type de documentation`, type **Picklist (string)**, valeurs : Manuel d'utilisation, Guide de démarrage rapide, Documentation API | **Required**, **Default value** = Manuel d'utilisation |
| Commentaires | la zone **Discussion** du formulaire | — |

Priorité réutilise un champ existant au lieu d'en créer un : ainsi, une même requête « Priority = 1 » trouve aussi bien les stories que la documentation. Retenez le réflexe : avant de créer un champ, cherchez s'il existe déjà.

Si `Date d'échéance` existe déjà dans votre organisation, un autre stagiaire l'a créé : les champs sont communs à toute l'organisation. Prenez **Use an existing field**.

**Le backlog.** `AgileCustom<Prénom>` > **Backlog levels** > **Stories** > **Edit** > cochez **Documentation**. Sans ça, un élément Documentation n'apparaît ni dans le backlog ni sur le tableau : il n'existe que dans les requêtes et dans Boards > Work items.

**Vérification.** Boards > Work items > **New Work Item** > Documentation. Le type vaut Manuel d'utilisation dès l'ouverture ; sans date d'échéance, **Save** est refusé et le champ est signalé en rouge.

## H : epic, feature, user stories et tâches

### La hiérarchie

| Niveau | Élément | Où le créer |
|---|---|---|
| Epic | Rendez-vous en ligne de la clinique | Backlogs, niveau Epics, **New Work Item** |
| Feature | Gestion des rendez-vous | **+** de la ligne de l'epic |
| User Story #1 | Prendre rendez-vous en ligne | **+** de la ligne de la feature, au niveau Features |
| User Story #2 | Recevoir des rappels par courriel | idem |
| User Story #3 | Tester la gestion des rendez-vous | idem |

Le texte « En tant que… je veux… afin de… » va dans la **Description** de chaque story. Pour le titre, une forme courte suffit.

**Les sprints des stories.** Niveau **Stories** > options d'affichage > **Planning** > glissez la #1 sur `Sprint 1`, la #2 sur `Sprint 2`, la #3 sur `Sprint 3`.

**Les tâches.** Boards > **Sprints** > `Sprint 1` > onglet **Backlog** > **+** de la User Story #1 > **Task**, et ainsi de suite pour chaque sprint. Une tâche créée ici est déjà dans le bon sprint et dans la bonne zone.

| Story | Tâche | Assignée à | Priorité |
|---|---|---|---|
| #1 | Créer la maquette de l'interface utilisateur pour la prise de rendez-vous | Vous | 1 |
| #1 | Développer l'interface utilisateur selon la maquette approuvée | Jim | 1 |
| #1 | Intégrer l'API de calendrier pour afficher les disponibilités des médecins | Jim | 2 |
| #2 | Concevoir le modèle de courriel de rappel de rendez-vous | Vous | 3 |
| #2 | Développer l'envoi des courriels de rappel 24 h avant le rendez-vous | Jim | 2 |
| #3 | Préparer et exécuter des tests fonctionnels pour la prise de rendez-vous | John | 2 |
| #3 | Mettre en place des tests automatisés de la fonctionnalité de rappels par courriel | John | 3 |

### L'élément Documentation

Backlog, niveau Stories > **New Work Item** > Documentation, ou Boards > Work items :

- titre : `Guide de démarrage rapide de la prise de rendez-vous` ;
- type : Guide de démarrage rapide ;
- date d'échéance : 18/12/2026 ;
- assigné à vous.

### Ce que vous devez voir

- Au niveau Epics : l'epic, puis une feature, trois stories et sept tâches.
- Chaque story porte 5 Story Points sans que vous les ayez saisis.
- `Sprint 1` montre la User Story #1 et ses trois tâches.

Si une story n'a pas ses 5 points, elle a été créée avant la section G.2.

## I : priorités et étiquettes

**Priorités des stories.** User Story #1 : Priority = 1. User Story #2 : Priority = 2. L'énoncé n'impose rien pour la #3.

**Étiquettes des tâches.**

| Tâche | Étiquette |
|---|---|
| Créer la maquette de l'interface | Interface |
| Développer l'interface selon la maquette | Interface |
| Intégrer l'API de calendrier | Backend |
| Concevoir le modèle de courriel de rappel | Interface |
| Développer l'envoi des courriels de rappel | Backend |
| Tests fonctionnels de la prise de rendez-vous | Test |
| Tests automatisés des rappels | Test |

J'ai classé le modèle de courriel en Interface : c'est ce que le patient voit. Si vous l'avez mis en Backend parce que c'est le serveur qui l'envoie, l'argument se tient. Votre requête `Clinique - Interface` renverra alors deux tâches au lieu de trois.

Le plus rapide pour étiqueter : sélectionnez plusieurs tâches dans une requête ou dans le backlog du sprint > clic droit > **Edit** > **Tags (Add)**.

Une étiquette n'a pas besoin d'être déclarée avant : tapez-la dans le champ Tags, elle est créée au premier enregistrement. C'est pratique, et c'est aussi le piège : `Interface`, `interface` et `IHM` deviennent vite trois étiquettes pour la même chose. Une équipe se met d'accord sur sa liste et s'y tient.

## J : le cycle de vie

**La tâche « Créer la maquette… ».**

| Transition | Reason inscrite automatiquement |
|---|---|
| New → Active | Work started |
| Active → Closed | Completed |

À la fermeture, le reste à faire (Remaining Work) est vidé : une tâche fermée ne pèse plus dans le burndown. Les champs Closed By et Closed Date se remplissent tout seuls.

**La User Story #1.**

| Transition | Reason |
|---|---|
| New → Active | Implementation started |
| Active → Resolved | Code complete and unit tests pass |
| Resolved → En attente de validation | une raison générique, du type « Moved to state… » : vous n'en avez pas défini pour cet état |

Sur le tableau, la carte suit : Active, Resolved, puis `Attente client`. Vous pouvez aussi faire l'inverse : glisser la carte de colonne en colonne, et l'état change avec elle.

**L'élément Documentation.** Nouveau → En cours → En révision.

**L'historique.** Onglet **History** de la User Story #1 : chaque changement d'état, avec sa date, son auteur et sa raison. C'est ce qui sert en rétrospective, quand on cherche pourquoi une story est restée dix jours en Resolved.

Par défaut, Azure Boards laisse passer d'un état à n'importe quel autre, y compris de New directement à Closed. Si vous voulez l'empêcher, c'est une règle du processus : voir « Pour aller plus loin ».

## K : les requêtes

Boards > **Queries** > **New query**, puis **Save query** > **Shared Queries**.

**`Clinique - Interface`**

| Champ | Opérateur | Valeur |
|---|---|---|
| Tags | Contains | Interface |

**`Clinique - Tâches P3`**

| Champ | Opérateur | Valeur |
|---|---|---|
| Work Item Type | = | Task |
| Priority | = | 3 |

En WIQL, si vous préférez lire la requête plutôt que l'éditeur :

```sql
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.Tags] CONTAINS 'Interface'

SELECT [System.Id], [System.Title], [System.AssignedTo]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'Task'
  AND [Microsoft.VSTS.Common.Priority] = 3
```

Résultats attendus :

- `Clinique - Interface` : trois tâches (maquette, développement de l'interface, modèle de courriel), ou deux si le modèle de courriel est en Backend ;
- `Clinique - Tâches P3` : deux tâches (modèle de courriel, tests automatisés des rappels).

## L : capacité et planning

### Capacité

Boards > **Sprints** > `Sprint 1` > **Capacity** > menu d'actions > **Add all team members**.

| Membre | Activité | Capacité par jour | Congé, Sprint 1 |
|---|---|---|---|
| Vous | Development | 6 | vendredi 27/11/2026 |
| Jim | Development | 6 | mercredi 02/12/2026 |
| John | Testing | 6 | lundi 30/11/2026 |

30 heures par semaine sur 5 jours ouvrés, ça fait 6 heures par jour.

Pour les Sprints 2 et 3, un jour au choix par membre. Par exemple :

| Membre | Sprint 2 | Sprint 3 |
|---|---|---|
| Vous | vendredi 11/12/2026 | mardi 22/12/2026 |
| Jim | lundi 14/12/2026 | lundi 28/12/2026 |
| John | mercredi 16/12/2026 | mercredi 30/12/2026 |

Dans le Sprint 3, le 25/12/2026 et le 01/01/2027 vont dans **Team days off**, pas dans les congés de chacun : ils concernent toute l'équipe. Et ne choisissez pas l'un de ces deux jours comme congé personnel, il ne serait pas décompté deux fois.

### Les chiffres

| Sprint | Jours ouvrés | Fériés | Congé | Jours travaillés par membre | Par membre | Équipe |
|---|---|---|---|---|---|---|
| Sprint 1 | 10 | 0 | 1 | 9 | 54 h | 162 h |
| Sprint 2 | 10 | 0 | 1 | 9 | 54 h | 162 h |
| Sprint 3 | 10 | 2 | 1 | 7 | 42 h | 126 h |

Attention au Sprint 1 : le volet **Work details** compte la capacité **restante**, à partir d'aujourd'hui. Le lundi 23 novembre, il affiche 162 heures. Le mardi 24, il en affichera 144 : un jour de moins pour chacun des trois membres. Les Sprints 2 et 3 n'ont pas commencé, leurs chiffres ne bougent pas.

La capacité ne sert à quelque chose que comparée au reste à faire. Renseignez le Remaining Work de vos tâches : Work details montre alors, par personne et par activité, si le sprint tient dans le temps disponible.

### Le planning des cérémonies

Azure Boards n'a pas d'agenda de cérémonies. Le plan de livraison et ses marqueurs en tiennent lieu.

1. Boards > **Delivery Plans** > **New Plan** : `Planning Clinique`, équipe `Clinique-<Prénom> Team`, niveau **Stories** > **Create**.
2. **Settings** > **Markers** :

| Marqueur | Date |
|---|---|
| Revue et rétro S1 | vendredi 04/12/2026 |
| Revue et rétro S2 | vendredi 18/12/2026 |
| Revue et rétro S3 | jeudi 31/12/2026 |

Le 31 décembre et pas le 1er janvier : le 1er est férié, la revue a lieu le dernier jour ouvré.

Le plan montre les trois sprints, chaque story dans son sprint, et les trois marqueurs. Si aucune story n'apparaît, elles n'ont pas d'itération, ou le plan n'est pas réglé sur le niveau Stories.

## M : la mention

Tâche « Développer l'interface utilisateur selon la maquette approuvée » > zone **Discussion** :

> @Jim attention, la maquette risque encore de bouger après la revue avec le client. Attends sa validation avant d'attaquer les écrans.

Tapez `@`, puis les premières lettres du nom, et choisissez Jim dans la liste. La mention devient un lien et Jim reçoit un courriel. Si vous ne passez pas par la liste, `@Jim` reste du texte et personne n'est prévenu ; même chose pour une mention copiée depuis un ancien commentaire.

On peut aussi mentionner une équipe entière : `@Clinique-<Prénom> Team` prévient chacun de ses membres. Et `#` suivi d'un numéro crée un lien vers un autre élément de travail.

## Pour aller plus loin

**Interdire New → Closed.** `AgileCustom<Prénom>` > **User Story** > **Rules** > **New rule** :

- condition : *When a work item state is* `New` ;
- action : *Restrict the transition to state* `Closed`.

Une story ne pourra plus passer de New à Closed d'un seul coup.

**Tableau de bord.** Overview > **Dashboards** > tableau de l'équipe > **Edit** :

- Query Results sur `Clinique - Interface` ;
- Sprint Burndown sur le Sprint 1 ;
- un widget Markdown avec la définition de fini.

## À retenir

- Le processus appartient à l'organisation ; le projet ne fait que l'utiliser. On hérite d'un processus système, on ne le modifie pas.
- Un nouvel état ne suffit pas : il lui faut sa colonne sur le tableau de chaque équipe.
- Une valeur par défaut ne vaut que pour les éléments créés après elle.
- Créer depuis la bonne vue fait gagner du temps : le **+** d'une ligne crée l'enfant, une tâche créée dans un sprint est déjà dans ce sprint.
- La capacité se lit en heures restantes, à partir d'aujourd'hui.

## Nettoyage, en fin de formation

Project settings > Overview > **Delete** pour le projet `Clinique-<Prénom>`, puis Organization settings > Boards > Process > `AgileCustom<Prénom>` > **Delete**. Dans cet ordre : un processus ne se supprime que si plus aucun projet ne l'utilise.
