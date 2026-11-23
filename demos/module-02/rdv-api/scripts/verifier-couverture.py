#!/usr/bin/env python3
"""Fusionne les rapports Cobertura des projets de tests et échoue sous le seuil.

Usage : python3 scripts/verifier-couverture.py <seuil-en-%> "<motif glob des rapports>"
Exemple dans le pipeline :
  python3 scripts/verifier-couverture.py 80 "$(Agent.TempDirectory)/**/coverage.cobertura.xml"

Chaque projet de tests produit son propre rapport ; une même ligne de code peut
y figurer deux fois (le domaine est couvert par les tests unitaires ET par les
tests d'intégration). On fusionne donc ligne par ligne : une ligne est couverte
si au moins un rapport l'a exécutée.
"""
import glob
import os
import sys
import xml.etree.ElementTree as ET

seuil = float(sys.argv[1])
motif = sys.argv[2]

lignes: dict[tuple[str, str], bool] = {}
rapports = glob.glob(motif, recursive=True)
for rapport in rapports:
    racine = ET.parse(rapport).getroot()
    sources = [s.text or "" for s in racine.iter("source")]
    base = sources[0] if sources else ""
    for classe in racine.iter("class"):
        fichier = os.path.normpath(os.path.join(base, classe.get("filename", "")))
        for ligne in classe.iter("line"):
            cle = (fichier, ligne.get("number", "0"))
            lignes[cle] = lignes.get(cle, False) or int(ligne.get("hits", "0")) > 0

if not lignes:
    print(f"##vso[task.logissue type=error]Aucun rapport de couverture trouvé pour {motif}")
    sys.exit(1)

taux = 100 * sum(lignes.values()) / len(lignes)
print(f"{len(rapports)} rapport(s), {len(lignes)} lignes instrumentées")
print(f"Couverture de lignes fusionnée : {taux:.1f} % (seuil : {seuil:.0f} %)")
if taux < seuil:
    print(f"##vso[task.logissue type=error]Couverture de {taux:.1f} % inférieure au seuil de {seuil:.0f} %")
    sys.exit(1)
