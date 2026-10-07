//
//  ViewExtension.swift
//  KSPlayer
//
//  Created by kintan on 11/30/24.
//

import SwiftUI

#if !os(tvOS)
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@MainActor
public struct PlayBackCommands: Commands {
    @FocusedObject
    private var config: KSVideoPlayer.Coordinator?
    public init() {}

    public var body: some Commands {
        CommandMenu("PlayBack") {
            if let config {
                Button(config.state.isPlaying ? String(localized: "Pause", bundle: .module) : String(localized: "Resume", bundle: .module)) {
                    if config.state.isPlaying {
                        config.playerLayer?.pause()
                    } else {
                        config.playerLayer?.play()
                    }
                }
                .keyboardShortcut(.space, modifiers: .none)
                Button(config.isMuted ? String(localized: "Mute", bundle: .module) : String(localized: "Unmute", bundle: .module)) {
                    config.isMuted.toggle()
                }
            }
        }
    }
}
#endif

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct MenuView<SelectionValue: Hashable, Content: View, Label: View>: View {
    public let selection: Binding<SelectionValue>
    @ViewBuilder
    public let content: () -> Content
    @ViewBuilder
    public let label: () -> Label
    @State
    private var showMenu = false

    public init(_ titleKey: String, selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) where Label == Text {
        self.init(selection: selection, content: content) {
            Text(titleKey)
        }
    }

    public init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label) {
        self.selection = selection
        self.content = content
        self.label = label
        showMenu = showMenu
    }

    public var body: some View {
        if #available(iOS 15, macOS 12.0, tvOS 17, *) {
            Menu {
                Picker(selection: selection) {
                    content()
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            } label: {
                label()
                    .menuLabelStyle()
            }
            .menuIndicator(.hidden)
            .menuStyleButton()
        } else {
            Picker(selection: selection, content: content) {
                label()
                    .menuLabelStyle()
            }
        }
    }
}

public extension View {
    @available(iOS 15, macOS 12, tvOS 15, *)
    func menuLabelStyle() -> some View {
        modifier(MenuLabelStyleModifier())
    }

    @available(iOS 14, macOS 11, tvOS 14, *)
    func isFocused(_ binding: Binding<Bool>) -> some View {
        modifier(WhenFocusedModifier(isFocuse: binding))
    }

    @available(iOS 15, macOS 12, tvOS 15, *)
    func isFocused<T: Hashable>(_ binding: Binding<T?>, equals value: T) -> some View {
        modifier(FocusModifier(binding: binding, value: value))
    }

    @available(iOS 14, macOS 11, tvOS 17, *)
    @ViewBuilder
    func menuStyleButton() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            menuStyle(.button)
        } else {
            menuStyle(.borderlessButton)
        }
    }

    @available(iOS 14, macOS 11, tvOS 15, *)
    @ViewBuilder
    func borderlessButton() -> some View {
        if #available(tvOS 17, *) {
            buttonStyle(.borderless)
        } else {
            self
        }
    }

    @available(iOS 14, macOS 11, tvOS 15, *)
    @ViewBuilder
    func circleGlassButton() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            #if os(visionOS)
            buttonBorderShape(.circle)
            #else
            buttonStyle(.glass)
                .buttonBorderShape(.circle)
            #endif
        } else if #available(tvOS 17.0, *) {
            buttonStyle(.borderless)
        } else {
            buttonStyle(.automatic)
        }
    }
}

public extension Binding where Value: Sendable {
    var option: Binding<Value?> {
        Binding<Value?>(
            get: { wrappedValue },
            set: { newValue in
                if let newValue {
                    wrappedValue = newValue
                }
            }
        )
    }
}

/// 这是只读的焦点状态，用于根据焦点调整样式
@available(iOS 14, macOS 11, tvOS 14, *)
private struct WhenFocusedModifier: ViewModifier {
    @Environment(\.isFocused)
    private var isFocused: Bool
    @Binding
    var isFocuse: Bool
    func body(content: Content) -> some View {
        content
            .onChange(of: isFocused) { newValue in
                isFocuse = newValue
            }
    }
}

