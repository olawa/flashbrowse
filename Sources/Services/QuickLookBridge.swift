import Foundation
import AppKit
import Quartz
import QuickLookUI

public class QuickLookBridge: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookBridge()
    
    public var currentPreviewURL: URL? {
        didSet {
            if QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible {
                QLPreviewPanel.shared().reloadData()
            }
        }
    }
    
    private override init() {
        super.init()
    }
    
    public func toggleQuickLook(for url: URL?) {
        guard let url = url else { return }
        self.currentPreviewURL = url
        
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentPreviewURL != nil ? 1 : 0
    }
    
    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard let url = currentPreviewURL else { return nil }
        return (url as NSURL)
    }
}
