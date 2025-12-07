import SwiftUI
import SwiftData
import Combine


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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var dataManager: PreferenceDataManager
    
    @State private var entityRubric      : [EntityRubric]      = []
    @State private var entityCategorie   : [EntityCategory]    = []
    @State private var entityPaymentMode : [EntityPaymentMode] = []
    @State private var entityStatus      : [EntityStatus]      = []
    
    @State var selectedStatusID   : PersistentIdentifier?
    @State var selectedRubricID   : PersistentIdentifier?
    @State var selectedCategoryID : PersistentIdentifier?
    @State var selectedModeID     : PersistentIdentifier?
    
    @State private var isExpanded = false // Indicateur pour l'état de sélection du signe
    @State var changeCounter = 0

    private func resolveStatus() -> EntityStatus? {
        guard let id = selectedStatusID, let context = dataManager.modelContext else { return nil }
        return context.model(for: id) as? EntityStatus
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
        guard let id = selectedModeID, let context = dataManager.modelContext else { return nil }
        return context.model(for: id) as? EntityPaymentMode
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Default values ​​for transactions for this account.")
                .font(.headline)
                .padding(.top)
            
            // Sélection des préférences
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Picker("Status", selection: $selectedStatusID) {
//                        Text("Aucun statut").tag(nil as PersistentIdentifier?)
                        ForEach(entityStatus, id: \.self) { index in
                            Text(index.name).tag(index.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Mode", selection: $selectedModeID) {
//                        Text("Aucun mode de paiement").tag(nil as PersistentIdentifier?)
                        ForEach(entityPaymentMode, id: \.self) {
                            Text($0.name).tag($0.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Picker("Rubric", selection: $selectedRubricID) {
//                        Text("Aucune rubrique").tag(nil as PersistentIdentifier?)
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
                    
                    Picker("No category", selection: $selectedCategoryID) {
                        Text("No category").tag(nil as PersistentIdentifier?)
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
                Text("Default sign")
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
        let pref = PreferenceManager.shared.getAllData(for: account)
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
        selectedModeID = entityPreference.paymentMode?.persistentModelID
        selectedRubricID = entityPreference.category?.rubric?.persistentModelID
        selectedCategoryID = entityPreference.category?.persistentModelID
        isExpanded = entityPreference.signe
        
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

