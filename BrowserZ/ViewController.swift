//
//  ViewController.swift
//  BrowserToy
//
//  Created by Marc Prud'hommeaux on 11/22/14.
//  Copyright (c) 2014 ChannelZ. All rights reserved.
//

import ChannelZ
import Cocoa
import AppKit
import WebKit

class WindowController : NSWindowController {

    override func windowDidLoad() {
//        window?.titleVisibility = .Hidden
    }
}


class ViewController : NSViewController {

    let backButton = makeButton(NSImageNameGoLeftTemplate)
    let forwardButton = makeButton(NSImageNameGoRightTemplate)
    let reloadButton = makeButton(NSImageNameRefreshTemplate)
    let stopButton = makeButton(NSImageNameStopProgressTemplate)
    let tabController = WebTabsController()
    var webView: WKWebView? { return self.tabController.tabView.selectedTabViewItem?.view as? WKWebView }

    override func viewDidLoad() {
        // buttons will be enabled when the web page loads
        backButton.enabled = false
        forwardButton.enabled = false

        let urlField = NSTextField()
        urlField.bezelStyle = NSTextFieldBezelStyle.RoundedBezel

        let progress = NSProgressIndicator()
        progress.doubleValue = 0.5
        progress.maxValue = 1.0
        progress.minValue = 1.0
        progress.indeterminate = false
        progress.bezeled = true
        progress.startAnimation(nil)

        tabController.tabStyle = .Toolbar
        tabController.tabView.allowsTruncatedLabels = true
        tabController.tabView.controlSize = .MiniControlSize

        self.addChildViewController(tabController)
        let tabView = tabController.view

        let viewMap = [
            "backButton": backButton,
            "forwardButton": forwardButton,
            "reloadButton": reloadButton,
            "stopButton": stopButton,
            "urlField": urlField,
            "tabView": tabView,
            "progress": progress,
        ]

        for control in viewMap.values {
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(control)
        }

        for constraints in [
            ("V:|-[urlField]-[tabView][progress]|", NSLayoutFormatOptions.AlignAllCenterX),
            ("H:|-[backButton]-[forwardButton]-[urlField]-[reloadButton]-[stopButton]-|", .AlignAllCenterY),
            ("H:|[tabView]|", nil),
            ("H:|[progress]|", nil),
            ] {
                NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat(constraints.0, options: constraints.1, metrics: nil, views: viewMap))
        }


        tabController.transitionOptions = .SlideForward
        tabController∞tabController.selectedTabViewItemIndex += {
            println("new tab: \($0)")
        }

        tabController∞(tabController.tabView.selectedTabViewItem, "tabView.selectedTabViewItem") += {
            println("view: \($0)")
        }

        // hook up the button commands to the current web view
        backButton.controlz() += { [weak self] _ in self?.webView?.goBack(); return }
        forwardButton.controlz() += { [weak self] _ in self?.webView?.goForward(); return }
        reloadButton.controlz() += { [weak self] _ in self?.webView?.reload(); return }
        stopButton.controlz() += { [weak self] _ in self?.webView?.stopLoading(); return }

        urlField.controlz() += { [weak self] _ in
            if let url = NSURL(string: urlField.stringValue) {
                self?.webView?.loadRequest(NSURLRequest(URL: url))
            }
        }

        addWebView()
    }

    override func viewDidAppear() {
        // we now have a window; synchronize its title to the currently selected tab
        if let window = self.view.window {
//            tabController∞tabController.title ∞=> window∞window.title
        }
    }


    func newDocument(sender: AnyObject?) {
        addWebView() // CMD-N will just open a new tab
    }

    func performClose(sender: AnyObject?) {
        let index = tabController.selectedTabViewItemIndex
        if index >= 0 {
            tabController.removeTabViewItem(tabController.tabView.tabViewItemAtIndex(index))
        }
    }

    func addWebView() {
        let webController = WebViewController()
        let tabItem = NSTabViewItem(viewController: webController)
        tabController.tabView.allowsTruncatedLabels = true
        webController.tabItem = tabItem
        webController.updateItemLabel()
        tabController.addTabViewItem(tabItem)
    }

}

