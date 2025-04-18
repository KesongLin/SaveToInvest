//
//  SaveToInvestApp.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 3/14/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAppCheck

// AppDelegate implementation
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        
        let IPv4PreferenceKey = "CFNetworkPrefersIPv4Over6"
        UserDefaults.standard.set(true, forKey: IPv4PreferenceKey)
        
        // 1) Create debug provider factory with token
        let providerFactory = AppCheckDebugProviderFactory()
          AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // 2) Configure Firebase
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
        
        // 3) Firestore settings (updated for cacheSettings)
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()

        // [START persistent_cache_settings]
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber) // 100MB cache size
        // [END persistent_cache_settings]

        firestore.settings = settings

        
        return true
    }
}

    
@main
struct SaveToInvestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = MainViewModel()
    @Environment(\.scenePhase) private var scenePhase
        
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    InvestmentDataManager.shared.initialize(with: viewModel.firebaseService)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        // App became active - refresh data
                        if viewModel.firebaseService.isAuthenticated {
                            NotificationCenter.default.post(name: Notification.Name("RefreshExpenses"), object: nil)
                        }
                    }
                }
        }
    }
}


