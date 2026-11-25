## Travail Pratique : Mise en Place d'un Pipeline CI/CD avec Azure Pipelines

#### Partie 1 : Écriture du Pipeline CI/CD
En vous basant sur le YAML fourni, vous allez créer un fichier de pipeline `azure-pipelines.yml` dans un nouveau dépôt git et qui comprendra les étapes suivantes : 

1. **Trigger** : Configurez le pipeline pour qu'il se déclenche sur les pushs dans la branche `master`.

2. **Build** : Créez une étape de build qui :
   - Construit l'application frontend, affiche un message "building frontend app".
   - Exécute les tests unitaires du frontend, affiche un message "running unit tests for frontend app".
   - Construit l'application backend, affiche un message "building backend app".
   - Exécute les tests unitaires du backend, affiche un message "running unit tests for backend app".

