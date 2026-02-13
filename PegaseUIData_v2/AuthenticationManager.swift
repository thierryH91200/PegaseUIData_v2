


import Foundation
import SwiftUI
import Combine
import LocalAuthentication


/// A manager responsible for handling user authentication state.
public final class AuthenticationManager: ObservableObject {
    /// Indicates whether the user is currently authenticated.
    @Published public private(set) var isAuthenticated: Bool = false

    /// Indicates whether the app is currently unlocked.
    @Published public private(set) var isUnlocked: Bool = false

    /// Stores any authentication error message.
    @Published public private(set) var authenticationError: String? = nil

    /// The current authenticated user's username, if any.
    @Published public private(set) var currentUserName: String? = nil

    /// Timer for automatic lock after inactivity
    private var inactivityTimer: Timer?

    /// Keys for UserDefaults storage
    private static let inactivityTimeoutKey = "inactivityTimeout"
    private static let inactivityTimeoutSetKey = "inactivityTimeoutHasBeenSet"
    private static let requireLockScreenAtLaunchKey = "requireLockScreenAtLaunch"

    /// Whether the lock screen is required at app launch (default: true)
    /// Persisted in UserDefaults
    @Published public var requireLockScreenAtLaunch: Bool {
        didSet {
            UserDefaults.standard.set(requireLockScreenAtLaunch, forKey: Self.requireLockScreenAtLaunchKey)
        }
    }

    /// Inactivity timeout in seconds (default: 5 minutes)
    /// Persisted in UserDefaults
    /// Value of 0 means "Never" (no automatic lock)
    public var inactivityTimeout: TimeInterval {
        get {
            // Vérifier si la valeur a déjà été définie par l'utilisateur
            if UserDefaults.standard.bool(forKey: Self.inactivityTimeoutSetKey) {
                return UserDefaults.standard.double(forKey: Self.inactivityTimeoutKey)
            }
            // Valeur par défaut : 5 minutes
            return 300
        }
        set {
            UserDefaults.standard.set(true, forKey: Self.inactivityTimeoutSetKey)
            UserDefaults.standard.set(newValue, forKey: Self.inactivityTimeoutKey)
        }
    }

    /// Publishers to track user activity
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Load persisted preference (defaults to true if never set)
        if UserDefaults.standard.object(forKey: Self.requireLockScreenAtLaunchKey) != nil {
            self.requireLockScreenAtLaunch = UserDefaults.standard.bool(forKey: Self.requireLockScreenAtLaunchKey)
        } else {
            self.requireLockScreenAtLaunch = true
        }

        // If lock screen is not required, unlock immediately
        if !requireLockScreenAtLaunch {
            isUnlocked = true
            isAuthenticated = true
        }

        setupActivityMonitoring()
    }
    
    /// Signs in the user with a given username and password.
    /// - Parameters:
    ///   - username: The username of the user.
    ///   - password: The password of the user.
    /// 
    /// This method currently simulates a successful sign-in by setting the authentication state accordingly.
    public func signIn(username: String, password: String) {
        isAuthenticated = true
        currentUserName = username
    }
    
    /// Signs out the current user, clearing the authentication state.
    public func signOut() {
        isAuthenticated = false
        currentUserName = nil
    }
    
    /// Restores the authentication session.
    ///
    /// This method currently resets the authentication state to unauthenticated.
    public func restoreSession() {
        isAuthenticated = false
        currentUserName = nil
    }

    /// Authenticates the user using biometric or system authentication.
    public func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Vérifier si l'authentification biométrique est disponible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Déverrouillez l'application avec Touch ID ou Face ID"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self?.authenticationError = nil
                        self?.isUnlocked = true
                        self?.isAuthenticated = true
                        self?.resetInactivityTimer()
                    } else {
                        // En cas d'échec, proposer le mot de passe système
                        self?.authenticateWithPassword()
                    }
                }
            }
        } else {
            // Si Touch ID/Face ID n'est pas disponible, utiliser le mot de passe
            authenticateWithPassword()
        }
    }

    /// Authentifie avec le mot de passe système en fallback
    private func authenticateWithPassword() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Déverrouillez l'application avec votre mot de passe"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self?.authenticationError = nil
                        self?.isUnlocked = true
                        self?.isAuthenticated = true
                        self?.resetInactivityTimer()
                    } else {
                        if let error = authenticationError {
                            self?.authenticationError = self?.getErrorMessage(error: error as NSError)
                        }
                    }
                }
            }
        } else {
            if let error = error {
                authenticationError = getErrorMessage(error: error)
            } else {
                authenticationError = "L'authentification n'est pas disponible sur cet appareil"
            }
        }
    }

    /// Convertit les erreurs LAError en messages lisibles
    private func getErrorMessage(error: NSError) -> String {
        guard let laError = LAError.Code(rawValue: error.code) else {
            return "Erreur d'authentification inconnue"
        }

        switch laError {
        case .authenticationFailed:
            return "L'authentification a échoué"
        case .userCancel:
            return "Authentification annulée"
        case .userFallback:
            return "Authentification annulée par l'utilisateur"
        case .systemCancel:
            return "Authentification annulée par le système"
        case .passcodeNotSet:
            return "Aucun mot de passe n'est configuré sur cet appareil"
        case .biometryNotAvailable:
            return "Touch ID/Face ID n'est pas disponible"
        case .biometryNotEnrolled:
            return "Touch ID/Face ID n'est pas configuré"
        case .biometryLockout:
            return "Touch ID/Face ID est verrouillé. Utilisez votre mot de passe."
        default:
            return "Erreur d'authentification"
        }
    }

    /// Locks the application, requiring re-authentication.
    public func lock() {
        isUnlocked = false
        isAuthenticated = false
        authenticationError = nil
        stopInactivityTimer()
    }

    /// Sets up monitoring for user activity
    private func setupActivityMonitoring() {
        // Observer pour les événements NSEvent (clics, touches clavier, etc.)
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel]) { [weak self] event in
            self?.resetInactivityTimer()
            return event
        }
    }

    /// Starts or resets the inactivity timer
    public func resetInactivityTimer() {
        guard isUnlocked else { return }

        stopInactivityTimer()

        // Si timeout est 0 (Jamais), ne pas démarrer le timer
        guard inactivityTimeout > 0 else { return }

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lock()
            }
        }
    }

    /// Stops the inactivity timer
    public func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    /// Configures the inactivity timeout
    /// - Parameter timeout: Timeout in seconds
    public func setInactivityTimeout(seconds: TimeInterval) {
        self.inactivityTimeout = seconds
        if isUnlocked {
            resetInactivityTimer()
        }
    }

    deinit {
        stopInactivityTimer()
    }
}

struct LockScreenView: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("PegaseUIData")
                .font(.largeTitle.bold())
            
            Text("Your financial data is protected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                authManager.authenticate()
            }) {
                Label("Lock", systemImage: "touchid")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if let error = authManager.authenticationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .frame(width: UIConstants.lockScreenSize.width, height: UIConstants.lockScreenSize.height)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

