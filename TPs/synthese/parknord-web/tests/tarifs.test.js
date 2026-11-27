const { describe, test } = require("node:test");
const assert = require("node:assert/strict");
const { dureeEnMinutes, prixEnCentimes, enEuros } = require("../js/tarifs.js");

describe("Saisie de la durée", () => {
  test("2 h 30 font 150 minutes", () => {
    assert.equal(dureeEnMinutes("2", "30"), 150);
  });

  test("plus de 59 minutes est refusé", () => {
    assert.equal(dureeEnMinutes("1", "75"), null);
  });

  test("une durée négative est refusée", () => {
    assert.equal(dureeEnMinutes("-1", "0"), null);
  });

  test("une durée non entière est refusée", () => {
    assert.equal(dureeEnMinutes("1.5", "0"), null);
  });
});

describe("Prix d'un stationnement", () => {
  test("10 minutes sont gratuites", () => {
    assert.equal(prixEnCentimes(10), 0);
  });

  test("16 minutes coûtent une heure entamée, 2,50 €", () => {
    assert.equal(prixEnCentimes(16), 250);
  });

  test("1 h 01 coûte deux heures entamées, 5,00 €", () => {
    assert.equal(prixEnCentimes(61), 500);
  });

  test("10 heures sont plafonnées à 20 €", () => {
    assert.equal(prixEnCentimes(10 * 60), 2000);
  });

  test("25 heures coûtent une journée et une heure, 22,50 €", () => {
    assert.equal(prixEnCentimes(25 * 60), 2250);
  });

  test("un ticket perdu coûte le forfait de 30 €, quelle que soit la durée", () => {
       assert.equal(prixEnCentimes(10, true), 3000);
       assert.equal(prixEnCentimes(3 * 24 * 60, true), 3000);
     });

});

describe("Affichage", () => {
  test("1250 centimes s'affichent 12,50 €", () => {
    assert.equal(enEuros(1250), "12,50 €");
  });
});
