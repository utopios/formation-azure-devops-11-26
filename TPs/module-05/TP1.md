# TP  Templates : le build et les tests de BasicJavaWebApp

> Module : 4 — Les builds
> Travail : individuel, dans votre organisation Azure DevOps

## Mise en situation

L'équipe Java a une application Spring Boot (Java 11, Maven, packagée en `war`). Chaque nouveau projet Java recopie le même pipeline de build, avec ses petites différences. Une correction doit être reportée à la main partout.

Votre mission : écrire le pipeline de build et de test **une fois**, dans des templates, puis l'appeler en ne changeant que des paramètres.

Ce TP est guidé : le code de chaque étape est donné. Recopiez-le à la main plutôt que par copier-coller, et répondez aux questions des points de contrôle.

## Ce que vous allez construire

```
pipelines/
├── build-java.yml              le pipeline : il ne fait qu'appeler les templates
└── templates/
    ├── etapes-maven.yml        template d'étapes : compiler, tester, publier le war
    ├── job-maven.yml           template de job : un agent + les étapes ci-dessus
    └── variables-version.yml   template de variables : le numéro de version
```

## Prérequis

| Élément | Détail |
|---|---|
| Projet | un projet `Java-<Prénom>` dans votre organisation |
| Dépôt | `basic-java-webapp` : Repos > Import repository, avec l'URL donnée par le formateur. Sa branche principale est `master` |

## Déroulé

| Étape | Contenu | Durée |
|---|---|---|
| 0 | Préparer la branche | 5 min |
| 1 | Le pipeline de référence, sans template | 10 min |
| 2 | Un premier template d'étapes | 12 min |
| 3 | Des paramètres et des insertions conditionnelles | 15 min |
| 4 | Un template de job et un template de variables | 12 min |
| 5 | Une modification, deux jobs | 5 min |
| 6 | Trois erreurs à provoquer | 8 min |

---

## Étape 0 — Préparer la branche (5 min)

1. Repos > Branches > **New branch** : `feature/templates`, depuis `master`
2. Clonez le dépôt, ou travaillez dans l'éditeur web (Repos > Files, sur votre branche)
3. Créez le dossier `pipelines/templates/`

## Étape 1 — Le pipeline de référence, sans template (10 min)

On écrit d'abord le pipeline **sans** template. Il servira de référence : après chaque transformation, le run doit donner le même résultat.

Créez `pipelines/build-java.yml` :

```yaml
trigger: none

pool:
  vmImage: ubuntu-24.04

steps:
  - task: Maven@3
    displayName: Maven package
    inputs:
      mavenPomFile: pom.xml
      goals: package
      options: -B -ntp                       # pas d'interaction, pas de barre de téléchargement
      publishJUnitResults: true
      testResultsFiles: '**/surefire-reports/TEST-*.xml'
      testRunTitle: JUnit - $(Build.BuildNumber)
      javaHomeOption: JDKVersion
      jdkVersionOption: '1.11'               # le pom demande Java 11

  - task: CopyFiles@2
    displayName: Copier le war
    inputs:
      Contents: '**/target/*.war'
      TargetFolder: $(Build.ArtifactStagingDirectory)
      flattenFolders: true

  - task: PublishPipelineArtifact@1
    displayName: Publier l'artefact
    inputs:
      targetPath: $(Build.ArtifactStagingDirectory)
      artifact: webapp
```

Poussez sur `feature/templates`, puis créez le pipeline :

1. Pipelines > New pipeline > Azure Repos Git > `basic-java-webapp`
2. *Existing Azure Pipelines YAML file* > branche `feature/templates`, chemin `/pipelines/build-java.yml` > Continue > Run
3. Renommez-le `build-java` (menu ⋮ > Rename/move)

**Point de contrôle 1** :

- le run est vert ;
- l'onglet **Tests** montre 1 test réussi (`contextLoads`) ;
- l'artefact `webapp` contient `webapp-0.0.1-SNAPSHOT.war`. À quoi sert `flattenFolders: true` ?

## Étape 2 — Un premier template d'étapes (12 min)

On déplace les trois étapes dans un template. Le pipeline ne fera plus que l'appeler.

1. Créez `pipelines/templates/etapes-maven.yml`. Collez-y les trois étapes de l'étape 1, puis ajoutez en tête un **paramètre** pour la version du JDK :

