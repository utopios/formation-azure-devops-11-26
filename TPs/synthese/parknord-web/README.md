# parknord-web

Simulateur de prix des parkings ParkNord : le client saisit une durée de stationnement et voit le prix à payer.

Le calcul (`js/tarifs.js`) est aussi publié comme paquet npm, `parknord-tarifs`, pour l'équipe des bornes de paiement.

## Ouvrir la page

Ouvrez `index.html` dans Edge ou Chrome (double-clic) : aucun serveur n'est nécessaire. En local, le pied de page affiche `Version __VERSION__` ; le pipeline remplace ce texte par le numéro du run.

## Lancer les tests

Node.js 20 ou plus récent, aucune dépendance à installer :

```bash
node --test
```

## Organisation du code

| Fichier | Rôle |
|---|---|
| `index.html` | la page |
| `css/style.css` | la mise en forme |
| `js/tarifs.js` | le calcul du prix, sans lien avec la page : c'est lui que les tests vérifient et que le paquet npm contient |
| `js/app.js` | le lien entre la page et le calcul |
| `tests/tarifs.test.js` | les tests unitaires |
