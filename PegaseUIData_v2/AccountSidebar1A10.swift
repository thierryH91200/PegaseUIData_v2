import SwiftUI
import SwiftData
import AppKit
import Combine
import UniformTypeIdentifiers

//extension EntityFolderAccount: Identifiable {}
//extension EntityAccount: Identifiable {}

struct Sidebar1A: View {
        
    @State var folders: [EntityFolderAccount] = []
    
    @State private var selectedAccountID: UUID?
    @State private var selectedMode = String(localized: "Check")
    
    var body: some View {
        
        List(selection: $selectedAccountID) {
            ForEach(folders) { folder in
                FolderSectionView(
                    folder: folder,
                    selectedAccountID: $selectedAccountID,
                    onMoved: {
                        folders = AccountFolderManager.shared.getAllData()
                    }
                )
            }
        }
        .navigationTitle(String(localized:"Account", table: "Account"))
        .listStyle(SidebarListStyle())
        .id(selectedAccountID)
        .frame(maxHeight: 500) // Ajustement de la hauteur
        
        .onChange(of: selectedAccountID) { oldID, newID in
            if let uuid = newID?.uuidString {
                CurrentAccountManager.shared.setAccount(uuid)
            }
        }
        Bouton(selectedAccountID: $selectedAccountID)
            .onAppear {
                Task {
                    folders = AccountFolderManager.shared.getAllData()
                    AccountFolderManager.shared.preloadDataIfNeeded()
                    await MainActor.run {
                        if selectedAccountID == nil {
                            if let firstFolder = folders.first, let firstAccount = firstFolder.children.first {
                                selectedAccountID = firstAccount.uuid
                                let firstModeName: String = firstAccount.paymentMode.first?.name ?? ""
                                selectedMode = firstModeName
                            }
                        }
                    }
                }
            }
    }
}

class BalanceManager: ObservableObject {
    @Published var balance: Double = 123.45
}

//// Vue pour l'en-tête de section
struct SectionHeader: View {
    
    @State var balance: Double = 0.0
    //section.children.reduce(0) { $0 + $1.solde }
    
    let section: EntityFolderAccount
    
    var body: some View {
        
        let count: Int = section.children.count
        
        HStack {
            Image(systemName: section.nameImage)
                .foregroundColor(.accentColor)
                .font(.system(size: 36)) // Ajustez la taille ici
            
            VStack {
                Text(section.name)
                    .font(.headline)
                Text("\(count) Account")
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(balance, specifier: "%.2f") €")
                .font(.headline)
                .foregroundColor(balance >= 0 ? .green : .red)
                .frame(width: 80, alignment: .trailing) // Aligne à droite avec une largeur fixe
        }
        .onAppear(){
            balance = section.children.reduce(0) { $0 + $1.solde }
        }
        .padding(.bottom, 5)
    }
}

struct AccountRow: View {
    
    @Environment(\.colorScheme) private var colorScheme

    let account: EntityAccount?
    let isSelected: Bool
    
    @State private var isPresented = false
    @State private var selectedAccount : EntityAccount?

    // MARK: - Computed properties optimisées
    private var rowBackground: Color {
        if isSelected {
            return colorScheme == .dark
            ? Color.accentColor.opacity(0.5)
            : Color.accentColor.opacity(0.6)
        } else {
            return colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.clear
        }
    }
    
    private var iconBackground: Color {
        isSelected ? Color.accentColor : Color.gray.opacity(0.3)
    }
    
    private var soldeColor: Color {
        account?.solde ?? 0.0 >= 0 ? .green : .red
    }
    
    private var identityText: String? {
        guard let id = account?.identity else { return nil }
        return "\(id.name) \(id.surName)"
    }
    
    private var accountCodeText: String? {
        account?.initAccount?.codeAccount
    }
    @State private var isShowAccountForm = false
    @State private var isModeCreate = true

    // MARK: - Body
    var body: some View {
        HStack {
            icon
            info
            Spacer()
            solde
        }
        .padding(8)
        .background(rowBackground)
        .cornerRadius(6)
        .contextMenu {
            menu
        }
//        .onDelete {
////            deleteAccount()
//        }
        .sheet(isPresented: $isPresented)
        {
            AccountFormView(
                isPresented: $isPresented,
                isModeCreate: $isModeCreate,
                account: isModeCreate ? nil : selectedAccount)
        }
    }
    
    // MARK: - Sous-vues
    private var icon: some View {
        Image(account?.nameIcon ?? "questionmark.circle")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .padding(0)
    }
    
    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            
            Text(account?.name ?? "")
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)
            
