import SwiftUI
import SwiftData
import Combine
import Observation


// Gestionnaire de préférences des transactions
final class PreferenceDataManager: ObservableObject {
    @Published var currentAccount: EntityAccount?
    @Published var preferencePreferenceID: PersistentIdentifier?
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    
    func resolvePreference() -> EntityPreference? {
        guard let id = preferencePreferenceID, let context = modelContext else { return nil }
        return context.model(for: id) as? EntityPreference
    }

    func saveChanges() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)", flag: true)
        }
    }
}

// Vue permettant de modifier les préférences de transactions pour un compte
struct PreferenceTransactionView: View {

    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var dataManager: PreferenceDataManager
    
    @State private var entityRubric      : [EntityRubric]      = []
    @State private var entityCategorie   : [EntityCategory]    = []
    @State private var entityPaymentMode : [EntityPaymentMode] = []
    @State private var entityStatus      : [EntityStatus]      = []
    
    @State var selectedStatus: EntityStatus? = nil
    @State var selectedMode: EntityPaymentMode? = nil

    @State var selectedStatusID   : PersistentIdentifier?
    @State var selectedRubricID   : PersistentIdentifier?
    @State var selectedCategoryID : PersistentIdentifier?
    @State var selectedModeID     : PersistentIdentifier?
    
    @State private var isExpanded = false // Indicateur pour l'état de sélection du signe
    @State private var groupCarteBancaire = false // Option regroupement CB (carte débit différé)
    @State var changeCounter = 0

    private func resolveStatus() -> EntityStatus? {
        return selectedStatus
    }
    private func resolveRubric() -> EntityRubric? {
        guard let id = selectedRubricID, let context = dataManager.modelContext else { return nil }
        return context.model(for: id) as? EntityRubric
    }
    private func resolveCategory() -> EntityCategory? {
        guard let id = selectedCategoryID, let context = dataManager.modelContext else { return nil }
        return context.model(for: id) as? EntityCategory
    }
    private func resolveMode() -> EntityPaymentMode? {
//        guard let id = selectedModeID, let context = dataManager.modelContext else { return nil }
//        return context.model(for: id) as? EntityPaymentMode
        return selectedMode
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Default values ​​for transactions for this account.", tableName: "SettingsView")
                .font(.headline)
                .padding(.top)

            // Sélection des préférences
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    FormField(label: String(localized: "Status", table: "SettingsView")) {
                        StatusPickerView(
                            statuses: entityStatus,
                            selectedStatus: $selectedStatus
                        )
                    }

                    FormField(label: String(localized: "Mode", table: "SettingsView")) {
                        PaymentModePickerView(
                            paymentModes: entityPaymentMode,
                            selectedMode: $selectedMode
                        )
                    }

                }

