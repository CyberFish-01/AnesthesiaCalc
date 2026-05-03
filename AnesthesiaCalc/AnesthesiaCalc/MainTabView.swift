//
//  MainTabView.swift
//  AnesthesiaCalc
//

import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — MainTabView (App Root — native TabView)
// ══════════════════════════════════════════════════════════════════════

struct MainTabView: View {

    @State private var selectedTab = 0
    @AppStorage("app_appearance") private var appearanceRaw: Int = 0

    private var preferredColorScheme: ColorScheme? {
        switch appearanceRaw {
        case 1:  return .light
        case 2:  return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorHomeView()
                .tabItem {
                    Label("计算", systemImage: "house.fill")
                }
                .tag(0)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)

            AIDecisionView()
                .tabItem {
                    Label("决策", systemImage: "brain.head.profile")
                }
                .tag(1)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)

            MaLeMeView()
                .tabItem {
                    Label("问答", systemImage: "magnifyingglass")
                }
                .tag(2)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
        .tint(.accentColor)
        .preferredColorScheme(preferredColorScheme)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    MainTabView()
}
