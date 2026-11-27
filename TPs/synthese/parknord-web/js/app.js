// Le lien entre la page et le calcul de js/tarifs.js.

const formulaire = document.getElementById("simulateur");
const resultat = document.getElementById("resultat");

function afficher(texte, classe) {
  resultat.textContent = texte;
  resultat.className = classe;
}

formulaire.addEventListener("submit", (evenement) => {
  evenement.preventDefault();

  if (document.getElementById("ticket-perdu").checked) {
         afficher("Prix : " + enEuros(prixEnCentimes(0, true)), "prix");
         return;
       }
       
  const duree = dureeEnMinutes(
    document.getElementById("heures").value,
    document.getElementById("minutes").value
  );
  if (duree === null) {
    afficher("Durée invalide : des heures et des minutes entières, minutes de 0 à 59.", "erreur");
    return;
  }

  afficher("Prix : " + enEuros(prixEnCentimes(duree)), "prix");
});
