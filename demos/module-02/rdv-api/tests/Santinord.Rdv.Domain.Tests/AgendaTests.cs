using Santinord.Rdv.Domain;

namespace Santinord.Rdv.Domain.Tests;

/// <summary>Horloge figée : les tests ne dépendent jamais de la date du jour.</summary>
internal sealed class HorlogeFixe(DateTime maintenant) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => new(maintenant, TimeSpan.Zero);

    public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;
}

public class AgendaTests
{
    // Lundi 23 novembre 2026, 9 h : premier jour de la session de formation.
    private static readonly DateTime Maintenant = new(2026, 11, 23, 9, 0, 0);
    private static readonly DateOnly Mardi = new(2026, 11, 24);
    private static readonly DateOnly Samedi = new(2026, 11, 28);
    private static readonly DateOnly Dimanche = new(2026, 11, 29);
    private const string Leroy = "DR-LV-01";
    private const string Saidi = "DR-LV-02";

    private static Agenda NouvelAgenda(int dureeCreneau = 20) =>
        new(new ReglesAgenda { DureeCreneauMinutes = dureeCreneau }, new HorlogeFixe(Maintenant), Referentiel.Praticiens);

    [Fact]
    public void Un_jour_de_semaine_compte_33_creneaux_de_20_minutes()
    {
        var creneaux = NouvelAgenda().CreneauxLibres(Leroy, Mardi);

        Assert.Equal(33, creneaux.Count);
        Assert.Equal(Mardi.ToDateTime(new TimeOnly(8, 0)), creneaux[0]);
        Assert.Equal(Mardi.ToDateTime(new TimeOnly(18, 40)), creneaux[^1]);
    }

    [Fact]
    public void Le_samedi_les_creneaux_s_arretent_a_midi()
    {
        var creneaux = NouvelAgenda().CreneauxLibres(Leroy, Samedi);

        Assert.Equal(12, creneaux.Count);
        Assert.Equal(Samedi.ToDateTime(new TimeOnly(11, 40)), creneaux[^1]);
    }

    [Fact]
    public void Le_dimanche_aucun_creneau()
    {
        Assert.Empty(NouvelAgenda().CreneauxLibres(Leroy, Dimanche));
    }

    [Fact]
    public void Aujourd_hui_les_creneaux_deja_passes_ne_sont_pas_proposes()
    {
        var aujourdhui = DateOnly.FromDateTime(Maintenant);

        var creneaux = NouvelAgenda().CreneauxLibres(Leroy, aujourdhui);

        Assert.All(creneaux, c => Assert.True(c > Maintenant));
        Assert.Equal(aujourdhui.ToDateTime(new TimeOnly(9, 20)), creneaux[0]);
    }

    [Fact]
    public void La_duree_de_creneau_est_parametrable()
    {
        Assert.Equal(22, NouvelAgenda(dureeCreneau: 30).CreneauxLibres(Leroy, Mardi).Count);
    }

    [Fact]
    public void Reserver_un_creneau_libre_reussit_et_le_retire_des_creneaux_libres()
    {
        var agenda = NouvelAgenda();
        var debut = Mardi.ToDateTime(new TimeOnly(10, 0));

        var resultat = agenda.Reserver(Leroy, "P-104233", debut);

        Assert.True(resultat.Succes);
        Assert.Equal(20, resultat.RendezVous!.DureeMinutes);
        Assert.DoesNotContain(debut, agenda.CreneauxLibres(Leroy, Mardi));
    }

    [Fact]
    public void Reserver_un_creneau_passe_est_refuse()
    {
        var resultat = NouvelAgenda().Reserver(Leroy, "P-104233", Maintenant.AddMinutes(-20));

        Assert.Equal(MotifRefus.CreneauPasse, resultat.Motif);
    }