            if let identityText {
                Text(identityText)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            if let accountCodeText {
                Text(accountCodeText)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .primary)
            }
        }
    }
    
    private var solde: some View {
        Text("\((account?.solde ?? 0.0), specifier: "%.2f") €")
            .font(.caption)
            .foregroundColor(soldeColor)
            .frame(width: 80, alignment: .trailing)
    }
    
    private var menu: some View {
        Group {
            Button {
                isModeCreate = true
                selectedAccount = nil
                DispatchQueue.main.async {
                    isPresented = true
                }
            } label: {
                Label("Add account", systemImage: "arrow.right.circle")
            }

            Button {
                isModeCreate = false
                selectedAccount = account
                DispatchQueue.main.async {
                    isPresented = true
                }
            } label: {
                Label("Edit account", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {  } label: {
                Label("Remove account", systemImage: "trash")
            }
        }
    }
}

struct Bouton: View {
    
    @Binding var selectedAccountID: UUID?
    @Query(sort: \EntityAccount.name) var accounts: [EntityAccount]

    var selectedAccount: EntityAccount? {
        accounts.first { $0.uuid == selectedAccountID }
    }

    @State private var selectedOption = "Options"

    @State private var isPresentedccount = false
    @State private var isPresentedGroup = false
    @State private var isModeCreate = false
    
    var body: some View {
        HStack {
            Button(action: {
                printTag("Button minus pressed", flag: true)
            }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16))
            }
            Spacer()
            Menu {
                Button(action: {
                    isPresentedGroup = true
                    isModeCreate = true
                }) {
                    Label(String(localized:"Add Group Account"), systemImage: "info.circle")
                }
                Button(action: {
                    isPresentedGroup = true
                    isModeCreate = false
                }) {
                    Label("Edit Group Account", systemImage: "info.circle")
                }
                Divider()
                
                Button(action: {
                    isPresentedccount = true
                    isModeCreate = true
                }) {
                    Label("Add account", systemImage: "info.circle")
                }

                Button(action: {
                    isPresentedccount = true
                    isModeCreate = false
                }) {
                    Label("Edit account", systemImage: "info.circle")
                }
            } label: {
                Label(selectedOption, systemImage: "ellipsis.circle")
                    .font(.system(size: 16))
            }
            Spacer()
            Button(action: {
                printTag("UUID", flag: true)
            }) {
                Image(systemName: "lock")
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)

        .sheet(isPresented: $isPresentedccount , onDismiss: {setupDataManager()})
        {
            AccountFormView(
                isPresented: $isPresentedccount,
                isModeCreate: $isModeCreate,
                account: isModeCreate ? nil : selectedAccount)
        }
        .sheet(isPresented: $isPresentedGroup , onDismiss: {setupDataManager()})
        {
            GroupAccountFormView(
                isPresented: $isPresentedGroup,
                isModeCreate: $isModeCreate,
                accountFolder: isModeCreate ? nil : selectedAccount?.folder)
        }
    }
    
    private func setupDataManager() {
        
    }
}

// MARK: - Helpers for drag & drop used in Sidebar1A
struct FolderSectionView: View {
    // Wrapper to make UUID transferable for drag and drop
    struct AccountIDPayload: Transferable, Identifiable, Hashable, Codable {
        var id: UUID { uuid }
        let uuid: UUID
        
        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(contentType: UTType.data)
        }
    }
    
    let folder: EntityFolderAccount
    @Binding var selectedAccountID: UUID?
    var onMoved: () -> Void = {}
    @State private var isTargetedHighlight = false
    
    var body: some View {
        Section(header: SectionHeader(section: folder)) {
            ForEach(folder.children, id: \.uuid) { child in
                AccountRow(
                    account: child,
                    isSelected: (selectedAccountID == child.uuid)
                )
                .tag(child.uuid)
                .draggable(AccountIDPayload(uuid: child.uuid))
            }
        }
        .background(
            isTargetedHighlight
            ? Color.accentColor.opacity(0.15)
            : Color.clear
        )
        .animation(.easeInOut(duration: 0.15), value: isTargetedHighlight)
        .dropDestination(for: AccountIDPayload.self) { items, location in
            for payload in items {
                moveAccount(with: payload.uuid, to: folder)
            }
            return true
        } isTargeted: { hovering in
            isTargetedHighlight = hovering
        }
    }
    
    private func moveAccount(with id: UUID, to destinationFolder: EntityFolderAccount) {
        printTag("[DnD] Move request for account: \(id) -> folder: \(destinationFolder.name)")
        
        // 1) Trouver le compte par son UUID
        guard let account = AccountFolderManager.shared.findAccount(by: id) else { return }
        printTag("[DnD] Found account: \(account.name) [\(account.uuid)]")
        
        // 2) Vérifier si le compte est déjà dans le dossier de destination
        if let currentFolder = AccountFolderManager.shared.findFolder(containing: account),
           currentFolder.uuid == destinationFolder.uuid {
            printTag("[DnD] Account already in destination folder: \(destinationFolder.name). Skipping move.")
            return
        }
        
        // 3) Retirer le compte de l'ancien dossier si nécessaire
        if let oldFolder = AccountFolderManager.shared.findFolder(containing: account) {
            printTag("[DnD] Removing from old folder: \(oldFolder.name)")
            oldFolder.children.removeAll { $0.uuid == account.uuid }
            printTag("[DnD] Removed from old folder: \(oldFolder.name)")
        }
        
        // 4) Ajouter le compte au dossier de destination
        printTag("[DnD] Appending to destination folder: \(destinationFolder.name)")
        destinationFolder.children.append(account)
        
        // 5) Mettre à jour la relation SwiftData pour rester cohérent
        printTag("[DnD] Updating account.folder to destination folder: \(destinationFolder.name)")
        account.folder = destinationFolder
        printTag("[DnD] account.folder updated for: \(account.name)")
        
        // 6) Sauvegarder les modifications
        printTag("[DnD] Saving context...")
        AccountFolderManager.shared.saveIfNeeded()
        printTag("[DnD] Save completed.")
        
        // 7) Rafraîchir la vue / les données
        printTag("[DnD] Triggering onMoved refresh.")
        self.onMoved()
    }
}
