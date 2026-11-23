# rdv-api — API de prise de rendez-vous de Santinord

Code du fil rouge de la formation Azure DevOps (ORSYS ICA). API minimale
ASP.NET Core sur .NET 10, règles métier testées, pipelines Azure Pipelines
prêts à l'emploi.

## Lancer en local

```bash
dotnet test                                   # 29 tests : unitaires + intégration
dotnet run --project src/Santinord.Rdv.Api --urls http://localhost:5080
./scripts/smoke-test.sh http://localhost:5080
```

Les requêtes de test manuel sont dans `rdv-api.http` (VS Code REST Client ou
Visual Studio).

## Routes

| Route | Rôle |
|---|---|
| `GET /api/praticiens` | les six praticiens des trois centres |
| `GET /api/creneaux?praticienId=DR-LV-01&date=2026-11-24` | créneaux libres d'un jour |
| `POST /api/rendez-vous` | réserver (`praticienId`, `patientId`, `debut`) |
| `GET /api/rendez-vous/{id}` | consulter |
| `DELETE /api/rendez-vous/{id}` | annuler (refusé à moins de 24 h) |
| `GET /sante` | sonde de santé |
| `GET /version` | version, commit, environnement, bandeau |

Règles : lundi-vendredi 8 h - 19 h, samedi 8 h - 12 h, créneaux de 20 minutes
(`Rdv__DureeCreneauMinutes`), réservation jusqu'à 90 jours, un rendez-vous par
patient et par jour chez un même praticien.

## Configuration par environnement

| Clé | Variable d'environnement | Exemple |
|---|---|---|
| `Rdv:NomEnvironnement` | `Rdv__NomEnvironnement` | `Recette` |
| `Rdv:Bandeau` | `Rdv__Bandeau` | `RECETTE - données fictives` |
| `Rdv:DureeCreneauMinutes` | `Rdv__DureeCreneauMinutes` | `20` |

## Pipelines

| Fichier | Pipeline | Rôle |
|---|---|---|
| `azure-pipelines.yml` | `rdv-ci-cd` | Build, Dev, Recette, Prod ; paramètre `cible` = `simulation` ou `azure` |
| `pipelines/pr-validation.yml` | `rdv-pr` | build de validation des pull requests (stratégie de branche de `main`) |
| `pipelines/nightly-regression.yml` | `rdv-nuit` | régression planifiée chaque nuit de semaine |
| `pipelines/load-test.yml` | `rdv-charge` | test de charge Azure Load Testing |
| `pipelines/agent-prive.yml` | `rdv-agent-prive` | exécution sur le pool auto-hébergé `Santinord-Interne` |
| `pipelines/file-attente.yml` | `rdv-file-attente` | quatre jobs pour observer la file d'attente et les parallel jobs |
| `pipelines/templates/*.yml` | — | build réutilisable, job de déploiement, test de fumée |

En mode `simulation` (par défaut), aucune ressource Azure n'est nécessaire :
chaque stage de déploiement démarre l'API sur l'agent avec la configuration de
l'environnement, puis le test de fumée vérifie `/sante` et `/version`.

En mode `azure`, créez au préalable :

- trois App Service Linux .NET 10 : `app-rdv-dev`, `app-rdv-recette`, `app-rdv-prod` ;
- une connexion de service Azure Resource Manager `sc-rdv-azure` (fédération
  d'identité de charge de travail) ;
- trois groupes de variables nommés comme les environments (`rdv-dev`,
  `rdv-recette`, `rdv-prod`) contenant `urlApp` (URL https de l'App Service)
  et `bandeau`.

## Couverture de code

`scripts/verifier-couverture.py` fusionne les rapports Cobertura des deux
projets de tests et fait échouer le build sous le seuil (80 % par défaut,
paramètre `seuilCouverture` de `templates/build-dotnet.yml`).