    [Fact]
    public void Reserver_au_dela_de_90_jours_est_refuse()
    {
        var resultat = NouvelAgenda().Reserver(Leroy, "P-104233", new DateTime(2027, 3, 1, 10, 0, 0));

        Assert.Equal(MotifRefus.TropLointain, resultat.Motif);
    }

    [Theory]
    [InlineData(2026, 11, 24, 10, 5)]  // pas aligné sur la grille de 20 minutes
    [InlineData(2026, 11, 24, 7, 40)]  // avant l'ouverture
    [InlineData(2026, 11, 24, 19, 0)]  // à la fermeture
    [InlineData(2026, 11, 28, 12, 0)]  // samedi après-midi
    [InlineData(2026, 11, 29, 10, 0)]  // dimanche
    public void Reserver_hors_planning_est_refuse(int annee, int mois, int jour, int heure, int minute)
    {
        var resultat = NouvelAgenda().Reserver(Leroy, "P-104233", new DateTime(annee, mois, jour, heure, minute, 0));

        Assert.Equal(MotifRefus.HorsPlanning, resultat.Motif);
    }

    [Fact]
    public void Reserver_chez_un_praticien_inconnu_est_refuse()
    {
        var resultat = NouvelAgenda().Reserver("DR-XX-99", "P-104233", Mardi.ToDateTime(new TimeOnly(10, 0)));

        Assert.Equal(MotifRefus.PraticienInconnu, resultat.Motif);
    }

    [Fact]
    public void Un_creneau_ne_se_reserve_qu_une_fois()
    {
        var agenda = NouvelAgenda();
        var debut = Mardi.ToDateTime(new TimeOnly(10, 0));
        agenda.Reserver(Leroy, "P-104233", debut);

        var resultat = agenda.Reserver(Leroy, "P-200871", debut);

        Assert.Equal(MotifRefus.CreneauDejaPris, resultat.Motif);
    }

    [Fact]
    public void Un_patient_ne_reserve_qu_un_rendez_vous_par_jour_chez_le_meme_praticien()
    {
        var agenda = NouvelAgenda();
        agenda.Reserver(Leroy, "P-104233", Mardi.ToDateTime(new TimeOnly(10, 0)));

        var resultat = agenda.Reserver(Leroy, "P-104233", Mardi.ToDateTime(new TimeOnly(16, 0)));

        Assert.Equal(MotifRefus.DoublonPatient, resultat.Motif);
    }

    [Fact]
    public void Un_patient_peut_voir_deux_praticiens_le_meme_jour()
    {
        var agenda = NouvelAgenda();
        agenda.Reserver(Leroy, "P-104233", Mardi.ToDateTime(new TimeOnly(10, 0)));

        var resultat = agenda.Reserver(Saidi, "P-104233", Mardi.ToDateTime(new TimeOnly(11, 0)));

        Assert.True(resultat.Succes);
    }

    [Fact]
    public void Annuler_plus_de_24_heures_avant_libere_le_creneau()
    {
        var agenda = NouvelAgenda();
        var debut = Mardi.ToDateTime(new TimeOnly(10, 0));
        var rendezVous = agenda.Reserver(Leroy, "P-104233", debut).RendezVous!;

        Assert.Equal(ResultatAnnulation.Annule, agenda.Annuler(rendezVous.Id));
        Assert.Contains(debut, agenda.CreneauxLibres(Leroy, Mardi));
    }

    [Fact]
    public void Annuler_moins_de_24_heures_avant_est_refuse()
    {
        var agenda = NouvelAgenda();
        var rendezVous = agenda.Reserver(Leroy, "P-104233", Maintenant.Date.AddHours(17)).RendezVous!;

        Assert.Equal(ResultatAnnulation.AnnulationTardive, agenda.Annuler(rendezVous.Id));
    }

    [Fact]
    public void Annuler_un_rendez_vous_inconnu_renvoie_introuvable()
    {
        Assert.Equal(ResultatAnnulation.Introuvable, NouvelAgenda().Annuler(Guid.NewGuid()));
    }
}
