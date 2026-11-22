import SwiftUI

/// À appliquer au contenu d'une feuille locale (hors AppState) : tant qu'elle est affichée,
/// les raccourcis globaux (⌘N, ⇧⌘N, ⌘K) sont désactivés.
private struct TracksSheetPresentation: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .onAppear { appState.localSheetCount += 1 }
            .onDisappear { appState.localSheetCount = max(0, appState.localSheetCount - 1) }
    }
}

extension View {
    func tracksSheetPresentation() -> some View { modifier(TracksSheetPresentation()) }
}
