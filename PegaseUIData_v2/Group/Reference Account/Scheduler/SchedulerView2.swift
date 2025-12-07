//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 23/05/2025.
//

import AppKit
import SwiftUI
import SwiftDate
import SwiftData

private enum UpdateTrigger {
    case dateDebut
    case frequencyCount
    case occurrence
    case frequencyType
}

// Vue pour la boîte de dialogue d'ajout
struct SchedulerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: SchedulerManager
    
    @Binding var isPresented: Bool
    @Binding var isModeCreate: Bool
    
    @State var scheduler: EntitySchedule?
    
    @State private var amount: String = ""
    @State private var dateValeur: Date = Date()
    @State private var dateDebut: Date = Date()
    @State private var dateFin: Date = Date()
    @State private var frequence: String = ""
    @State private var libelle: String = ""
    @State private var nextOccurrence: String = ""
    @State private var occurrence: String = ""
    @State private var frequency: String = ""
    
    @State private var entityPaymentMode : [EntityPaymentMode] = []
    @State private var entityRubric      : [EntityRubric]      = []
    @State private var entityCategorie   : [EntityCategory]    = []
    @State private var frequenceType     : [String]    = []
    
    @State var selectedRubric   : EntityRubric?
    @State var selectedCategory : EntityCategory?
    @State var selectedTypeIndex = 0
    @State var selectedMode     : EntityPaymentMode?
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            schedulerDateFields
            schedulerTextFields
            schedulerPickers
        }
        .frame(width: 300)
        .padding()
        .navigationTitle(scheduler == nil ? String(localized: "New scheduler", table: "Scheduler") : String(localized: "Edit scheduler", table: "Scheduler"))
        .background(.white)
        .onChange(of: scheduler) { oldValue, newValue in
            printTag("scheduler a changé : \(oldValue?.libelle ?? "nil") -> \(newValue?.libelle ?? "nil")")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", table: "Scheduler")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", table: "Scheduler")) {
                    save()
                    dismiss()
                }
            }
        }
        .onAppear {
            guard let account = CurrentAccountManager.shared.getAccount() else {
                printTag("Erreur : aucun compte courant trouvé.")
                return
            }
            frequenceType = [
                String(localized :"Day",table : "Account"),
                String(localized :"Week",table : "Account"),
                String(localized :"Month",table : "Account"),
                String(localized :"Year",table : "Account")]
            
            let entityPreference = PreferenceManager.shared.getAllData(for: account)
            entityPaymentMode = PaymentModeManager.shared.getAllData()
            entityRubric = RubricManager.shared.getAllData()
            
            if let scheduler = scheduler {
                //                scheduler.account = currentAccount
                amount = String(scheduler.amount)
                dateValeur = scheduler.dateValeur
                dateDebut = scheduler.dateDebut
                dateFin = scheduler.dateFin
                frequence = String(scheduler.frequence)
                libelle = scheduler.libelle
                nextOccurrence = String(scheduler.nextOccurrence)
                occurrence = String(scheduler.occurrence)
                frequency = String(scheduler.frequence)
                
                selectedMode = scheduler.paymentMode
                selectedCategory = scheduler.category
                selectedRubric = scheduler.category?.rubric
                selectedTypeIndex = Int(scheduler.typeFrequence)
                
            } else {
                //                account = scheduler.account!
                amount = String(scheduler?.amount ?? 0.0)
                dateValeur = Date().noon
                dateDebut = Date().noon
                dateFin = Date().noon + 12.months
                frequence = "2"
                libelle = ""
                nextOccurrence = "1"
                occurrence = "12"
                frequency = "1"
                
                selectedMode = entityPreference?.paymentMode
                selectedRubric = entityPreference?.category?.rubric
                selectedCategory = entityPreference!.category
                selectedTypeIndex = 2
            }
        }
        .onDisappear {
            entityPaymentMode.removeAll()
            entityRubric.removeAll()
            entityCategorie.removeAll()
        }
    }
    
    private var schedulerDateFields: some View {
        Group {
            HStack {
                Text(String(localized: "Start Date", table: "Scheduler")).frame(width: 100, alignment: .leading)
                DatePicker("", selection: $dateDebut, displayedComponents: .date)
            }
            HStack {
                Text(String(localized: "Value Date", table: "Scheduler")).frame(width: 100, alignment: .leading)
                DatePicker("", selection: $dateValeur, displayedComponents: .date)
            }
            HStack {
                Text(String(localized: "End Date", table: "Scheduler")).frame(width: 100, alignment: .leading)
                DatePicker("", selection: .constant(dateFin), displayedComponents: .date)
                    .disabled(true)
            }
        }
        .onChange(of: dateDebut) { old, newValue in
            update(.dateDebut)
        }
    }

    private var schedulerTextFields: some View {
        Group {
            HStack {
                Text(String(localized: "Occurrence", table: "Scheduler")).frame(width: 100, alignment: .leading)
                TextField(String(localized: "Occurrence", table: "Scheduler"), text: $occurrence)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text(String(localized: "Next occurrence", table: "Scheduler")).frame(width: 100, alignment: .leading)
                TextField(String(localized: "Next occurrence", table: "Scheduler"), text: $nextOccurrence)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
            }
            HStack {
                Text(String(localized: "Comment", table: "Scheduler")).frame(width: 100, alignment: .leading)
                TextField(String(localized: "Comment", table: "Scheduler"), text: $libelle)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text(String(localized: "Amount", table: "Scheduler")).frame(width: 100, alignment: .leading)
                TextField(String(localized: "Amount", table: "Scheduler"), text: $amount)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .onChange(of: occurrence) { _, _ in update(.occurrence) }
    }

    private var schedulerPickers: some View {
        Group {
            HStack {
                Text(String(localized: "Frequency", table: "Scheduler")).frame(width: 100, alignment: .leading)
                TextField("", text: $frequency)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $selectedTypeIndex) {
                    ForEach(0..<frequenceType.count, id: \.self) { index in
                        Text(frequenceType[index]).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .onChange(of: selectedTypeIndex) { _, _ in update(.frequencyType) }
            .onChange(of: frequency) { _, _ in update(.frequencyCount) }

            HStack {
                Text(String(localized: "Mode", table: "Scheduler")).frame(width: 100, alignment: .leading)
                Picker("", selection: $selectedMode) {
                    ForEach(entityPaymentMode, id: \.self) {
                        Text($0.name).tag($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            HStack {
                Text(String(localized: "Rubric", table: "Scheduler")).frame(width: 100, alignment: .leading)
                Picker("", selection: $selectedRubric) {
                    ForEach(entityRubric, id: \.self) {
                        Text($0.name).tag($0 as EntityRubric?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .onChange(of: selectedRubric) { _, newRubric in
                if let newRubric = newRubric {
                    entityCategorie = newRubric.categorie.sorted { $0.name < $1.name }
                    if let selected = selectedCategory,
                       !entityCategorie.contains(where: { $0 == selected }) {
                        selectedCategory = entityCategorie.first
                    }
                } else {
                    entityCategorie = []
                    selectedCategory = nil
                }
            }

            HStack {
                Text(String(localized: "Category", table: "Scheduler")).frame(width: 100, alignment: .leading)
                Picker("", selection: $selectedCategory) {
                    ForEach(entityCategorie, id: \.self) {
                        Text($0.name).tag($0 as EntityCategory?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private func update(_ trigger: UpdateTrigger) {
        
        let numOccurrence = Int(occurrence) ?? 1
        let numFrequence = Int(frequency) ?? 1
        let nombre = (numFrequence * numOccurrence) - (numFrequence )
        
        switch trigger {
        case .dateDebut, .frequencyCount, .occurrence, .frequencyType:
            
            switch selectedTypeIndex {
            case 0:
                dateFin = dateDebut + nombre.days
            case 1:
                dateFin = dateDebut + nombre.weeks
            case 2:
                dateFin = dateDebut + nombre.months
            case 3:
                dateFin = dateDebut + nombre.years
            default:
                dateFin = dateDebut + nombre.months
            }
        }
    }
    
    private func save() {
        
        var newItem: EntitySchedule?
        
        if let existingStatement = scheduler {
            newItem = existingStatement
        } else {
            newItem = EntitySchedule()
            modelContext.insert(newItem!)
        }
        if let frequence = Int16(frequency),
           let nextOccurrence = Int16(nextOccurrence),
           let occurrence = Int16(occurrence),
           let frequencyType = Int16(exactly: selectedTypeIndex),
           let amount = Double(amount) {
            
            newItem?.amount = amount
            newItem?.dateValeur = dateValeur.noon
            newItem?.dateDebut = dateDebut.noon
            newItem?.dateFin = dateFin.noon
            newItem?.frequence = frequence
            newItem?.libelle = libelle
            newItem?.nextOccurrence = nextOccurrence
            newItem?.occurrence = occurrence
            newItem?.typeFrequence = Int16(frequencyType)
            
            newItem?.paymentMode = selectedMode
            newItem?.category = selectedCategory
            
            newItem?.account = CurrentAccountManager.shared.getAccount()!
            
            try? modelContext.save()
            let allSchedulers = SchedulerManager.shared.getAllData()!
            dataManager.schedulers = allSchedulers
            if let last = allSchedulers.sorted(by: { $0.dateValeur < $1.dateValeur }).last {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    dataManager.selectScheduler(last)
                }
            }
            NotificationManager.shared.scheduleReminder(for: newItem!)
            scheduler = nil
            newItem = nil

        }
    }
}

