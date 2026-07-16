import Foundation
import SwiftUI

enum VorsorgeStatus: Equatable {
    case unvollstaendig
    case bereitZurPruefung
    case geprueft
    case dossierErstellt
    case einladungOffen
    case vertrauenspersonAktiv
    case aktualisierungNoetig

    var titel: String {
        switch self {
        case .unvollstaendig: "Deine Vorsorge wächst"
        case .bereitZurPruefung: "Dein Dossier ist bereit zur Prüfung"
        case .geprueft: "Alles geprüft"
        case .dossierErstellt: "Dein Vorsorgedossier ist bereit"
        case .einladungOffen: "Einladung ausstehend"
        case .vertrauenspersonAktiv: "Deine Vorsorge ist vorbereitet"
        case .aktualisierungNoetig: "Dein Dossier wurde geändert"
        }
    }

    var beschreibung: String {
        switch self {
        case .unvollstaendig: "Noch einige Angaben fehlen."
        case .bereitZurPruefung: "Kontrolliere deine Angaben."
        case .geprueft: "Erstelle jetzt dein Vorsorgedossier."
        case .dossierErstellt: "Bestimme jetzt eine Vertrauensperson."
        case .einladungOffen: "Deine Vertrauensperson hat die Einladung noch nicht angenommen."
        case .vertrauenspersonAktiv: "Dossier aktuell und Vertrauensperson hinterlegt."
        case .aktualisierungNoetig: "Prüfe die neuen Angaben und aktualisiere den Export."
        }
    }

    var buttonTitel: String {
        switch self {
        case .unvollstaendig: "Vorsorge weiterführen"
        case .bereitZurPruefung: "Dossier prüfen"
        case .geprueft: "Dossier erstellen"
        case .dossierErstellt: "Vertrauensperson festlegen"
        case .einladungOffen: "Einladung anzeigen"
        case .vertrauenspersonAktiv: "Vorsorge verwalten"
        case .aktualisierungNoetig: "Änderungen prüfen"
        }
    }
}

struct VorsorgeStatusService {
    static func berechne(
        vollstaendigkeit: Double,
        wurdeGeprueft: Bool,
        letzterExportAm: Date?,
        letzteInhaltlicheAenderungAm: Date?,
        hatOffeneEinladung: Bool,
        hatAktiveVertrauensperson: Bool
    ) -> VorsorgeStatus {
        if let letzterExportAm,
           let letzteInhaltlicheAenderungAm,
           letzteInhaltlicheAenderungAm > letzterExportAm {
            return .aktualisierungNoetig
        }
        if hatAktiveVertrauensperson { return .vertrauenspersonAktiv }
        if hatOffeneEinladung { return .einladungOffen }
        if letzterExportAm != nil { return .dossierErstellt }
        if wurdeGeprueft { return .geprueft }
        if vollstaendigkeit >= 0.7 { return .bereitZurPruefung }
        return .unvollstaendig
    }
}

struct VorsorgeStatusCard: View {
    let status: VorsorgeStatus
    let fortschritt: Double
    let letztePruefung: Date?
    let vertrauenspersonen: Int
    let akzentFarbe: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().stroke(akzentFarbe.opacity(0.13), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: min(max(fortschritt, 0), 1))
                        .stroke(akzentFarbe, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((fortschritt * 100).rounded()))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text(status.titel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(status.beschreibung)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                if let letztePruefung {
                    Label(letztePruefung.formatted(.dateTime.locale(Locale(identifier: "de_CH")).day().month().year()), systemImage: "checkmark.seal.fill")
                }
                if vertrauenspersonen > 0 {
                    Label("\(vertrauenspersonen)", systemImage: "person.2.fill")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Button(action: action) {
                HStack {
                    Text(status.buttonTitel).font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(akzentFarbe))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.systemBackground).opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.78)))
        .shadow(color: akzentFarbe.opacity(0.11), radius: 14, x: 0, y: 7)
    }
}
