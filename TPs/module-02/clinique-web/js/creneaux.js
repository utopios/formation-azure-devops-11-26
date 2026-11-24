// Calcul des créneaux de rendez-vous d'un médecin pour une journée.
// Chargé par la page (balise <script>) et par les tests (require).

const DUREE_CRENEAU_MINUTES = 20;

function enMinutes(heure) {
  const [h, m] = heure.split(":").map(Number);
  return h * 60 + m;
}

function enHeure(minutes) {
  const h = String(Math.floor(minutes / 60)).padStart(2, "0");
  const m = String(minutes % 60).padStart(2, "0");
  return h + ":" + m;
}

// Tous les créneaux entre l'ouverture et la fermeture : un créneau qui
// finirait après la fermeture n'est pas proposé.
function creneauxDeLaJournee(ouverture, fermeture) {
  const creneaux = [];
  for (let m = enMinutes(ouverture); m + DUREE_CRENEAU_MINUTES <= enMinutes(fermeture); m += DUREE_CRENEAU_MINUTES) {
    creneaux.push(enHeure(m));
  }
  return creneaux;
}

// Les créneaux que le patient peut réserver.
function creneauxLibres(ouverture, fermeture, reservations) {
  return creneauxDeLaJournee(ouverture, fermeture);
}

if (typeof module !== "undefined") {
  module.exports = { creneauxDeLaJournee, creneauxLibres };
}
