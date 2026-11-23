# TP 1 bis — Piloter un projet dans Azure Boards : la clinique médicale

> Module : 1 — Intégration continue et Azure DevOps
> Programme ORSYS : « Créer et configurer un nouveau projet » ; gestion de projet avec Azure DevOps
> Durée : environ 1 h 30
> Modalité : individuelle ; votre voisin joue John (section E)
> Après : démo 1.1 (projet, sprints, import) et démo 1.2 (processus hérité, création, cycle de vie, capacité)

## Mise en situation

Une clinique médicale veut permettre à ses patients de prendre et de gérer leurs rendez-vous en ligne. C'est le même métier que le projet RDV de Santinord vu en démonstration ; cette fois, vous le montez seul, de bout en bout, dans Azure Boards : projet, équipe, processus personnalisé, éléments de travail, cycle de vie, requêtes, capacité et planning.

## A — Contexte du projet

| | |
|---|---|
| **Nom du projet** | `Clinique-<Prénom>` (votre prénom : plusieurs stagiaires peuvent partager une organisation) |
| **Début du projet** | lundi 23 novembre 2026 |
| **Durée prévue** | trois mois, jusqu'au vendredi 19 février 2027 |
| **Objectif** | permettre aux patients de prendre et de gérer leurs rendez-vous médicaux en ligne |

À faire : depuis la page d'accueil de votre organisation, **New project** : nom `Clinique-<Prénom>`, description reprenant l'objectif, visibilité **Private** ; **Advanced** : **Git**, processus **Agile**.

**Point de contrôle A** — Project settings > Overview affiche le processus Agile.

## B — Équipe de projet

| Membre | Rôle | Note |
|---|---|---|
| Vous | Développeur | administrateur du projet |
| Jim | Développeur FullStack | personne à créer : une adresse Gmail |
| John | Testeur QA | votre voisin |

Les membres sont ajoutés à la section E.

## C — Planification des sprints

Sprints de **deux semaines**, du lundi au vendredi de la semaine suivante. On ne crée pas les six sprints des trois mois : on planifie les trois premiers, les suivants seront créés au fil du projet.

| Sprint | Dates | Objectif |
|---|---|---|
| **Sprint 1** | du lundi 23 novembre au vendredi 4 décembre 2026 | User Story #1 |
| **Sprint 2** | du lundi 7 décembre au vendredi 18 décembre 2026 | User Story #2 |
| **Sprint 3** | du lundi 21 décembre 2026 au vendredi 1er janvier 2027 | User Story #3 |

À faire :

1. Project settings > Boards > **Project configuration** > onglet **Iterations** : le projet contient déjà `Iteration 1` à `Iteration 3`, sans dates. Renommez-les `Sprint 1` à `Sprint 3` et donnez-leur les dates du tableau.
2. Project settings > **Team configuration** : l'équipe affichée est `Clinique-<Prénom> Team` (le sélecteur d'équipe est dans le fil d'Ariane, tout en haut de la page). Onglet **Iterations** : vérifiez que les trois sprints sont sélectionnés, sinon ajoutez-les avec **Select iteration(s)**.
3. Même page, onglet **General** > **Backlogs** : cochez **Epics** (décoché par défaut).

**Point de contrôle C** — Boards > **Sprints** affiche `Sprint 1` comme sprint en cours (**Current**), du 23/11 au 04/12/2026.

## D — Présentation du projet (Overview)

Rendez le projet lisible pour quelqu'un qui arrive : contexte, équipe, sprints.

