const { describe, test } = require("node:test");
const assert = require("node:assert/strict");
const { creneauxDeLaJournee, creneauxLibres } = require("../js/creneaux.js");

describe("Créneaux de la journée", () => {
  test("une matinée de 8 h à 12 h compte 12 créneaux de 20 minutes", () => {
    const creneaux = creneauxDeLaJournee("08:00", "12:00");
    assert.equal(creneaux.length, 12);
    assert.equal(creneaux[0], "08:00");
    assert.equal(creneaux[11], "11:40");
  });

  test("aucun créneau ne déborde sur la fermeture", () => {
    const creneaux = creneauxDeLaJournee("14:00", "18:30");
    assert.equal(creneaux.at(-1), "18:00");
  });

  test("sans réservation, tous les créneaux sont libres", () => {
    assert.deepEqual(creneauxLibres("09:00", "10:00", []), ["09:00", "09:20", "09:40"]);
  });
});
