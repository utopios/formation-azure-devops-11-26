namespace Santinord.Rdv.Domain;

/// <summary>Les praticiens des trois centres (données fictives du fil rouge).</summary>
public static class Referentiel
{
    public static IReadOnlyList<Praticien> Praticiens { get; } =
    [
        new("DR-LV-01", "Dr Anne Leroy", "Médecine générale", "Lille-Vauban"),
        new("DR-LV-02", "Dr Mehdi Saïdi", "Pédiatrie", "Lille-Vauban"),
        new("DR-RG-01", "Dr Sophie Delattre", "Dermatologie", "Roubaix-Gare"),
        new("DR-RG-02", "Dr Paul Verbeke", "Médecine générale", "Roubaix-Gare"),
        new("DR-VA-01", "Dr Julie Caron", "Ophtalmologie", "Villeneuve-d'Ascq-Pont-de-Bois"),
        new("DR-VA-02", "Dr Nadia Haddad", "Kinésithérapie", "Villeneuve-d'Ascq-Pont-de-Bois"),
    ];
}
