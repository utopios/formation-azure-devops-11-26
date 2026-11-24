// Relie la page au calcul des créneaux.
document.addEventListener("DOMContentLoaded", () => {
  const medecin = document.getElementById("medecin");
  const liste = document.getElementById("creneaux");
  if (!medecin || !liste) {
    return; // le formulaire n'est pas encore sur la page
  }

  for (const nom of Object.keys(DISPONIBILITES)) {
    medecin.add(new Option(nom, nom));
  }

  function afficher() {
    const jour = DISPONIBILITES[medecin.value];
    const libres = creneauxLibres(jour.ouverture, jour.fermeture, jour.reservations);
    liste.replaceChildren(...libres.map((heure) => {
      const li = document.createElement("li");
      li.textContent = heure;
      return li;
    }));

    const message = document.getElementById("message");
    message.textContent = libres.length === 0
      ? "Plus aucun créneau libre aujourd'hui pour ce médecin."
      : libres.length + " créneau(x) libre(s).";
  }

  medecin.addEventListener("change", afficher);
  afficher();
});
