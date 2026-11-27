// Calcul du prix d'un stationnement dans les parkings ParkNord.
// Les montants sont en centimes d'euro : pas d'arrondi de nombres à virgule.
// Chargé par la page (balise <script>) et par les tests (require).

const MINUTES_GRATUITES = 15;
const PRIX_HEURE_CENTIMES = 250;
const PLAFOND_JOUR_CENTIMES = 2000;
const MINUTES_PAR_JOUR = 24 * 60;

const FORFAIT_TICKET_PERDU_CENTIMES = 3000;

// La durée saisie, en minutes, ou null si la saisie n'est pas valide :
// des nombres entiers, des heures positives, des minutes de 0 à 59.
function dureeEnMinutes(heures, minutes) {
  const h = Number(heures);
  const m = Number(minutes);
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || m < 0 || m > 59) {
    return null;
  }
  return h * 60 + m;
}

// Moins de 24 heures : chaque heure entamée est due, dans la limite du plafond.
function prixDUneJournee(minutes) {
  const heuresEntamees = Math.ceil(minutes / 60);
  return Math.min(heuresEntamees * PRIX_HEURE_CENTIMES, PLAFOND_JOUR_CENTIMES);
}

// Le prix d'un stationnement. Les premières minutes sont gratuites ; au-delà,
// chaque journée complète coûte le plafond, et le reste se paie à l'heure entamée.
function prixEnCentimes(dureeMinutes, ticketPerdu = false) {
       if (ticketPerdu) {
         return FORFAIT_TICKET_PERDU_CENTIMES;
       }

// 1250 centimes s'affichent "12,50 €".
function enEuros(centimes) {
  return (centimes / 100).toFixed(2).replace(".", ",") + " €";
}

if (typeof module !== "undefined") {
  module.exports = { dureeEnMinutes, prixEnCentimes, enEuros };
}
