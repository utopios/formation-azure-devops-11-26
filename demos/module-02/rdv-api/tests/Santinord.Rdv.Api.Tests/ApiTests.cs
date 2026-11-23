using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace Santinord.Rdv.Api.Tests;

/// <summary>Horloge figée au lundi 23 novembre 2026, 9 h.</summary>
internal sealed class HorlogeFixe : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => new(2026, 11, 23, 9, 0, 0, TimeSpan.Zero);

    public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;
}

/// <summary>Héberge l'API en mémoire (aucun port ouvert) avec une horloge et un environnement de test.</summary>
public sealed class ApiRdv : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("Rdv:NomEnvironnement", "Tests");
        builder.ConfigureServices(services => services.AddSingleton<TimeProvider>(new HorlogeFixe()));
    }
}

public class ApiTests(ApiRdv api) : IClassFixture<ApiRdv>
{
    private readonly HttpClient _client = api.CreateClient();

    // Chaque test réserve un créneau différent : l'agenda est partagé par la fixture.
    private static object Demande(string heure, string patient = "P-104233", string praticien = "DR-RG-02") =>
        new { praticienId = praticien, patientId = patient, debut = $"2026-11-25T{heure}:00" };

    [Fact]
    public async Task La_sonde_de_sante_repond()
    {
        var reponse = await _client.GetAsync("/sante");

        Assert.Equal(HttpStatusCode.OK, reponse.StatusCode);
    }

    [Fact]
    public async Task La_version_indique_l_environnement()
    {
        var version = await _client.GetFromJsonAsync<JsonElement>("/version");

        Assert.Equal("Tests", version.GetProperty("environnement").GetString());
        Assert.False(string.IsNullOrEmpty(version.GetProperty("version").GetString()));
    }

    [Fact]
    public async Task Les_six_praticiens_sont_listes()
    {
        var praticiens = await _client.GetFromJsonAsync<JsonElement[]>("/api/praticiens");

        Assert.Equal(6, praticiens!.Length);
    }

    [Fact]
    public async Task Les_creneaux_d_un_praticien_inconnu_renvoient_404()
    {
        var reponse = await _client.GetAsync("/api/creneaux?praticienId=DR-XX-99&date=2026-11-24");

        Assert.Equal(HttpStatusCode.NotFound, reponse.StatusCode);
    }

    [Fact]
    public async Task Reserver_renvoie_201_et_l_adresse_du_rendez_vous()
    {
        var reponse = await _client.PostAsJsonAsync("/api/rendez-vous", Demande("08:00"));

        Assert.Equal(HttpStatusCode.Created, reponse.StatusCode);
        var detail = await _client.GetAsync(reponse.Headers.Location);
        Assert.Equal(HttpStatusCode.OK, detail.StatusCode);
    }

    [Fact]
    public async Task Reserver_un_creneau_deja_pris_renvoie_409()
    {
        await _client.PostAsJsonAsync("/api/rendez-vous", Demande("09:00", "P-300001"));

        var reponse = await _client.PostAsJsonAsync("/api/rendez-vous", Demande("09:00", "P-300002"));

        Assert.Equal(HttpStatusCode.Conflict, reponse.StatusCode);
    }

    [Fact]
    public async Task Reserver_un_creneau_passe_renvoie_422()
    {
        var reponse = await _client.PostAsJsonAsync("/api/rendez-vous",
            new { praticienId = "DR-RG-02", patientId = "P-104233", debut = "2026-11-20T10:00:00" });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, reponse.StatusCode);
    }

    [Fact]
    public async Task Reserver_sans_patient_renvoie_400()
    {
        var reponse = await _client.PostAsJsonAsync("/api/rendez-vous", Demande("10:00", patient: ""));

        Assert.Equal(HttpStatusCode.BadRequest, reponse.StatusCode);
    }

    [Fact]
    public async Task Annuler_renvoie_204_puis_le_rendez_vous_n_existe_plus()
    {
        var creation = await _client.PostAsJsonAsync("/api/rendez-vous", Demande("11:00", "P-400001"));

        var annulation = await _client.DeleteAsync(creation.Headers.Location);

        Assert.Equal(HttpStatusCode.NoContent, annulation.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(creation.Headers.Location)).StatusCode);
    }
}
