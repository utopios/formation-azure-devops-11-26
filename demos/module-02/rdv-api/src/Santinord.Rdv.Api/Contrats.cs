using Santinord.Rdv.Domain;

namespace Santinord.Rdv.Api;

/// <summary>Section « Rdv » de la configuration. Chaque environnement la surcharge
/// par variables d'environnement : Rdv__NomEnvironnement, Rdv__Bandeau, Rdv__DureeCreneauMinutes.</summary>
public sealed class RdvOptions
{
    public const string Section = "Rdv";

    public string NomEnvironnement { get; set; } = "Local";
    public string? Bandeau { get; set; }
    public int DureeCreneauMinutes { get; set; } = 20;
}

public sealed record DemandeRendezVous(string PraticienId, string PatientId, DateTime Debut);

public sealed record InfosVersion(string Version, string Commit, string Environnement, string? Bandeau);

/// <summary>Traduit un motif de refus métier en réponse HTTP « problem details ».</summary>
public static class Refus
{
    public static IResult EnReponse(MotifRefus motif)
    {
        var (statut, titre) = motif switch
        {
            MotifRefus.PraticienInconnu => (StatusCodes.Status404NotFound, "Praticien inconnu"),
            MotifRefus.CreneauDejaPris => (StatusCodes.Status409Conflict, "Créneau déjà pris"),
            MotifRefus.DoublonPatient => (StatusCodes.Status409Conflict, "Le patient a déjà un rendez-vous ce jour-là chez ce praticien"),
            MotifRefus.CreneauPasse => (StatusCodes.Status422UnprocessableEntity, "Créneau passé"),
            MotifRefus.TropLointain => (StatusCodes.Status422UnprocessableEntity, "Créneau au-delà de l'horizon de réservation"),
            _ => (StatusCodes.Status422UnprocessableEntity, "Créneau hors planning"),
        };
        return Results.Problem(statusCode: statut, title: titre,
            extensions: new Dictionary<string, object?> { ["motif"] = motif.ToString() });
    }
}
