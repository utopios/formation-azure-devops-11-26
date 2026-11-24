# clinique-web

Page de prise de rendez-vous en ligne de la clinique : le patient choisit un médecin et voit ses créneaux libres de la journée.

## Lancer la page

Ouvrez `index.html` dans Edge ou Chrome (double-clic) : aucun serveur n'est nécessaire.

## Lancer les tests

Node.js 20 ou plus récent :

```bash
node --test
```

Le pipeline `azure-pipelines.yml` lance les mêmes tests à chaque push sur `main` et à chaque pull request.

## Organisation du code

| Fichier | Rôle |
|---|---|
| `index.html` | la page |
| `css/style.css` | la mise en forme |
| `js/creneaux.js` | le calcul des créneaux, sans lien avec la page : c'est lui que les tests vérifient |
| `js/disponibilites.js` | les horaires et réservations des médecins, en attendant l'API de calendrier |
| `js/app.js` | le lien entre la page et le calcul |
| `tests/creneaux.test.js` | les tests unitaires |

## Conventions de l'équipe

- Une branche par élément de travail, créée depuis Boards : `feature/<id>-<sujet>`, `bugfix/<id>-<sujet>`.
- Chaque message de commit cite sa tâche : « Ajoute le formulaire #123 ».
- Rien n'entre dans `main` sans pull request : un relecteur, une tâche liée, des tests verts.