```yaml
# Template d'étapes : compiler, tester, publier le war.
parameters:
  - name: versionJdk
    type: string
    default: '1.11'
    values:                # toute autre valeur est refusée avant le run
      - '1.11'
      - '1.17'

steps:
  - task: Maven@3
    displayName: Maven package (JDK ${{ parameters.versionJdk }})
    inputs:
      mavenPomFile: pom.xml
      goals: package
      options: -B -ntp
      publishJUnitResults: true
      testResultsFiles: '**/surefire-reports/TEST-*.xml'
      testRunTitle: JUnit - JDK ${{ parameters.versionJdk }} - $(Build.BuildNumber)
      javaHomeOption: JDKVersion
      jdkVersionOption: ${{ parameters.versionJdk }}

  # ... CopyFiles@2 et PublishPipelineArtifact@1, inchangées
```

2. Dans `pipelines/build-java.yml`, remplacez les trois étapes par un appel au template :

```yaml
steps:
  - template: templates/etapes-maven.yml     # chemin relatif au fichier qui appelle
    parameters:
      versionJdk: '1.11'
```

3. Poussez et lancez un run.
4. Ouvrez le pipeline en édition (**Edit**), puis menu ⋮ > **Download full YAML**. Ouvrez le fichier téléchargé.

**Point de contrôle 2** :

- le run donne le même résultat qu'à l'étape 1 : 1 test, le même artefact ;
- dans la liste des étapes du job, cherchez le mot « template ». Vous ne le trouvez pas : pourquoi ?
- dans le YAML complet, que sont devenus `${{ parameters.versionJdk }}` et `$(Build.BuildNumber)` ? Pourquoi l'un est-il remplacé et pas l'autre ?

## Étape 3 — Des paramètres et des insertions conditionnelles (15 min)

On veut :

- pouvoir **sauter les tests** au lancement ;
- compiler aussi en **JDK 17**, pour vérifier la compatibilité, mais publier l'artefact une seule fois.

1. Dans `etapes-maven.yml`, ajoutez deux paramètres après `versionJdk` :

```yaml
  - name: executerTests
    type: boolean
    default: true
  - name: nomArtefact
    type: string
    default: ''            # vide : pas d'artefact
```

2. Remplacez les `inputs` de `Maven@3`. Un `${{ if }}` peut choisir des **clés**, pas seulement des étapes :

```yaml
    inputs:
      mavenPomFile: pom.xml
      goals: package
      javaHomeOption: JDKVersion
      jdkVersionOption: ${{ parameters.versionJdk }}
      ${{ if eq(parameters.executerTests, true) }}:
        options: -B -ntp
        publishJUnitResults: true
        testResultsFiles: '**/surefire-reports/TEST-*.xml'
        testRunTitle: JUnit - JDK ${{ parameters.versionJdk }} - $(Build.BuildNumber)
      ${{ else }}:
        options: -B -ntp -DskipTests
        publishJUnitResults: false
```

3. Les deux étapes de publication ne sont insérées que si un nom d'artefact est donné :

```yaml
  - ${{ if ne(parameters.nomArtefact, '') }}:
      - task: CopyFiles@2
        displayName: Copier le war
        inputs:
          Contents: '**/target/*.war'
          TargetFolder: $(Build.ArtifactStagingDirectory)
          flattenFolders: true

      - task: PublishPipelineArtifact@1
        displayName: Publier l'artefact ${{ parameters.nomArtefact }}
        inputs:
          targetPath: $(Build.ArtifactStagingDirectory)
          artifact: ${{ parameters.nomArtefact }}
```

4. Dans `build-java.yml`, ajoutez un paramètre de **pipeline** (il apparaît dans le formulaire *Run pipeline*), puis appelez le template dans deux jobs :

```yaml
trigger: none

parameters:
  - name: executerTests
    displayName: Exécuter les tests
    type: boolean
    default: true

pool:
  vmImage: ubuntu-24.04

jobs:
  - job: Jdk11
    displayName: Maven - JDK 11
    steps:
      - template: templates/etapes-maven.yml
        parameters:
          versionJdk: '1.11'
          executerTests: ${{ parameters.executerTests }}
          nomArtefact: webapp
```

**À vous** : ajoutez le job `Jdk17`. Il compile en JDK 17, transmet `executerTests`, et ne publie **pas** d'artefact.

5. Lancez deux runs : un avec la case « Exécuter les tests » cochée, un avec la case décochée.

**Point de contrôle 3** :

- run avec tests : deux jobs. L'onglet **Tests** montre deux séries, une par JDK, grâce au titre. Seul `Jdk11` a les étapes de copie et de publication, et `Jdk17` ne les a pas du tout (ni *skipped*, ni grisées) ;
- run sans tests : la commande Maven contient `-DskipTests` (journal de `Maven@3`), et l'onglet Tests est vide ;
- question : pourquoi `${{ if }}` et pas `condition:` ? Deux raisons : l'une tient au moment où le paramètre est connu, l'autre aux `inputs`.

