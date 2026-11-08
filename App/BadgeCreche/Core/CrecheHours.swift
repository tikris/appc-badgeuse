import Foundation

/// Créneaux d'arrivée et de départ pendant lesquels Wallet peut proposer le badge sur l'écran
/// verrouillé (`relevantDates` du pass, iOS 18 et plus ; ignoré par iOS 17).
///
/// Un pass qui a à la fois des dates et un lieu ne s'affiche que si les deux correspondent
/// (documentation Apple) : hors de ces créneaux, le badge ne s'affiche plus tout seul, même près
/// de la crèche (domicile voisin, passage le soir ou le week-end). Les dates sont absolues : le pass
/// couvre `horizonDays` jours et l'app le renouvelle quand on l'ouvre (voir BadgeStore).
nonisolated enum CrecheHours {
    /// Créneaux du lundi au vendredi, en minutes depuis minuit, heure de Paris.
    static let windows: [(start: Int, end: Int)] = [
        (7 * 60, 10 * 60 + 30),
        (15 * 60 + 30, 19 * 60 + 30),
    ]

    /// Environ six mois de créneaux par pass.
    static let horizonDays = 182

    /// Libellé des créneaux, pour l'app.
    static let summary = "en semaine, de 7 h à 10 h 30 et de 15 h 30 à 19 h 30"

    static let timeZone = TimeZone(identifier: "Europe/Paris")!

    /// Créneaux à venir (ou en cours) sur `days` jours à partir du jour de `now`.
    static func intervals(from now: Date, days: Int = horizonDays) -> [DateInterval] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        var result: [DateInterval] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            // 1 = dimanche, 7 = samedi.
            guard (2...6).contains(calendar.component(.weekday, from: day)) else { continue }
            for window in windows {
                guard
                    let start = calendar.date(bySettingHour: window.start / 60, minute: window.start % 60, second: 0, of: day),
                    let end = calendar.date(bySettingHour: window.end / 60, minute: window.end % 60, second: 0, of: day),
                    end > now
                else { continue }
                result.append(DateInterval(start: start, end: end))
            }
        }
        return result
    }

    /// Valeur de `relevantDates` : dates W3C avec le décalage horaire de Paris (heure d'été comprise).
    static func relevantDates(from now: Date, days: Int = horizonDays) -> [[String: String]] {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return intervals(from: now, days: days).map {
            ["startDate": formatter.string(from: $0.start), "endDate": formatter.string(from: $0.end)]
        }
    }
}
