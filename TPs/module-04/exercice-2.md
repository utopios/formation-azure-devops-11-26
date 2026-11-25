# Exercice Variables, portée et conditions

> Module : 4 — Les builds
> Durée : 45 min
> Quand : après la démo 4.1, partie 2 (`02` portée, `03` trois syntaxes, `E1`, `06` paramètres, `08` conditions)
> Travail : individuel, dans votre organisation Azure DevOps

## Mise en situation

L'équipe a un pipeline .NET qui fonctionne : il compile et lance les tests. Mais il a été écrit vite :

- une variable est utilisée sans être déclarée ;
- tout est compilé et livré de la même façon, que ce soit un essai sur une branche ou une version de `master`.

Votre mission : le rendre explicite et sélectif, sans changer ce qu'il compile.

## Le point de départ

```yaml
trigger:
- master

pool:
  vmImage: ubuntu-24.04

stages:
- stage: BuildAndTest
  jobs:
  - job: BuildAndTestJob
    steps:
    - task: DotNetCoreCLI@2
      displayName: 'Build .NET Core project'
      inputs:
        command: 'build'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildconfiguration)'

    - task: DotNetCoreCLI@2
      displayName: 'Test .NET Core project'
      inputs:
        command: 'test'
        projects: '**/dotnetcore-tests/*.csproj'
        arguments: '--configuration $(buildconfiguration) --logger trx'
        testRunTitle: 'dotnet test'
```

## Prérequis

- Le dépôt .NET fourni par le formateur, importé dans votre projet (Repos > Import repository). Sa branche principale est `master`
- Un pipeline créé depuis son `azure-pipelines.yml` : Pipelines > New pipeline > Azure Repos Git > le dépôt > *Existing Azure Pipelines YAML file* > `master`, `/azure-pipelines.yml` > Run
- Vous modifiez le YAML dans l'éditeur web (Pipelines > le pipeline > **Edit**). Chaque enregistrement sur `master` lance un run, car le déclencheur est sur `master` : c'est normal

## Étape 1 — Lire le point de départ (5 min)

Ouvrez le run lancé à la création, puis le journal de l'étape « Build .NET Core project ».

**Point de contrôle 1** — vous savez répondre :

- où est déclarée `buildconfiguration` ? Cherchez dans le fichier, puis dans Edit > **Variables** ;
- quelle valeur `dotnet` a-t-il reçue ? Lisez la ligne de commande dans le journal, et les avertissements ;
- dans quelle configuration le code a-t-il été compilé ?

## Étape 2 — Trois niveaux de portée et des macros (12 min)

1. Déclarez les variables au niveau le plus étroit qui convient :
   - `buildConfiguration`, valeur `Release`, à la **racine** : tous les stages en ont besoin ;
   - `projetsTests`, valeur `**/dotnetcore-tests/*.csproj`, au niveau du **stage** `BuildAndTest` ;
   - `titreTests`, au niveau du **job** `BuildAndTestJob`. Sa valeur est construite avec des macros : `dotnet test`, la configuration, puis le numéro du run (`Build.BuildNumber`).
2. Utilisez-les dans les deux tâches : la configuration dans `arguments`, `projetsTests` dans `projects` du test, `titreTests` dans `testRunTitle`. Plus aucune valeur n'est écrite en dur.
3. En tête du job, ajoutez une étape `script` « Afficher les variables », qui affiche les trois variables.
4. Ajoutez un second stage, `Rapport`, qui dépend de `BuildAndTest`. Il doit s'exécuter **même si** `BuildAndTest` échoue. Son job unique, `Resume`, affiche les trois mêmes variables.

   Écrivez ces lignes entre **apostrophes** (`echo '...'`). Une macro non résolue reste écrite telle quelle, et entre guillemets doubles, Bash prendrait `$(nom)` pour une commande.

**Point de contrôle 2** :

- dans « Afficher les variables », les trois valeurs sont résolues, et `titreTests` contient le numéro du run ;
- le journal de la compilation montre `--configuration Release`, sans l'avertissement de l'étape 1 ;
- l'onglet **Tests** du run affiche une série de tests intitulée avec votre titre ;
- dans `Rapport`, une seule des trois variables est résolue. Vous savez dire laquelle, et pourquoi les deux autres ne le sont pas.

## Étape 3 — Une condition au template : la configuration choisie au lancement (10 min)