@available(iOS 15, macOS 12, tvOS 15, *)
private struct FocusModifier<T: Hashable>: ViewModifier {
    @Binding
    var binding: T?
    let value: T
    @FocusState
    private var focused: T?
    func body(content: Content) -> some View {
        content
            .focused($focused, equals: value)
            .onChange(of: binding) { newValue in
                focused = newValue
            }
//            .onChange(of: focused) { newValue in
//                binding = newValue
//            }
    }
}

@available(iOS 15, macOS 12, tvOS 15, *)
private struct MenuLabelStyleModifier: ViewModifier {
    @State
    private var isFocus: Bool = false

    func body(content: Content) -> some View {
        content
            .symbolVariant(isFocus ? .fill : .none)
            .foregroundStyle(isFocus ? .black : .secondary)
            .scaleEffect(isFocus ? 1.25 : 1)
            .isFocused($isFocus)
        #if !os(tvOS)
            .font(.title3.weight(.semibold))
        #endif
    }
}

@available(iOS 16, macOS 13, tvOS 16, *)
public struct PlatformView<Content: View>: View {
    private let content: () -> Content
    public var body: some View {
        #if os(tvOS)
        // tvos需要加NavigationStack，不然无法出现下拉框。iOS不能加NavigationStack，不然会丢帧。
        NavigationStack {
            ScrollView {
                content()
                .padding()
                    .pickerStyle(.navigationLink)
            }
        }
        #else
        Form {
            content()
        }
        .formStyle(.grouped)
        #endif
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
}

@available(iOS 15, macOS 12, tvOS 15, *)
public struct ShowValueField<F: ParseableFormatStyle>: View where F.FormatOutput == String {
    private let titleKey: String
    private let value: Binding<F.FormatInput>
    private let prompt: Text?
    private let format: F

    public init(_ titleKey: String, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) {
        self.titleKey = titleKey
        self.value = value
        self.format = format
        self.prompt = prompt
    }

    public var body: some View {
        #if os(macOS)
        TextField(titleKey, value: value, format: format, prompt: prompt)
        #else
        HStack {
            Text(titleKey)
            Spacer()
            let title = ""
            TextField(title, value: value, format: format, prompt: prompt)
        }
        #endif
    }
}

@available(iOS 15, macOS 12, tvOS 15, *)
public struct ShowTextField: View {
    private let titleKey: String
    private let text: Binding<String>
    private let prompt: Text?
    public init(_ titleKey: String, text: Binding<String>, prompt: Text? = nil) {
        self.titleKey = titleKey
        self.text = text
        self.prompt = prompt
    }

    public var body: some View {
        #if os(macOS)
        TextField(titleKey, text: text, prompt: prompt)
        #else
        HStack {
            Text(titleKey)
            Spacer()
            let title = ""
            TextField(title, text: text, prompt: prompt)
        }
        #endif
    }
}

extension EventModifiers {
    static let none = Self()
}

extension View {
    func then(_ body: (inout Self) -> Void) -> Self {
        var result = self
        body(&result)
        return result
    }
}

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

extension View {
    func onKeyPressLeftArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.leftArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressRightArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.rightArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressSapce(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.space) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    #if !os(tvOS)
    func textSelection() -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            return textSelection(.enabled)
        } else {
            return self
        }
    }
    #endif

    func italic(value: Bool) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            return italic(value)
        } else {
            return self
        }
    }

    func ksIgnoresSafeArea() -> some View {
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            return ignoresSafeArea()
        } else {
            return self
        }
    }

    func onHoverActive(point: @escaping (CGPoint?) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onContinuousHover { phase in
                switch phase {
                case let .active(value):
                    point(value)
                default:
                    point(nil)
                }
            }
        } else {
            return self
        }
    }
}
