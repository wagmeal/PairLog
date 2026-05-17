import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        windowScene.windows.forEach { $0.overrideUserInterfaceStyle = .light }
    }
}

@main
struct PairLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appSession = AppSessionViewModel()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var activeUserPref = ActiveUserPreference()


    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environmentObject(appSession)
                .environmentObject(authVM)
                .environmentObject(activeUserPref)
                .preferredColorScheme(.light)
        }
    }
}

private struct AppEntryView: View {
    @EnvironmentObject private var appSession: AppSessionViewModel

    var body: some View {
        Group {
            switch appSession.state {
            case .loading:
                ZStack {
                    Color.background.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.maincolor)
                }

            case .loggedOut:
                LoginView()

            case .needsPairSetup:
                PairUsersSetupView(mode: .setup) { _, _ in
                    appSession.refreshSetupState()
                }

            case .ready:
                RootTabView()
                    .task {
                        await RecurringRuleExecutor.checkAndExecute()
                    }
            }
        }
        .task {
            appSession.start()
        }
    }
}

@MainActor
final class AppSessionViewModel: ObservableObject {
    enum State {
        case loading
        case loggedOut
        case needsPairSetup
        case ready
    }

    @Published var state: State = .loading

    private var authListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private var hasStarted = false

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            Task { @MainActor in
                if let user {
                    await self.resolveLoggedInState(uid: user.uid)
                } else {
                    self.state = .loggedOut
                }
            }
        }
    }

    func refreshSetupState() {
        guard let uid = Auth.auth().currentUser?.uid else {
            state = .loggedOut
            return
        }

        Task {
            await resolveLoggedInState(uid: uid)
        }
    }

    private func resolveLoggedInState(uid: String) async {
        state = .loading

        do {
            let document = try await db.collection("users")
                .document(uid)
                .collection("pair_profile")
                .document("main")
                .getDocument()

            let data = document.data() ?? [:]
            let user1Name = (data["user1Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let user2Name = (data["user2Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !user1Name.isEmpty && !user2Name.isEmpty {
                state = .ready
            } else {
                state = .needsPairSetup
            }
        } catch {
            state = .needsPairSetup
        }
    }
}
