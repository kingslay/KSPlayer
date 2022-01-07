//
//  Collection+.swift
//  KSPlayer-tvOS
//
//  Created by Alanko5 on 07/01/2022.
//

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
