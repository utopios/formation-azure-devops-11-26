namespace Santinord.Rdv.Domain;

/// <summary>
/// L'agenda des praticiens : calcule les créneaux libres, réserve et annule.
/// Stockage en mémoire : le fil rouge s'intéresse à la chaîne de livraison, pas à la persistance.
/// </summary>
public sealed class Agenda(ReglesAgenda regles, TimeProvider horloge, IEnumerable<Praticien> praticiens)
{
    private readonly Dictionary<string, Praticien> _praticiens = praticiens.ToDictionary(p => p.Id);
    private readonly List<RendezVous> _rendezVous = [];
    private readonly Lock _verrou = new();

    public IReadOnlyCollection<Praticien> Praticiens => _praticiens.Values;

    private DateTime Maintenant => horloge.GetLocalNow().DateTime;

    /// <summary>Les débuts de créneaux prévus au planning pour un jour donné, réservés ou non.</summary>
    public IEnumerable<DateTime> Grille(DateOnly jour)
    {
        TimeOnly? fermeture = jour.DayOfWeek switch
        {
            DayOfWeek.Sunday => null,
            DayOfWeek.Saturday => regles.FermetureSamedi,
            _ => regles.FermetureSemaine,
        };
        if (fermeture is null)
        {
            yield break;
        }

        var debut = jour.ToDateTime(regles.Ouverture);
        var fin = jour.ToDateTime(fermeture.Value);
        for (var creneau = debut; creneau.AddMinutes(regles.DureeCreneauMinutes) <= fin;
             creneau = creneau.AddMinutes(regles.DureeCreneauMinutes))
        {
            yield return creneau;
        }
    }

    /// <summary>Les créneaux encore réservables d'un praticien pour un jour donné.</summary>
    public IReadOnlyList<DateTime> CreneauxLibres(string praticienId, DateOnly jour)
    {
        lock (_verrou)
        {
            var pris = _rendezVous
                .Where(r => r.PraticienId == praticienId && DateOnly.FromDateTime(r.Debut) == jour)
                .Select(r => r.Debut)
                .ToHashSet();
            return Grille(jour).Where(c => c > Maintenant && !pris.Contains(c)).ToList();
        }
    }

    public ResultatReservation Reserver(string praticienId, string patientId, DateTime debut)
    {
        if (!_praticiens.ContainsKey(praticienId))
        {
            return ResultatReservation.Refus(MotifRefus.PraticienInconnu);
        }

        if (debut <= Maintenant)
        {
            return ResultatReservation.Refus(MotifRefus.CreneauPasse);
        }

        if (debut > Maintenant.AddDays(regles.HorizonReservationJours))
        {
            return ResultatReservation.Refus(MotifRefus.TropLointain);
        }

        var jour = DateOnly.FromDateTime(debut);
        if (!Grille(jour).Contains(debut))
        {
            return ResultatReservation.Refus(MotifRefus.HorsPlanning);
        }

        lock (_verrou)
        {
            if (_rendezVous.Any(r => r.PraticienId == praticienId && r.Debut == debut))
            {
                return ResultatReservation.Refus(MotifRefus.CreneauDejaPris);
            }

            // Un patient ne prend qu'un rendez-vous par jour chez un même praticien.
            if (_rendezVous.Any(r => r.PraticienId == praticienId
                                     && r.PatientId == patientId
                                     && DateOnly.FromDateTime(r.Debut) == jour))
            {
                return ResultatReservation.Refus(MotifRefus.DoublonPatient);
            }

            var rendezVous = new RendezVous(Guid.NewGuid(), praticienId, patientId, debut, regles.DureeCreneauMinutes);
            _rendezVous.Add(rendezVous);
            return ResultatReservation.Ok(rendezVous);
        }
    }

    public RendezVous? Trouver(Guid id)
    {
        lock (_verrou)
        {
            return _rendezVous.FirstOrDefault(r => r.Id == id);
        }
    }

    public ResultatAnnulation Annuler(Guid id)
    {
        lock (_verrou)
        {
            var rendezVous = _rendezVous.FirstOrDefault(r => r.Id == id);
            if (rendezVous is null)
            {
                return ResultatAnnulation.Introuvable;
            }

            if (rendezVous.Debut - Maintenant < TimeSpan.FromHours(regles.DelaiAnnulationHeures))
            {
                return ResultatAnnulation.AnnulationTardive;
            }

            _rendezVous.Remove(rendezVous);
            return ResultatAnnulation.Annule;
        }
    }
}