1. Ajoutez un paramètre de run `configuration` : libellé « Configuration de compilation », type `string`, valeurs possibles `Release` et `Debug`, `Release` par défaut.
2. `buildConfiguration` prend désormais la valeur de ce paramètre, avec la syntaxe d'expression de template.
3. À la fin du job `BuildAndTestJob`, ajoutez deux étapes, insérées **uniquement si** la configuration est `Release` (`${{ if }}`) :
   - « Publier l'application » : `DotNetCoreCLI@2`, commande `publish`. Elle publie tous les projets sauf les tests : `publishWebProjects: false`, puis dans `projects`, une ligne `**/*.csproj` et une ligne `!**/dotnetcore-tests/*.csproj`. Elle utilise la configuration choisie, sa sortie va dans `$(Build.ArtifactStagingDirectory)`, compressée en zip ;
   - « Publier l'artefact » : `PublishPipelineArtifact@1`, ce dossier, artefact nommé `app`.
4. Lancez à la main deux fois : **Run pipeline** > *Configuration de compilation* `Release`, puis `Debug`.

**Point de contrôle 3** :

- le formulaire *Run pipeline* propose la liste `Release` / `Debug` ;
- run en `Release` : les deux étapes de publication s'exécutent, et le résumé du run indique un artefact `app` ;
- run en `Debug` : la compilation reçoit `--configuration Debug`, et les deux étapes de publication **n'apparaissent pas du tout** dans le job ;
- vous savez dire pourquoi un paramètre, et non une variable de la racine, permet de choisir la configuration au lancement.

## Étape 4 — Des conditions à l'exécution (12 min)

1. **Livrer seulement depuis `master`.** Les deux étapes de publication ne doivent s'exécuter que si tout a réussi **et** que le run porte sur `master`. Écrivez la condition avec `and()`, `succeeded()`, `eq()` et `variables['Build.SourceBranch']`. Gardez le `${{ if }}` de l'étape 3.
2. **Tester seulement s'il y a des tests.** Avant la compilation, ajoutez une étape `bash` « Détecter les projets de tests ». Elle compte les `.csproj` de `dotnetcore-tests/`, puis fixe une variable `aDesTests` à `true` ou `false` avec la commande de journalisation `##vso[task.setvariable variable=aDesTests]...`. La tâche de test ne s'exécute que si tout a réussi et que `aDesTests` vaut `true`.
3. Dans `Rapport`, ajoutez `aDesTests` à la liste des variables affichées.
4. Repos > Branches > **New branch** `essai`, créée depuis `master`. Puis Run pipeline sur `essai`, configuration `Release`.

**Point de contrôle 4** :

- run sur `master` : le test et les deux publications s'exécutent ;
- run sur `essai` : les deux étapes de publication sont **présentes mais ignorées** (*skipped*). Comparez avec le run `Debug` de l'étape 3, où elles étaient absentes : vous savez dire quelle condition a été évaluée quand ;
- dans `Rapport`, `aDesTests` n'est pas résolue, alors que la tâche de test, elle, l'a vue. Pourquoi ?

## Étape 5 — Deux pièges (6 min)

Essayez chaque piège, lisez le résultat, puis **annulez-le**.

| Piège | Ce que vous écrivez |
|---|---|
| A | dans l'étape 3, remplacez la condition d'insertion par `${{ if eq($(buildConfiguration), 'Release') }}` |
| B | à la fin du job, insérez une étape `script: echo "Des tests ont été trouvés"` sous `${{ if eq(variables.aDesTests, 'true') }}` |

**Point de contrôle 5** :

- piège A : le run est refusé **avant** de démarrer. Vous savez dire quelle ligne est en cause, et pourquoi une macro ne peut pas être lue à cet endroit ;
- piège B : aucun message d'erreur, et pourtant l'étape n'apparaît jamais, même quand des tests sont trouvés. Pourquoi ? Que faut-il écrire à la place ?

## Pour aller plus loin (si vous avez fini)

Faites en sorte que `Rapport` connaisse `aDesTests`. Pour cela :

1. Transformez-la en **variable de sortie** (`isOutput=true`, avec un `name:` sur l'étape de détection) ;
2. Relisez-la dans le job `Resume` avec une expression d'exécution `$[ stageDependencies... ]` (démo, fichier `04`) ;
3. Attention : dans le job de détection lui-même, la condition du test doit alors lire `nomEtape.aDesTests`.

## Livrable

Le fichier `azure-pipelines.yml` modifié et trois runs :

- un run `Release` sur `master`, avec l'artefact `app` ;
- un run `Debug`, sans étape de publication ;
- un run sur `essai`, avec les publications ignorées.
