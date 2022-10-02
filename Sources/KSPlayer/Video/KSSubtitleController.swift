//
//  File.swift
//  KSSubtitle
//
//  Created by kintan on 2018/8/3.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Combine
public class KSSubtitleController {
    private let cacheDataSouce = CacheDataSouce()
    private var subtitleDataSouces: [SubtitleDataSouce] = []
    private var infos = [SubtitleInfo]()
    private var subtitleName: String?
    public var view: KSSubtitleView
    public var subtitle: KSSubtitleProtocol?
    public var selectWithFilePath: ((Result<KSSubtitleProtocol, NSError>) -> Void)? {
        didSet {
            view.selectWithFilePath = selectWithFilePath
        }
    }

    @Published public var srtListCount: Int = 0
    public init(customControlView: KSSubtitleView? = nil) {
        if let customView = customControlView {
            view = customView
        } else {
            view = KSSubtitleView()
        }
        view.isHidden = true
        subtitleDataSouces = [cacheDataSouce]
    }

    public func searchSubtitle(name: String) {
        let subtitleName = (name as NSString).deletingPathExtension
        infos.removeAll()
        srtListCount = infos.count
        for subtitleDataSouce in subtitleDataSouces {
            searchSubtitle(datasouce: subtitleDataSouce, name: subtitleName)
        }
        self.subtitleName = subtitleName
    }

    public func remove(dataSouce: SubtitleDataSouce) {
        subtitleDataSouces.removeAll { $0 === dataSouce }
        runInMainqueue { [weak self] in
            guard let self else { return }
            dataSouce.infos?.forEach { info in
                self.infos.removeAll { other in
                    other.subtitleID == info.subtitleID
                }
                if info.subtitleID == self.view.selectedInfo?.subtitleID {
                    self.view.selectedInfo = nil
                }
            }
            self.srtListCount = self.infos.count
            self.view.setupDatas(infos: self.infos)
        }
    }

    public func add(dataSouce: SubtitleDataSouce) {
        subtitleDataSouces.append(dataSouce)
        if let dataSouce = dataSouce as? SubtitletoCache {
            dataSouce.cache = cacheDataSouce
        }
        if let subtitleName {
            searchSubtitle(datasouce: dataSouce, name: subtitleName)
        }
    }

    public func filterInfos(_ isIncluded: (SubtitleInfo) -> Bool) -> [SubtitleInfo] {
        infos.filter(isIncluded)
    }

    private func searchSubtitle(datasouce: SubtitleDataSouce, name: String) {
        datasouce.searchSubtitle(name: name) {
            guard let array = datasouce.infos else { return }
            runInMainqueue { [weak self] in
                guard let self else { return }
                self.infos.append(contentsOf: array)
                self.srtListCount = self.infos.count
                self.view.setupDatas(infos: self.infos)
            }
        }
    }
}
