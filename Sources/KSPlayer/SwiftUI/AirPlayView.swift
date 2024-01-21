//
//  AirPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2023/5/4.
//

import AVKit
import SwiftUI

#if !os(xrOS)
public struct AirPlayView: UIViewRepresentable {
    public init() {}

    #if canImport(UIKit)
    public typealias UIViewType = AVRoutePickerView
    public func makeUIView(context _: Context) -> UIViewType {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        return routePickerView
    }

    public func updateUIView(_: UIViewType, context _: Context) {}
    #else
    public typealias NSViewType = AVRoutePickerView
    public func makeNSView(context _: Context) -> NSViewType {
        let routePickerView = AVRoutePickerView()
        routePickerView.isRoutePickerButtonBordered = false
        return routePickerView
    }

    public func updateNSView(_: NSViewType, context _: Context) {}
    #endif
}
#endif
public extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder
    func `if`(_ condition: @autoclosure () -> Bool, transform: (Self) -> some View) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`(_ condition: @autoclosure () -> Bool, if ifTransform: (Self) -> some View, else elseTransform: (Self) -> some View) -> some View {
        if condition() {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }

    @ViewBuilder
    func ifLet<T: Any>(_ optionalValue: T?, transform: (Self, T) -> some View) -> some View {
        if let value = optionalValue {
            transform(self, value)
        } else {
            self
        }
    }
}

extension Bool {
    static var iOS16: Bool {
        guard #available(iOS 16, *) else {
            return true
        }
        return false
    }
}
