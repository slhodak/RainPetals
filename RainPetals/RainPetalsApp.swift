//
//  RainPetalsApp.swift
//  RainPetals
//
//  Created by Sam Hodak on 3/4/24.
//

import SwiftUI

@main
struct RainPetalsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
