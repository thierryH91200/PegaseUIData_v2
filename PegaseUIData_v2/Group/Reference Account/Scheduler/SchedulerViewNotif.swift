//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 23/05/2025.
//

import AppKit
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let didSelectScheduler = Notification.Name("didSelectScheduler")
}

// MARK: - NotificationManager
class NotificationManager {
    static let shared = NotificationManager()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { accordee, error in
            if let error = error {
                printTag("Notification permission error: \(error.localizedDescription)")
            } else {
                printTag("Notification permission granted: \(accordee)")
            }
        }
    }
    
    func scheduleReminder(for scheduler: EntitySchedule) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Upcoming Schedule", table: "Scheduler")
        let bodyFormat = String(localized: "Reminder: %@ is due soon.", table: "Scheduler")
        content.body = String(format: bodyFormat, scheduler.libelle)
        content.sound = .default
        
        let triggerDate = scheduler.dateValeur.addingTimeInterval(-86400) // 1 day before
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: scheduler.uuid.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelReminder(for scheduler: EntitySchedule) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [scheduler.uuid.uuidString])
    }
}

struct UpcomingRemindersView: View {
        
    let upcoming: [EntitySchedule]
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(String(localized: "🔔 Upcoming Reminders", table: "Scheduler"))
                .font(.headline)
            
            let filteredUpcoming = upcoming
                .filter { !$0.isProcessed && $0.dateValeur >= Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.dateValeur < $1.dateValeur }
            
            if filteredUpcoming.isEmpty {
                Text(String(localized: "No scheduled operations.", table: "Scheduler"))
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(filteredUpcoming) { item in
                        HStack {
                            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: item.dateValeur).day ?? 0
                            let iconName = daysRemaining <= 1 ? "exclamationmark.triangle.fill" : "calendar"
                            let iconColor: Color = daysRemaining <= 1 ? .red : (daysRemaining <= 7 ? .orange : .green)
                            
                            Image(systemName: iconName)
                                .foregroundColor(iconColor)
                            
                            VStack(alignment: .leading) {
                                Text(item.libelle)
                                    .fontWeight(daysRemaining <= 1 ? .bold : .regular)
                                    .foregroundColor(daysRemaining <= 1 ? .red : .primary)
                                
                                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: item.dateValeur).day ?? 0
                                
                                let relativeLabel: String = {
                                    switch daysRemaining {
                                    case 0:
                                        return String(localized: "Today", table: "Scheduler")
                                    case 1:
                                        return String(localized: "Tomorrow", table: "Scheduler")
                                    case 2...6:
                                        let format = String(localized: "In %d days", table: "Scheduler")
                                        return String(format: format, daysRemaining)
                                    default:
                                        return ""
                                    }
                                }()
                                if !relativeLabel.isEmpty {
                                    Text(relativeLabel)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    let datePrefix = String(localized: "Date:", table: "Scheduler")
                                    Text("\(datePrefix) \(dateFormatter.string(from: item.dateValeur))")
                                        .font(.caption)
                                        .foregroundColor(daysRemaining <= 1 ? .red : (daysRemaining <= 3 ? .orange : .secondary))
                                }
                                Spacer()
                                
                                Text(String(format: "%.2f", item.amount))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onAppear {
                        for entitySchedule in upcoming {
                            SchedulerManager.shared.createTransaction(entitySchedule: entitySchedule)
                            NotificationManager.shared.cancelReminder(for: entitySchedule)
                            entitySchedule.isProcessed = true
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
        
        

