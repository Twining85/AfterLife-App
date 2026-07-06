//
//  NotificationService.swift
//  AfterLife
//
//  Created by René Engeler on 06.07.2026.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    private let dossierPruefungNotificationID = "jaehrliche-dossier-pruefung"
    
    func berechtigungAnfragen() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { erlaubt, fehler in
            if let fehler {
                print("Fehler bei Benachrichtigungs-Berechtigung: \(fehler.localizedDescription)")
                return
            }
            
            print("Benachrichtigungen erlaubt: \(erlaubt)")
        }
    }
    
    func jaehrlicheDossierPruefungPlanen(ab letztemPruefdatum: Date) {
        // TEST: Für den iPhone-Test bewusst auf 1 Minute gesetzt.
        // Für Produktion wieder auf `.year, value: 1` ändern.
        guard let erinnerungsDatum = Calendar.current.date(byAdding: .minute, value: 1, to: letztemPruefdatum) else {
            return
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dossierPruefungNotificationID]
        )
        
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Jährliche Prüfung fällig"
        inhalt.body = "Nimm dir kurz Zeit und prüfe, ob dein Vorsorge-Dossier noch aktuell ist."
        inhalt.sound = .default
        
        let datumKomponenten = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: erinnerungsDatum
        )
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: datumKomponenten,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: dossierPruefungNotificationID,
            content: inhalt,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { fehler in
            if let fehler {
                print("Fehler beim Planen der Dossier-Prüfung: \(fehler.localizedDescription)")
            } else {
                print("Dossier-Prüfung geplant für: \(erinnerungsDatum)")
            }
        }
    }
    
    func jaehrlicheDossierPruefungEntfernen() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dossierPruefungNotificationID]
        )
    }
}
