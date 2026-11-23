using System.Reflection;
using Microsoft.Extensions.Options;
using Santinord.Rdv.Api;
using Santinord.Rdv.Domain;

var builder = WebApplication.CreateBuilder(args);

// Configuration validée au démarrage : une valeur aberrante (variable de pipeline mal
// réglée) arrête l'API tout de suite, avec un message clair dans le journal.
builder.Services.AddOptions<RdvOptions>()
    .Bind(builder.Configuration.GetSection(RdvOptions.Section))
    .Validate(o => o.DureeCreneauMinutes is >= 5 and <= 120,
        "Rdv:DureeCreneauMinutes doit être compris entre 5 et 120 minutes.")
    .ValidateOnStart();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton(sp =>
{
    var options = sp.GetRequiredService<IOptions<RdvOptions>>().Value;
    return new ReglesAgenda { DureeCreneauMinutes = options.DureeCreneauMinutes };
});
builder.Services.AddSingleton(sp => new Agenda(
    sp.GetRequiredService<ReglesAgenda>(),
    sp.GetRequiredService<TimeProvider>(),
    Referentiel.Praticiens));
builder.Services.AddProblemDetails();

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

// Sondes utilisées par les tests de fumée du pipeline après chaque déploiement.
app.MapGet("/sante", () => Results.Ok(new { statut = "ok" }));

app.MapGet("/version", (IOptions<RdvOptions> options) =>
{
    // InformationalVersion vaut « 1.4.27+<sha du commit> » quand le pipeline compile
    // avec -p:Version=$(Build.BuildNumber) dans un dépôt Git.
    var informationnelle = typeof(Program).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0";
    var morceaux = informationnelle.Split('+', 2);
    return Results.Ok(new InfosVersion(
        Version: morceaux[0],
        Commit: morceaux.Length > 1 ? morceaux[1][..Math.Min(8, morceaux[1].Length)] : "local",
        Environnement: options.Value.NomEnvironnement,
        Bandeau: options.Value.Bandeau));
});

var api = app.MapGroup("/api");

api.MapGet("/praticiens", (Agenda agenda) => agenda.Praticiens.OrderBy(p => p.Id));

api.MapGet("/creneaux", (string praticienId, DateOnly date, Agenda agenda) =>
    agenda.Praticiens.Any(p => p.Id == praticienId)
        ? Results.Ok(agenda.CreneauxLibres(praticienId, date))
        : Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Praticien inconnu"));

api.MapGet("/rendez-vous/{id:guid}", (Guid id, Agenda agenda) =>
    agenda.Trouver(id) is { } rendezVous ? Results.Ok(rendezVous) : Results.NotFound());

api.MapPost("/rendez-vous", (DemandeRendezVous demande, Agenda agenda, ILogger<Program> journal) =>
{
    if (string.IsNullOrWhiteSpace(demande.PatientId) || string.IsNullOrWhiteSpace(demande.PraticienId))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["patientId"] = ["L'identifiant patient et le praticien sont obligatoires."],
        });
    }

    var resultat = agenda.Reserver(demande.PraticienId, demande.PatientId, demande.Debut);
    if (resultat.RendezVous is { } rendezVous)
    {
        journal.LogInformation("Rendez-vous {Id} réservé chez {PraticienId} le {Debut:yyyy-MM-dd HH:mm}",
            rendezVous.Id, rendezVous.PraticienId, rendezVous.Debut);
        return Results.Created($"/api/rendez-vous/{rendezVous.Id}", rendezVous);
    }

    journal.LogWarning("Réservation refusée chez {PraticienId} le {Debut:yyyy-MM-dd HH:mm} : {Motif}",
        demande.PraticienId, demande.Debut, resultat.Motif);
    return Refus.EnReponse(resultat.Motif!.Value);
});

api.MapDelete("/rendez-vous/{id:guid}", (Guid id, Agenda agenda) => agenda.Annuler(id) switch
{
    ResultatAnnulation.Annule => Results.NoContent(),
    ResultatAnnulation.Introuvable => Results.NotFound(),
    _ => Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Annulation tardive",
        detail: "Un rendez-vous ne s'annule plus en ligne à moins de 24 heures ; contactez le secrétariat."),
});

app.Run();

// Rend la classe Program visible du projet de tests d'intégration (WebApplicationFactory<Program>).
public partial class Program;
