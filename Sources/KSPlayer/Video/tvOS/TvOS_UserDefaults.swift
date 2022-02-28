//
//  TvOS_UserDefaults.swift
//  KSPlayer-tvOS
//
//  Created by Marek Labuzik on 28/02/2022.
//

import Foundation

final class TvOSUserDefaults {
    static var isReduceLoudSounds: Bool {
        get {
            UserDefaults.standard.bool(forKey: "TvOSUserDefaults.isReduceLoudSounds")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TvOSUserDefaults.isReduceLoudSounds")
            UserDefaults.standard.synchronize()
        }
    }
}
