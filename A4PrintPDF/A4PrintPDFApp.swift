//
//  A4PrintPDFApp.swift
//  A4PrintPDF
//
//  Created by ゆー on 2026/02/07.
//

import SwiftUI

#if canImport(UIKit)
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MobileAds.shared.start(completionHandler: nil)
        return true
    }
}
#endif

@main
struct A4PrintPDFApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
