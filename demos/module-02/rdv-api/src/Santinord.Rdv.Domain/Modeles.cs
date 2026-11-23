namespace Santinord.Rdv.Domain;

/// <summary>Un praticien d'un des trois centres Santinord.</summary>
public sealed record Praticien(string Id, string Nom, string Specialite, string Centre);

/// <summary>Un rendez-vous réservé. Les heures sont exprimées en heure locale du centre.</summary>
public sealed record RendezVous(Guid Id, string PraticienId, string PatientId, DateTime Debut, int DureeMinutes)
{
    public DateTime Fin => Debut.AddMinutes(DureeMinutes);
}

/// <summary>Pourquoi une réservation est refusée.</summary>
public enum MotifRefus
{
    PraticienInconnu,
    CreneauPasse,
    TropLointain,
    HorsPlanning,
    CreneauDejaPris,
    DoublonPatient,
}

/// <summary>Résultat d'une demande de réservation : un rendez-vous ou un motif de refus.</summary>
public sealed record ResultatReservation(RendezVous? RendezVous, MotifRefus? Motif)
{
    public bool Succes => RendezVous is not null;

    public static ResultatReservation Ok(RendezVous rendezVous) => new(rendezVous, null);

    public static ResultatReservation Refus(MotifRefus motif) => new(null, motif);
}

/// <summary>Résultat d'une demande d'annulation.</summary>
public enum ResultatAnnulation
{
    Annule,
    Introuvable,
    AnnulationTardive,
}

/// <summary>Règles de planning, réglables par configuration (section « Rdv »).</summary>
public sealed class ReglesAgenda
{
    public int DureeCreneauMinutes { get; init; } = 20;
    public TimeOnly Ouverture { get; init; } = new(8, 0);
    public TimeOnly FermetureSemaine { get; init; } = new(19, 0);
    public TimeOnly FermetureSamedi { get; init; } = new(12, 0);
    public int HorizonReservationJours { get; init; } = 90;
    public int DelaiAnnulationHeures { get; init; } = 24;
}