class WebTabsController : NSTabViewController {
//    override func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
//        if let item = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag) {
//            println("toolbar item: \(item)")
//            let label = NSTextField()
//
//            label.stringValue = ""
//            label.editable = false
//            label.lineBreakMode = NSLineBreakMode.ByTruncatingMiddle
//            item.view = label
//
//            item.minSize = NSSize(width: 100, height: 10)
//            item.maxSize = NSSize(width: 100, height: 10)
//
//            return item
//        } else {
//            return nil
//        }
//    }

}

class WebViewController : NSViewController {
    let webView = WKWebView()
    var tabItem: NSTabViewItem?

    override func loadView() {
        self.view = webView

        if let item = tabItem {
//            item.label = ""
//            item.image = NSImage(named: NSImageNameListViewTemplate)
//            (webView∞webView.URL).map({ NSURLComponents(URL: $0!, resolvingAgainstBaseURL: false)?.host ?? "" }) ∞=> item∞item.toolTip
        }

        updateItemLabel()

        // just load a random wikipedia page to start
        webView.loadRequest(NSURLRequest(URL: NSURL(string: "https://en.wikipedia.org/wiki/Special:Random")!))
    }

    func updateItemLabel() {
        if let item = tabItem {
            var label = webView.title ?? ""
            if countElements(label) == 0 {
                label = "Untitled" // tab items always need a label
            }

//            while countElements(label) < 20 {
//                label = label + " "
//            }
//            while countElements(label) > 20 {
//                label = dropLast(label)
//            }

            item.label = label
//            item.label = "-"
            item.image = NSImage(named: NSImageNameExitFullScreenTemplate)

        }
    }

    override func viewDidDisappear() {
        // our tab was de-selected: disconnect our controls from the main buttons
    }

    override func viewDidAppear() {
        // out tab was selected: hook up our controls to the main buttons

//        webView∞webView.URL += { url in urlField.stringValue = url?.absoluteString ?? "" }
//        webView∞webView.canGoBack ∞=> backButton∞backButton.enabled
//        webView∞webView.canGoForward ∞=> forwardButton∞forwardButton.enabled
//        webView∞webView.title ∞=> tabItem∞tabItem.label
//        webView∞webView.loading ∞=> stopButton∞stopButton.enabled
        //        webView∞webView.estimatedProgress ∞=> progress∞progress.doubleValue


        // make the tab item draw a little circular progess pie
        if let item = tabItem {

            webView∞webView.estimatedProgress += { [weak self] progress in
//                item.image = drawProgressPie(CGFloat(progress))
                self?.updateItemLabel()
                return
            }
        }

//        (webView∞webView.estimatedProgress).map({ CGFloat($0) }) ∞=> webView∞webView.alphaValue

        //        (webView∞webView.loading).map({ !$0 }) ∞=> progress∞progress.hidden
        webView∞webView.loading += { println("loading: \($0)") }

//        (webView∞webView.title).filter({ $0 != nil }) ∞=> self∞self.title

//        self.view.window?.title = webView.title
    }

}


/// Helper function to make a little toolbar-style button
func makeButton(imageName: String) -> NSButton {
    let button = NSButton()
    button.setButtonType(NSButtonType.MomentaryChangeButton)
    button.bezelStyle = NSBezelStyle.RoundedBezelStyle
    button.image = NSImage(named: imageName)
    return button
}

func drawProgressPie(progress: CGFloat) -> NSImage {
    return NSImage(size: NSSize(width: 20, height: 20), flipped: false, drawingHandler: { rect in
        let center = NSPoint(x: 10, y: 10)

        let pie = NSBezierPath()
        pie.moveToPoint(center)
        pie.appendBezierPathWithArcWithCenter(center, radius: 10.0, startAngle: 365.0*progress, endAngle: 0.0, clockwise: true)
        pie.closePath()
        NSColor.lightGrayColor().set()
        pie.fill()

        // also draw an outline
        let path = NSBezierPath(ovalInRect: NSRect(x: 1, y: 1, width: 18, height: 18))
        path.lineWidth = 1.0
        NSColor.grayColor().set()
        path.stroke()

        return true
    })
}