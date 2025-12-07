//
//  ContainerManager.swift
//  DatabaseManager
//
//  Created by thierryH24 on 24/08/2025.
//

import SwiftUI
import SwiftData
import Combine


// MARK: - Container Manager avec gestion fichiers récents
class ContainerManager: ObservableObject {
    @Published var currentContainer: ModelContainer?
    @Published var currentDatabaseName: String = ""
    @Published var currentDatabaseURL: URL?
    @Published var recentFiles: [RecentFile] = []
    @Published var showingSplashScreen = true
    
    private let recentFilesKey = "RecentDatabases"
    private let maxRecentFiles = 10
    
    let schema = AppSchema.shared.schema
    
    init() {
        loadRecentFiles()
        logUI("ContainerManager.init - showingSplashScreen=\(showingSplashScreen)")
    }
    
    // MARK: - Gestion des fichiers récents
    private func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: recentFilesKey),
           let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
            // Filtrer les fichiers qui existent encore
            recentFiles = files.filter { FileManager.default.fileExists(atPath: $0.url.path) }
                .sorted { $0.lastAccessed > $1.lastAccessed }
        }
    }
    
    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: recentFilesKey)
        }
    }
    
    private func addToRecentFiles(_ file: RecentFile) {
        // Supprimer le fichier s'il existe déjà
        recentFiles.removeAll { $0.url == file.url }
        
        // Ajouter en première position
        recentFiles.insert(file, at: 0)
        
        // Limiter le nombre de fichiers récents
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        saveRecentFiles()
    }
    
    func removeFromRecentFiles(url: URL) {
        recentFiles.removeAll { $0.url == url }
        saveRecentFiles()
    }
    
    // Main-actor isolated because it touches main-actor isolated singletons (e.g., CurrentAccountManager.shared)
    @MainActor private func clearAllCaches() {
        // Vider les caches des managers connus
        
        RubricManager.shared.entitiesRubric.removeAll()
        BankManager.shared.reset()
        BankStatementManager.shared.reset()
        ChequeBookManager.shared.reset()
        IdentityManager.shared.reset()
        PaymentModeManager.shared.reset()
        PreferenceManager.shared.reset()
        RubricManager.shared.reset()
        SchedulerManager.shared.reset()
        SubTransactionsManager.shared.reset()
        StatusManager.shared.reset()
        ListTransactionsManager.shared.reset()
        
        CurrentAccountManager.shared.clearAccount()
        
        // TODO: Ajouter ici d'autres nettoyages si vous avez d'autres managers qui gardent des entités
    }
    
    // MARK: - Helpers
    private func sanitizeFileName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
    
    // MARK: - Gestion des bases de données (API principale)
    // Crée une base au chemin donné (p.ex. choisi via NSSavePanel)
    @MainActor
    func createNewDatabase(at url: URL) {
        let schema = AppSchema.shared.schema
        logUI("createNewDatabase begin - url=\(url.path)")
        
        do {
            // Normaliser l’URL: nom de fichier nettoyé + extension .store
            let baseName = url.deletingPathExtension().lastPathComponent
            let sanitizedFileName = sanitizeFileName(baseName)
            
            // Dossier parent choisi par l'utilisateur dans le NSSavePanel
            let baseDirectory = url.deletingLastPathComponent()
            
            // Créer un sous-dossier portant le nom "sanitizedFileName"
            let parentDir = baseDirectory.appendingPathComponent(sanitizedFileName, isDirectory: true)
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Construire l’URL finale: <parentDir>/<sanitizedFileName>.store
            var cleanURL = parentDir.appendingPathComponent(sanitizedFileName)
            if cleanURL.pathExtension != "store" {
                cleanURL = cleanURL.appendingPathExtension("store")
            }
            
            // Configurer le container SwiftData
            let config = ModelConfiguration(
                schema: schema,
                url: cleanURL,
                allowsSave: true
            )
            
            let container = try ModelContainer(for: schema, configurations: config)
            let context = container.mainContext
            
            // Centraliser le ModelContext et l’UndoManager
            let globalUndo = UndoManager()
            DataContext.shared.context = context
            DataContext.shared.undoManager = globalUndo
            context.undoManager = globalUndo

            DataContext.shared.container  = nil
            
            initBDD()  // >--> Important
            
            logUI("createNewDatabase end - about to openDatabase at \(cleanURL.path)")
            openDatabase(at: cleanURL)
            
        } catch {
            print("❌ Erreur lors de la création : \(error)")
            let sqliteError = error as NSError
            print("❌ Code SQLite: \(sqliteError.code)")
            print("❌ Détails: \(sqliteError.userInfo)")
        }
    }
    
    @MainActor func initBDD() {
        // initialisation de la BDD
        //une personne de démonstration
        //        PersonManager.shared.create(name: "Exemple", town: "Seoul", age: 25)
        
        // Une BDD plus complexe
        InitManager.shared.initialize()
    }
    
    @MainActor func openDatabase(at url: URL) {
        logUI("openDatabase begin - url=\(url.path)")
        do {
            let config = ModelConfiguration(
                schema: schema,
                url: url
            )
            let container = try ModelContainer(for: schema, configurations: config)
            let context = container.mainContext
            
            // Centraliser le ModelContext et l'UndoManager global
            let globalUndo = UndoManager()
            DataContext.shared.context = context
            DataContext.shared.undoManager = globalUndo
            DataContext.shared.container = nil
            context.undoManager = globalUndo
            
            // Publier l'état courant
            currentContainer = container
            currentDatabaseURL = url
            currentDatabaseName = url.deletingPathExtension().lastPathComponent
            
            logUI("openDatabase state set - name=\(currentDatabaseName) url=\(currentDatabaseURL?.path ?? "nil")")
            
            // Ajouter aux fichiers récents
            let recentFile = RecentFile(name: currentDatabaseName, url: url)
            addToRecentFiles(recentFile)
            
            logUI("openDatabase about to hide splash - showingSplashScreen=\(showingSplashScreen)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                logUI("openDatabase hiding splash (async) - before=\(self.showingSplashScreen)")
                self.showingSplashScreen = false
                logUI("openDatabase did hide splash (async) - after=\(self.showingSplashScreen)")
            }
            
            logUI("openDatabase end")
        } catch {
            print("Erreur lors de l'ouverture : \(error)")
        }
    }
    
    @MainActor
    func closeCurrentDatabase() {
        // 1) Prévenir l’UI qu’on ferme, pour qu’elle cesse d’accéder aux entités
        currentDatabaseURL = nil
        currentDatabaseName = ""
        
        // 2) Vider les caches applicatifs qui conservent des instances SwiftData
        clearAllCaches()
                
        // 3) Laisser l’UI appliquer ces changements avant de débrancher le contexte
        Task { @MainActor in
            // Laisser passer au moins un cycle de runloop
            await Task.yield()
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms pour être large (optionnel)
            
            let emptyContainer = try? ModelContainer(for: DummyModel.self)
            DataContext.shared.container = emptyContainer
            DataContext.shared.context = ModelContext(emptyContainer!)
            DataContext.shared.undoManager = UndoManager()
        }
        showingSplashScreen = true
    }
    
    func clearAll(in context: ModelContext) {
        try? context.delete(model: EntityAccount.self)
        try? context.delete(model: EntityBankStatement.self)
        try? context.delete(model: EntityBanqueInfo.self)
        try? context.delete(model: EntityCategory.self)
        try? context.delete(model: EntityCheckBook.self)
        try? context.delete(model: EntityFolderAccount.self)
        try? context.delete(model: EntityIdentity.self)
        try? context.delete(model: EntityInitAccount.self)
        try? context.delete(model: EntityPaymentMode.self)
        try? context.delete(model: EntityStatus.self)
        try? context.delete(model: EntityPreference.self)
        try? context.delete(model: EntityCategory.self)
        try? context.delete(model: EntityRubric.self)
        try? context.delete(model: EntitySchedule.self)
        try? context.delete(model: EntitySousOperation.self)
        try? context.delete(model: EntityTransaction.self)
    }
}


