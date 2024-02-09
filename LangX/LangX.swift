//
//  TandyApp.swift
//  Tandy
//
//  Created by Luke Thompson on 25/11/2023.
//

import SwiftUI
import Firebase
import UserNotifications
import FirebaseMessaging

@main
struct LangX: App {
    @StateObject var authManager = AuthManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            mainView
                .environmentObject(authManager)
                .animation(.default, value: authManager.isAuthenticated)
                .animation(.default, value: authManager.isAccountSetup)
                .animation(.default, value: authManager.isInitializing)
                .accentColor(Color(red: 44/255, green: 150/255, blue: 255/255))
        }
    }

    @ViewBuilder
    private var mainView: some View {
        switch (authManager.isInitializing, authManager.isAuthenticated, authManager.isAccountSetup) {
        case (true, _, _):
            SplashScreenView()
        case (false, true, true):
            MainMenuView(authManager: authManager)
        case (false, true, false):
            SetupAccountView()
        case (false, false, _):
            LoginMenuView()
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request permission to display alerts and play sounds.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Request Authorization Completion Handler. Granted: \(granted), Error: \(String(describing: error))")
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNS Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        Messaging.messaging().apnsToken = deviceToken

        // Call uploadFCMToken here after setting APNS Token
        uploadFCMToken(fcmToken: Messaging.messaging().fcmToken)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "none")")
        // Call uploadFCMToken here as well
        if let token = fcmToken {
            uploadFCMToken(fcmToken: token)
        }
    }

    func uploadFCMToken(fcmToken: String?) {
        guard let token = fcmToken, let userID = Auth.auth().currentUser?.uid else {
            print("Error: FCM token or user ID is nil")
            return
        }

        let usersRef = Firestore.firestore().collection("users").document(userID)
        usersRef.setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error updating FCM token in Firestore: \(error.localizedDescription)")
            } else {
                print("FCM token updated successfully in Firestore.")
            }
        }
    }

    
    // Handle registration error
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    private func requestNotificationAuthorization(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
}