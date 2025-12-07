//
//  ListTransactions1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 26/02/2025.
//

import SwiftUI
import SwiftData


struct GradientText: View {
    var text: String
    var gradientImage: NSImage? {
        NSImage(named: NSImage.Name("Gradient"))
    }
    
    var body: some View {
        Text(text)
            .font(.custom("Silom", size: 16))
            .background(LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.7)]), startPoint: .top, endPoint: .bottom))
    }
}

//Statut de l'opération : Prévu, Engagé, Pointé. Vous pouvez utiliser le clavier pour choisir la valeur en tapant P pour Prévu, E pour Engagé et T pour Pointé.
// Lorsque le statut est Prévu ou Engagé, la date de pointage est estimée et le montant est modifiable.
// Lorsque le statut est Pointé, la date de pointage doit être celle indiquée sur le relevé et le montant n'est plus modifiable.

struct SummaryView: View {
    @Binding var dashboard: DashboardState
    
    var body: some View {
        HStack(spacing: 0) {
            
            VStack {
                Text("Final balance")
                Text(String(format: "%.2f €", dashboard.planned))
                    .font(.title)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.1), Color.cyan.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
            .border(Color.black, width: 1)

            VStack {
                Text("Actual balance")
                Text(String(format: "%.2f €", dashboard.engaged))
                    .font(.title)
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.1), Color.cyan.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
            .border(Color.black, width: 1)
            
            VStack {
                Text("Bank balance")
                Text(String(format: "%.2f €", dashboard.executed))
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.1), Color.cyan.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
            .border(Color.black, width: 1)

        }
        .frame(maxWidth: .infinity)
    }
}

// Représente un regroupement par année.
struct TransactionsByYear100: Identifiable {
    let id = UUID()
    let year: String
    let months: [TransactionsByMonth100]
}

// Représente un groupe de transactions d'un mois précis (par exemple 2023-02).
struct TransactionsByMonth100: Identifiable {
    let id = UUID()
    let year: String
    let month: Int
    let transactions: [EntityTransaction]
    
    /// Formatage mois (ex: "Février")
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR") // ou "en_US" etc.
        formatter.dateFormat = "LLLL" // nom du mois
        if let transaction = transactions.first {
            let date = transaction.datePointage
            return formatter.string(from: date).capitalized
        }
        return "Mois Inconnu"
    }

    /// Calcul du total du mois
    var totalAmount: Double {
        transactions.reduce(0.0) { $0 + $1.amount }
    }
}

struct YearMonth: Hashable {
    let year: String
    let month: Int
}

func groupTransactionsByYear(transactions: [EntityTransaction]) -> [TransactionsByYear100] {
    // Dictionnaire [year: [TransactionsByMonth]]
    var dictionaryByYear: [String: [TransactionsByMonth100]] = [:]

    // Dictionnaire [YearMonth : [EntityTransactions]]
    var yearMonthDict: [YearMonth: [EntityTransaction]] = [:]

    for transaction in transactions {
        guard let yearString = transaction.sectionYear else { continue }
        let datePointage = transaction.datePointage
        let calendar = Calendar.current
        let month = calendar.component(.month, from: datePointage)

        let key = YearMonth(year: yearString, month: month)
        yearMonthDict[key, default: []].append(transaction)
    }

    // Convertir yearMonthDict → dictionaryByYear
    for (yearMonth, trans) in yearMonthDict {
        let byMonth = TransactionsByMonth100(year: yearMonth.year, month: yearMonth.month, transactions: trans)
        dictionaryByYear[yearMonth.year, default: []].append(byMonth)
    }

    // Construire un tableau de TransactionsByYear100
    var result: [TransactionsByYear100] = []
    for (year, monthsArray) in dictionaryByYear {
        // Trier les mois par ordre croissant
        let sortedMonths = monthsArray.sorted { $0.month > $1.month }
        result.append(TransactionsByYear100(year: year, months: sortedMonths))
    }

    // Trier par année décroissante (ou croissante)
    return result.sorted { $0.year > $1.year }
}
