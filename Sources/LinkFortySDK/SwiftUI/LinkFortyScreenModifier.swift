//
//  LinkFortyScreenModifier.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
public extension View {
    /// Reports a `screen_view` event when this view appears.
    ///
    /// The event is stamped with the active last-click attribution context, so the
    /// dashboard can show which screens users reach after opening a deep link.
    ///
    /// ```swift
    /// ProductView()
    ///     .linkfortyScreen("ProductDetail")
    /// ```
    ///
    /// - Parameters:
    ///   - name: Screen name (e.g., "ProductDetail")
    ///   - properties: Optional additional properties
    func linkfortyScreen(_ name: String, properties: [String: Any]? = nil) -> some View {
        modifier(LinkFortyScreenModifier(name: name, properties: properties))
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct LinkFortyScreenModifier: ViewModifier {
    let name: String
    let properties: [String: Any]?

    func body(content: Content) -> some View {
        content.onAppear {
            let name = self.name
            let properties = self.properties
            Task {
                try? await LinkForty.shared.trackScreenView(name: name, properties: properties)
            }
        }
    }
}
#endif