                VStack(alignment: .leading) {
                    Picker(String(localized: "Rubric", table: "SettingsView"), selection: $selectedRubricID) {
                        ForEach(entityRubric, id: \.self) {
                            Text($0.name).tag($0.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedRubricID) { _, newID in
                        if let id = newID, let newRubric = entityRubric.first(where: { $0.persistentModelID == id }) {
                            entityCategorie = newRubric.categorie.sorted { $0.name < $1.name }
                            if let currentCatID = selectedCategoryID,
                               !entityCategorie.contains(where: { $0.persistentModelID == currentCatID }) {
                                selectedCategoryID = entityCategorie.first?.persistentModelID
                            }
                        } else {
                            entityCategorie = []
                            selectedCategoryID = nil
                        }
                    }

                    Picker(String(localized: "Category", table: "SettingsView"), selection: $selectedCategoryID) {
                        ForEach(entityCategorie, id: \.self) {
                            Text($0.name).tag($0.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .frame(width: 600)

            // Sélection du signe par une icône
            HStack {
                Text("Default sign", tableName: "SettingsView")
                ZStack {
                    Rectangle()
                        .fill(isExpanded ? Color.red : Color.green)
                        .frame(width: 30, height: 30)

                    Image(systemName: isExpanded ? "minus" : "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                .onTapGesture {
                    isExpanded.toggle()
                }
            }
            .padding(.bottom)

            // Option regroupement Carte Bancaire (pour cartes à débit différé)
            Toggle(isOn: $groupCarteBancaire) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("Group credit card transactions", tableName: "SettingsView")
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal)
            .help(String(localized: "Activate this option if you have a deferred debit card to group your credit card transactions by month.", table: "SettingsView"))

            Spacer()
        }
        .onAppear {
            Task {
                try await configureFormState()
                if let account = currentAccountManager.getAccount() {
                    dataManager.currentAccount = account
                    try await refreshData(for: account)
                }
            }
        }
        
        .onDisappear {
            Task { @MainActor in
                guard let _ = dataManager.modelContext,
                      currentAccountManager.getAccount() != nil else { return }
                guard let status = resolveStatus(),
                      let mode = resolveMode(),
                      let rubric = resolveRubric(),
                      let category = resolveCategory(),
                      let preference = dataManager.resolvePreference() else { return }
                await updatePreference(status: status,
                                       mode: mode,
                                       rubric: rubric,
                                       category: category,
                                       preference: preference,
                                       sign: isExpanded)
                entityRubric.removeAll()
                entityCategorie.removeAll()
                entityPaymentMode.removeAll()
                entityStatus.removeAll()
            }
        }
        
        .onChange(of: currentAccountManager.getAccount()) { _, newAccount in
            changeCounter += 1
            Task { @MainActor in
//                guard let context = dataManager.modelContext else { return }

                // Si le compte devient nil, vider l'état local et arrêter
                guard let account = newAccount else {
                    entityStatus = []
                    entityPaymentMode = []
                    entityRubric = []
                    entityCategorie = []
                    selectedStatusID = nil
                    selectedModeID = nil
                    selectedRubricID = nil
                    selectedCategoryID = nil
                    dataManager.preferencePreferenceID = nil
                    return
                }

                // Tenter de sauvegarder l'état précédent si tout est résoluble
                if let status = resolveStatus(),
                   let mode = resolveMode(),
                   let rubric = resolveRubric(),
                   let category = resolveCategory(),
                   let preference = dataManager.resolvePreference() {
                    await updatePreference(status: status,
                                           mode: mode,
                                           rubric: rubric,
                                           category: category,
                                           preference: preference,
                                           sign: isExpanded)
                }

                // Basculer sur le nouveau compte et recharger
                dataManager.preferencePreferenceID = nil
                dataManager.currentAccount = account
                try await refreshData(for: account)
            }
        }
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }
    
    // Fonction de mise à jour des préférences
    @MainActor
    func updatePreference(status: EntityStatus,
                          mode: EntityPaymentMode,
                          rubric: EntityRubric,
                          category: EntityCategory,
                          preference: EntityPreference,
                          sign: Bool) async {
        // Mettre à jour l'option CB
        preference.groupCarteBancaire = groupCarteBancaire

        Task {
            try await PreferenceManager.shared.update(status: status,
                                                       mode: mode,
                                                       rubric: rubric,
                                                       category: category,
                                                       preference: preference,
                                                       sign: sign)
        }
    }
    
    // Configuration initiale du formulaire
    func configureFormState() async throws {
        guard DataContext.shared.context != nil else { return }

        let modes = PaymentModeManager.shared.getAllData()
        entityPaymentMode = modes
        
        if let account = CurrentAccountManager.shared.getAccount() {
            let status = StatusManager.shared.getAllData(for: account)
            entityStatus = status
            
        } else {
            entityStatus = []
            entityPaymentMode = []
        }
    }

    // Rafraîchir les données du formulaire
    private func refreshData(for account: EntityAccount) async throws {
        guard DataContext.shared.context != nil else { return }
        let pref = PreferenceManager.shared.getAllData()
        dataManager.preferencePreferenceID = pref?.persistentModelID
        guard let entityPreference = pref else { 
            // Si pas de préférence, nettoyer les sélections
            selectedStatusID = nil
            selectedModeID = nil
            selectedRubricID = nil
            selectedCategoryID = nil
            isExpanded = false
            
            entityStatus = StatusManager.shared.getAllData(for: account)
            entityPaymentMode = PaymentModeManager.shared.getAllData()
            entityRubric = RubricManager.shared.getAllData()
            entityCategorie = []
            return 
        }
        
        selectedStatusID = entityPreference.status?.persistentModelID
        selectedStatus = entityPreference.status

        selectedModeID = entityPreference.paymentMode?.persistentModelID
        selectedMode = entityPreference.paymentMode

        selectedRubricID = entityPreference.category?.rubric?.persistentModelID
        selectedCategoryID = entityPreference.category?.persistentModelID
        isExpanded = entityPreference.signe
        groupCarteBancaire = entityPreference.groupCarteBancaire
        
        entityStatus = StatusManager.shared.getAllData(for: account)
        entityPaymentMode = PaymentModeManager.shared.getAllData()
        entityRubric = RubricManager.shared.getAllData()
        if let rubric = entityPreference.category?.rubric {
            entityCategorie = rubric.categorie
        } else {
            entityCategorie = []
        }
    }
}