## Étape 4 — Un template de job et un template de variables (12 min)

Les deux jobs se ressemblent encore : `job`, `displayName`, appel du template. On factorise le job entier, puis la numérotation.

1. Créez `pipelines/templates/job-maven.yml` :

```yaml
# Template de job : un agent Ubuntu, et les étapes Maven.
parameters:
  - name: nomJob
    type: string                # pas de valeur par défaut : obligatoire
  - name: versionJdk
    type: string
    default: '1.11'
  - name: executerTests
    type: boolean
    default: true
  - name: nomArtefact
    type: string
    default: ''

jobs:
  - job: ${{ parameters.nomJob }}
    displayName: Maven - JDK ${{ parameters.versionJdk }}
    pool:
      vmImage: ubuntu-24.04
    steps:
      - template: etapes-maven.yml        # relatif à CE fichier : même dossier
        parameters:
          versionJdk: ${{ parameters.versionJdk }}
          executerTests: ${{ parameters.executerTests }}
          nomArtefact: ${{ parameters.nomArtefact }}
```

2. Créez `pipelines/templates/variables-version.yml` :

```yaml
# Template de variables : la version de l'application, partagée par les pipelines.
variables:
  - name: versionMajeure
    value: 1
  - name: versionMineure
    value: 0
```

3. Réécrivez `pipelines/build-java.yml` en entier :

```yaml
name: $(versionMajeure).$(versionMineure).$(Rev:r)

trigger: none

parameters:
  - name: executerTests
    displayName: Exécuter les tests
    type: boolean
    default: true

variables:
  - template: templates/variables-version.yml

jobs:
  - template: templates/job-maven.yml
    parameters:
      nomJob: Jdk11
      versionJdk: '1.11'
      executerTests: ${{ parameters.executerTests }}
      nomArtefact: webapp

  # À vous : le job Jdk17, sans artefact
```

Il n'y a plus de `pool:` à la racine : chaque job le porte, dans le template.

Lancez un run.

**Point de contrôle 4** :

- le run s'appelle `1.0.1`, et il a les mêmes jobs et étapes qu'à l'étape 3 ;
- `build-java.yml` tient en une trentaine de lignes, et ne contient plus aucune tâche ;
- dans `job-maven.yml`, le chemin est `etapes-maven.yml`, et non `templates/etapes-maven.yml`. Pourquoi ?

## Étape 5 — Une modification, deux jobs (5 min)

Dans `etapes-maven.yml`, juste après la tâche `Maven@3`, ajoutez :

```yaml
  - script: ls -l target/
    displayName: Contenu de target
```

Poussez et lancez, **sans toucher** à `build-java.yml`.

**Point de contrôle 5** :

- l'étape « Contenu de target » apparaît dans les **deux** jobs ;
- question : c'est l'intérêt des templates. Quel est le risque, quand dix pipelines utilisent ce template ? Comment l'équipe se protège-t-elle ?

## Étape 6 — Trois erreurs à provoquer (8 min)

Faites chaque erreur, lancez, lisez le message, puis **annulez-la** avant la suivante.

| Erreur | Ce que vous changez dans `build-java.yml` |
|---|---|
| A | `versionJdk: '1.8'` dans l'appel du job `Jdk11` |
| B | `template: templates/job-maven.yaml` (`.yaml` au lieu de `.yml`) |
| C | supprimez la ligne `nomJob: Jdk17` |

**Point de contrôle 6** :

- pour chaque erreur, vous savez dire quel fichier et quel paramètre le message cite ;
- question : combien d'agents ont été utilisés par ces trois runs ? Qu'en concluez-vous sur le moment où les templates sont vérifiés ?
- l'erreur A : `job-maven.yml` ne déclare pas de `values` pour `versionJdk`. Qui a refusé `1.8`, alors ?

## Pour aller plus loin (si vous avez fini)

Les deux appels de `job-maven.yml` ne diffèrent que par la version du JDK. Remplacez-les par une boucle `${{ each }}` sur un paramètre de pipeline de type `object` :

```yaml
parameters:
  - name: versionsJdk
    displayName: Versions du JDK
    type: object
    default:
      - '1.11'
      - '1.17'
```

- Chaque job a un nom différent. Les points sont interdits dans un nom de job : utilisez `replace(version, '.', '_')`.
- Seul le job `1.11` publie l'artefact.

## Livrable

- les quatre fichiers de `pipelines/` sur la branche `feature/templates` ;
- un run vert nommé `1.0.x`, avec deux jobs, deux séries de tests et l'artefact `webapp` ;
- les réponses aux questions des points de contrôle.