1. Overview > **Wiki** > **Create project wiki**. Page d'accueil `Accueil` : le contexte (section A), l'équipe (section B) et le planning des sprints (section C), en tableaux Markdown. **Save**.
2. Overview > **Summary** > **Add Project Description** (ou l'icône de modification) : une description d'une phrase, et **Wiki** comme page « About this project ».

**Point de contrôle D** — Overview > Summary affiche la description et le contenu de la page d'accueil du wiki.

## E — Membres et permissions

1. Organization settings > **Users** > **Add users** :
   - Jim : son adresse Gmail ; John : l'adresse de votre voisin ;
   - **Access level** : Basic (les cinq premiers Basic d'une organisation sont gratuits ; s'il n'en reste plus, Stakeholder suffit pour ce TP) ;
   - **Add to projects** : `Clinique-<Prénom>` ; **Azure DevOps Groups** : Project Contributors.
2. Project settings > **Teams** > `Clinique-<Prénom> Team` > **Add** : Jim et John.

**Point de contrôle E** — L'équipe compte trois membres : vous, Jim et John. Votre voisin voit le projet depuis son navigateur.

## F — Nouveau processus

Créez un processus hérité du processus **Agile**, nommé `AgileCustom<Prénom>`, puis basculez-y le projet.

1. Organization settings > Boards > **Process** > menu « … » d'**Agile** > **Create inherited process** > `AgileCustom<Prénom>`.
2. Revenez au processus **Agile** > onglet **Projects** > menu « … » de `Clinique-<Prénom>` > **Change process** > `AgileCustom<Prénom>`.

**Point de contrôle F** — Project settings > Overview affiche le processus `AgileCustom<Prénom>`. Rien n'a changé dans le projet : un processus hérité du même processus de base ne demande aucune reprise.

## G — Personnaliser le processus

Toutes ces modifications se font dans Organization settings > Boards > **Process** > `AgileCustom<Prénom>`.

### G.1 — Un nouvel état et sa colonne

Les user stories qui attendent un retour du client doivent se distinguer.

1. Type **User Story** > **States** > **New state** : `En attente de validation`, catégorie **Resolved**.
2. Dans le projet : Boards > **Boards**, niveau Stories > engrenage > **Columns** : ajoutez la colonne `Attente client` entre Resolved et Closed, reliée à l'état `En attente de validation`. **Save**.

### G.2 — Story Points par défaut

Chaque nouvelle user story reçoit automatiquement **5 Story Points**.

Type **User Story** > page du formulaire > champ **Story Points** > **Edit** > onglet **Options** > **Default value** : `5`.

Faites-le **avant** la section H : la valeur par défaut s'applique aux éléments créés ensuite.

### G.3 — Un nouveau type d'élément : Documentation

**Objectif** : suivre la création, la révision et la mise à jour de la documentation technique du produit : manuels d'utilisation, guides de démarrage rapide, documentation de l'API.

1. **Work item types** > **New work item type** : `Documentation`.
2. Onglet **States** : un nouveau type naît avec New, Active et Closed. Ajoutez `Nouveau` (Proposed), `En cours` (In Progress), `En révision` (Resolved) et `Complété` (Completed), puis supprimez New et Active. La catégorie Completed n'accepte qu'un état : `Complété` y remplace Closed.
3. Champs du formulaire :

| Champ | Description | Comment l'obtenir | Contraintes |
|---|---|---|---|
| **Titre** | le sujet de la documentation | champ Title, déjà présent | — |
| **Responsable** | la personne assignée à la création ou à la mise à jour | champ Assigned To, déjà présent | — |
| **État** | Nouveau, En cours, En révision, Complété | le cycle de vie de l'étape 2 | — |
| **Priorité** | l'importance ou l'urgence | **New field** > **Use an existing field** > Priority | — |
| **Date d'échéance** | la date limite | **New field**, type **Date/Time** | **Required** (onglet Options) |
| **Type de documentation** | Manuel d'utilisation, Guide de démarrage rapide, Documentation API | **New field**, type **Picklist (string)** | **Required**, **Default value** : Manuel d'utilisation |
| **Commentaires** | remarques ou instructions | la zone Discussion du formulaire, déjà présente | — |

4. Pour voir les éléments Documentation dans le backlog et sur le tableau : processus > **Backlog levels** > niveau des stories (**Stories**) > **Edit** > cochez **Documentation**.

**Point de contrôle G** — Boards > Work items > **New Work Item** propose Documentation. Un élément Documentation sans date d'échéance ne s'enregistre pas ; son type vaut Manuel d'utilisation à la création.

## H — Epic, feature, user stories et tâches

### H.1 — La hiérarchie

Boards > **Backlogs**, niveau **Epics** > **New Work Item** : l'epic `Rendez-vous en ligne de la clinique`. Avec le **+** de sa ligne, ajoutez la feature `Gestion des rendez-vous`. Les trois user stories sont des enfants de cette feature.

### H.2 — User Story #1 (Sprint 1)

> « En tant que patient, je veux pouvoir prendre rendez-vous en ligne afin de ne pas avoir à appeler la clinique. »

| Tâche | Assignée à | Priorité |
|---|---|---|
| Créer la maquette de l'interface utilisateur pour la prise de rendez-vous | Vous | 1 |
| Développer l'interface utilisateur selon la maquette approuvée | Jim | 1 |
| Intégrer l'API de calendrier pour afficher les disponibilités des médecins | Jim | 2 |

### H.3 — User Story #2 (Sprint 2)

> « En tant que patient, je veux recevoir des rappels par courriel de mon rendez-vous pour éviter de l'oublier. »

| Tâche | Assignée à | Priorité |
|---|---|---|
| Concevoir le modèle de courriel de rappel de rendez-vous | Vous | 3 |
| Développer l'envoi des courriels de rappel 24 h avant le rendez-vous | Jim | 2 |

### H.4 — User Story #3 (Sprint 3)

> « En tant qu'équipe de développement, nous voulons tester minutieusement la fonctionnalité "Gestion des rendez-vous" pour assurer une expérience utilisateur fiable et intuitive. »

| Tâche | Assignée à | Priorité |
|---|---|---|
| Préparer et exécuter des tests fonctionnels pour la prise de rendez-vous | John | 2 |
| Mettre en place des tests automatisés de la fonctionnalité de rappels par courriel | John | 3 |

Où et dans quel ordre :

1. Au niveau **Features** du backlog, le **+** de la feature crée une user story enfant.
2. Au niveau **Stories**, ouvrez le volet de planification et glissez chaque story dans son sprint.
3. Boards > **Sprints** > le sprint de la story > onglet **Backlog** : le **+** de la story crée une tâche, déjà placée dans le bon sprint.

### H.5 — Un élément Documentation

Créez `Guide de démarrage rapide de la prise de rendez-vous` : type **Guide de démarrage rapide**, date d'échéance **vendredi 18 décembre 2026**, assigné à vous.

**Point de contrôle H** — Au niveau Epics, l'epic se déplie en une feature, trois user stories et sept tâches. Chaque story affiche 5 Story Points sans que vous les ayez saisis. Boards > **Sprints** > `Sprint 1` montre la User Story #1 et ses trois tâches.

## I — Priorités et étiquettes

### Priorité métier des user stories

| User Story | Priorité |
|---|---|
| User Story #1 | **Haute** (Priority = 1) |
| User Story #2 | **Moyenne** (Priority = 2) |

### Étiquettes des tâches

| Étiquette | Usage |
|---|---|
| `Interface` | tâches liées à l'interface |
| `Backend` | tâches liées au backend |
| `Test` | tâches de test |

Étiquetez chacune des sept tâches avec la bonne étiquette (champ **Tags** du formulaire, ou modification en masse).

**Point de contrôle I** — Sur le tableau des tâches du Sprint 1, chaque carte affiche son étiquette.

## J — Faire vivre les éléments : le cycle de vie

1. Tâche « Créer la maquette… » : passez-la de **New** à **Active**, puis à **Closed**. Observez le reste à faire (Remaining Work) et le champ **Reason**.
2. User Story #1 : faites-la avancer de **New** à **Active**, **Resolved**, puis **En attente de validation**. Sur le tableau, la carte suit les colonnes.
3. Élément Documentation : de **Nouveau** à **En cours**, puis **En révision**.
4. Ouvrez l'onglet **History** de la User Story #1.

**Point de contrôle J** — L'historique de la User Story #1 montre chaque changement d'état, avec sa date, son auteur et sa raison. La carte est dans la colonne `Attente client`.

## K — Requêtes

Boards > **Queries** > **New query**, puis **Save query** dans **Shared Queries** :

| Requête | Ce qu'elle retourne |
|---|---|
| `Clinique - Interface` | les éléments portant l'étiquette `Interface` |
| `Clinique - Tâches P3` | les tâches de priorité 3 |

**Point de contrôle K** — Chaque requête renvoie les éléments attendus d'après vos étiquettes et le tableau des tâches.

## L — Capacité de l'équipe et planning

### L.1 — Capacité

| Élément | Valeur |
|---|---|
| **Capacité** | chaque membre consacre **30 heures par semaine** au projet, soit 6 heures par jour |
| **Activité** | Vous et Jim : Development ; John : Testing |
| **Congés** | une journée par membre et par sprint |
| **Jours fériés** | vendredi 25 décembre 2026 et vendredi 1er janvier 2027, tous deux dans le Sprint 3 |

Boards > **Sprints** > `Sprint 1` > onglet **Capacity** : ajoutez les membres de l'équipe, saisissez l'activité et la capacité par jour, puis les congés du Sprint 1 :

| Membre | Jour de congé, Sprint 1 |
|---|---|
| Vous | vendredi 27 novembre 2026 |
| Jim | mercredi 2 décembre 2026 |
| John | lundi 30 novembre 2026 |

Faites de même pour les Sprints 2 et 3, avec un jour de congé au choix pour chacun. Dans le Sprint 3, saisissez les deux jours fériés comme **congés d'équipe**.

### L.2 — Planning des cérémonies

La revue de sprint et la rétrospective ont lieu le **dernier jour ouvré** de chaque sprint : vendredi 4 décembre 2026, vendredi 18 décembre 2026 et **jeudi 31 décembre 2026** (le 1er janvier est férié).

Boards > **Delivery Plans** > **New Plan** `Planning Clinique`, avec votre équipe et son niveau Stories. Le plan affiche les périodes des sprints. Puis **Settings** > **Markers** : un marqueur `Revue et rétro S1`, `S2`, `S3` à chacune de ces dates.

**Point de contrôle L** — Le volet **Work details** du Sprint 1 compte la capacité sur les jours restants du sprint : regardé le lundi 23 novembre, il affiche 162 heures pour l'équipe (3 membres, 9 jours de 6 heures). Le Sprint 3 affiche 126 heures (3 membres, 7 jours). Le plan montre les trois sprints, les user stories dans leur sprint et les trois marqueurs.

## M — Commentaires

Sur la tâche « Développer l'interface utilisateur selon la maquette approuvée », dans la zone **Discussion**, écrivez un commentaire qui mentionne Jim (`@` puis son nom) pour lui indiquer que la maquette risque d'être modifiée.

**Point de contrôle M** — Le commentaire affiche la mention de Jim comme un lien ; Jim reçoit un courriel de notification.

