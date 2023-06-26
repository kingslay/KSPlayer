//
//  SwiftUIView.swift
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
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
