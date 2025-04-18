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

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Set environment variable to disable App Check enforcement
    // This must be done BEFORE FirebaseApp.configure()
    let fOptions = FirebaseOptions(contentsOfFile: Bundle.main.path(
                    forResource: "GoogleService-Info", ofType: "plist")!)
    
    // Force disable App Check
    if let fOptions = fOptions {
      FirebaseApp.configure(options: fOptions)
    } else {
      FirebaseApp.configure()
    }
          
    return true
  }
}

@main
struct SaveToInvestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
     @StateObject var viewModel = MainViewModel()

     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(viewModel)
                 .onAppear {
                     InvestmentDataManager.shared.initialize(with: viewModel.firebaseService)
                 }
         }
     }
 }
