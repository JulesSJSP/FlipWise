//
//  FlipWiseApp.swift
//  FlipWise
//
//  Created by Jules Beausaert on 06/05/2025.
//

import SwiftUI

@main
struct LoginApp: App {
    @AppStorage("isLoggedIn") var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                HomeView()
            } else {
                LoginView()
            }
        }
    }
}

