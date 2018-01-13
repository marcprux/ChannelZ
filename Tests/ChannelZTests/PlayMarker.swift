////
////  PlayMarker.swift
////  ChannelZ
////
////  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
////  License: MIT (or whatever)
////
//
//#if os(macOS) // NSXMLDocument is only on Mac
//
//import Foundation
//
///// Tool to convert simple CommonMark files with embedded swift source code into Xcode Playground files
//class PlayMarker {
//    var output: [(name: String, contents: String)] = []
//    var root = XMLElement(name: "div")
//    var node : XMLElement
//    let scanner: Scanner
//
//    init(commonMark: String) {
//        node = root
//        scanner = Scanner(string: "\n" + commonMark) // prefix with newline for header detection
//        scanner.charactersToBeSkipped = CharacterSet.illegalCharacters
//    }
//
//    /// Given the markdown file at the specified path, generate a .playground folder for the file
//    class func generatePlaydown(_ commonMarkPath: URL, playgroundFolder: URL? = nil) throws -> [URL] {
//        var urls: [URL] = []
//
//        if let outputURL = playgroundFolder ?? commonMarkPath.deletingPathExtension().appendingPathExtension("playground") {
//            let string = try String(contentsOf: commonMarkPath, usedEncoding: nil)
//            let marker = PlayMarker(commonMark: string)
//            marker.convertBlocks()
//
//            for output in marker.output {
//                if let data = output.contents.data(using: String.Encoding.utf8) {
//                    let dataURL = outputURL.appendingPathComponent(output.name)
//                    if let dataDir = dataURL.deletingLastPathComponent() {
//                        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true, attributes: nil)
//                    }
//
//                    let existingData = (try? Data(contentsOf: dataURL)) ?? Data()
//                    if existingData != data {
//                        NSLog("writing playground file to: \(dataURL)")
//                        try data.write(to: dataURL, options: NSData.WritingOptions.atomicWrite)
//                        urls += [dataURL]
//                    }
//                }
//            }
//        }
//
//        return urls
//    }
//
//    fileprivate func scan(_ token: String) -> Bool {
//        return scanner.scanString(token, into: nil)
//    }
//
//    fileprivate func scanTo(_ token: String) -> String {
//        var string: NSString?
//        if scanner.scanUpTo(token, into: &string) {
//        } else {
//            scanner.scanString(token, into: nil) // consume the token
//        }
//
//        return string?.description ?? ""
//    }
//
//    fileprivate func scanThrough(_ token: String) -> String {
//        let scanned = scanTo(token)
//        scan(token)
//        return scanned
//    }
//
//    fileprivate func append(_ string: String?) {
//        if let str = string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
//            if !str.isEmpty {
//                element(node, "p", ("class", "para")).stringValue = str
//            }
//        }
//    }
//
//    func generateContents() {
//        // https://developer.apple.com/library/ios/documentation/Swift/Reference/Playground_Ref/Chapters/InteractiveLearning.html
//        let playground = element(nil, "playground", ("version", "3.0"), ("sdk", "iphonesimulator"), ("allows-reset", "YES"))
//
//        let contentDoc = XMLDocument(rootElement: playground)
//        contentDoc.isStandalone = true
//        contentDoc.version = "1.0"
//        contentDoc.characterEncoding = "UTF-8"
//
//        let sections = element(playground, "sections")
//        for section in output {
//            let sname: NSString = (section.name as NSString)
//            if sname.pathExtension == "html" {
//                element(sections, "documentation", ("relative-path", sname.lastPathComponent))
//            } else if sname.pathExtension == "swift" {
//                element(sections, "code", ("source-file-name", sname.lastPathComponent))
//            }
//        }
//
//        output += [("contents.xcplayground", contentDoc.xmlString(withOptions: Int(NSXMLNodePrettyPrint)))]
//
//    }
//
//    func generateCSS() {
//        output += [("Documentation/playdown.css", css)]
//    }
//
//    func pushXHTMLContent() {
//        output += [("Documentation/fragment-\(output.count).html", toXHTML(root))]
//        root = XMLElement(name: "div") // fresh new root node
//        toRoot()
//    }
//
//    func pushSwiftContent(_ code: String) {
//        output += [("section-\(output.count).swift", code)]
//    }
//
//    func toRoot() -> XMLElement {
//        node = root
//        return node
//    }
//
//    let patterns: [(NSRegularExpression, String, Int)] = [
//        (try! NSRegularExpression(pattern: "&", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "&amp;", 0),
//        (try! NSRegularExpression(pattern: "<", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "&lt;", 0),
//        (try! NSRegularExpression(pattern: ">", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "&gt;", 0),
//        (try! NSRegularExpression(pattern: "`(.*?)`", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "<code class='code-voice'>$1</code>", 1),
//        (try! NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "<strong>$1</strong>", 1),
//        (try! NSRegularExpression(pattern: "\\*(.*?)\\*", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "<em>$1</em>", 1),
//        (try! NSRegularExpression(pattern: "\\[(.*?)\\]\\(#(.*?)\\)", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "<em>$1</em>", 1), // no support for intra-Playground anchor links
//        (try! NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: NSRegularExpression.Options.allowCommentsAndWhitespace), "<a href='$2'>$1</a>", 1),
//    ]
//
//    /// Single-line scans use regualar expressions to parse for bold/italic/monospace
//    func scanLine() -> String {
//        let scanned = scanTo("\n")
//        var line = NSMutableString(string: scanned)
//
//        func replace(_ exp: NSRegularExpression, str: String) -> Int {
//            return exp.replaceMatches(in: line, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, line.length), withTemplate: str)
//        }
//
//        var reps = 0
//        for pattern in patterns {
//            let exp = pattern.0
//            let rep = pattern.1
//            let significance = pattern.2
//
//            reps += replace(exp, str: rep) * significance
//        }
//
//        // maybe HTML: parse it and add it as a child node
//        if reps > 0 {
//            return "<span>" + line.description + "</span>"
//        } else {
//            return scanned
//        }
//    }
//
//    func scanChild(_ child: XMLElement) {
//        let line = scanLine().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//        if !line.isEmpty {
//            if line.characters.index(of: "<") != nil {
//                // maybe HTML: parse it and add it as a child node
//                do {
//                    let parsed = try XMLDocument(xmlString: line, options: Int(NSXMLNodePreserveWhitespace))
//                    if let root = parsed.rootElement() {
//                        root.detach()
//                        child.addChild(root)
//                    }
//                } catch {
//                    child.stringValue = line
//                }
//            } else {
//                child.stringValue = line
//            }
//        } else {
//            child.detach()
//        }
//    }
//
//    func appendHeader(_ level: UInt8) {
//        while let parent = node.parent as? XMLElement { node = parent }
//        let attrs = level <= 2 ? ("class", "chapter-name") : ("class", "section-name")
//        scanChild(element(toRoot(), "h\(level)", attrs))
//    }
//
//    /// High-level conversion of blocks to code
//    func convertBlocks() {
//        let _: NSString?
//
//        while !scanner.isAtEnd {
//            if scan("\n```swift") {
//                // swift code is special: we make new playground output files for the pending document and the swift code
//                let swiftCode = scanThrough("```")
//                scanLine()  // ignore any trailing marks
//                pushXHTMLContent()
//                pushSwiftContent(swiftCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
//            } else if scan("<!--") {
//                _ = scanThrough("-->")
//            } else if scan("\n###### ") {
//                appendHeader(6)
//            } else if scan("\n##### ") {
//                appendHeader(5)
//            } else if scan("\n#### ") {
//                appendHeader(4)
//            } else if scan("\n### ") {
//                appendHeader(3)
//            } else if scan("\n## ") {
//                appendHeader(2)
//            } else if scan("\n# ") {
//                appendHeader(1)
//            } else if scan("\n* ") || scan("\n- ") {
//                // start an unordered list if needed
//                if node.name != "ul" { node = element(node, "ul", ("class", "list-bullet")) }
//                scanChild(element(element(node, "li", ("class", "item")), "p", ("class", "para")))
//            } else if scan("\n1. ") {
//                // start an ordered list if needed
//                if node.name != "ol" { node = element(node, "ol", ("class", "list-number")) }
//                scanChild(element(element(node, "li", ("class", "item")), "p", ("class", "para")))
//            } else if scan("\n> ") {
//                // start an aside for block quotes
//                if node.name != "aside" {
//                    node = element(element(node, "div", ("class", "note")), "aside", ("class", "aside"))
//                }
//                scanChild(element(node, "p", ("class", "para")))
//            } else if scan("\n```") {
//                while let parent = node.parent as? XMLElement { node = parent }
//                element(toRoot(), "code").stringValue = scanThrough("```")
//                scanLine() // ignore any trailing marks
//            } else {
//                while let parent = node.parent as? XMLElement { node = parent }
//                scanChild(element(toRoot(), "p", ("class", "para")))
//            }
//        }
//
//        pushXHTMLContent() // the last document
//        generateCSS()
//        generateContents()
//    }
//
//
//    func toXHTML(_ element: XMLElement) -> String {
//        var xhtml = "<!DOCTYPE html>\n"
//        if let root = createDocument(element).rootElement() {
//            let options = NSXMLNodeCompactEmptyElement // | NSXMLNodePrettyPrint
//            xhtml += root.xmlString(withOptions: Int(options))
//        }
//        return xhtml
//    }
//
//    func attr(_ name: String, _ value: String) -> XMLNode {
//        return XMLNode.attribute(withName: name, stringValue: value) as! XMLNode
//    }
//
//    func element(_ parent: XMLElement?, _ name: String, _ attributes: (name: String, value: String)...) -> XMLElement {
//        let element = XMLElement(name: name)
//        for attribute in attributes {
//            element.addAttribute(attr(attribute.name, attribute.value))
//        }
//        if let parent = parent {
//            parent.addChild(element)
//        }
//        return element
//    }
//
//    /// Creates an XHTML document wrappen the given content node
//    func createDocument(_ content: XMLElement) -> XMLDocument {
//        let rootElement = element(nil, "html", ("lang", "en"))
//
//        let doc = XMLDocument(rootElement: rootElement)
//        doc.isStandalone = true
//        doc.documentContentKind = .xhtml
//
//        let head = element(rootElement, "head")
//        let title = element(head, "title")
//        title.stringValue = "Playground"
//        
//        _ = element(head, "link", ("rel", "stylesheet"), ("type", "text/css"), ("href", "playdown.css"))
//        _ = element(head, "meta", ("charset", "utf-8"))
//        _ = element(head, "meta", ("id", "xcode-display"), ("name", "xcode-display"), ("content", "render"))
//        _ = element(head, "meta", ("name", "apple-mobile-web-app-capable"), ("content", "yes"))
//        _ = element(head, "meta", ("name", "viewport"), ("content", "width = device-width, maximum-scale=1.0"))
//
//
//        let body = element(rootElement, "body", ("id", "conceptual_flow_with_tasks"), ("class", "jazz"))
//        let div = element(body, "div", ("class", "content-wrapper"))
//        let article = element(div, "article", ("class", "chapter>"))
//        let section = element(article, "section", ("class", "section"))
//
//        content.detach()
//        section.addChild(content)
//
//        return doc
//    }
//
//
//    // Standard CSS from Apple playground samples
//    let css =  "html,body,div,span,applet,object,iframe,h1,h2,h3,h4,h5,h6,p,blockquote,pre,a,abbr,acronym,address,big,cite,code,del,dfn,em,figure,font,img,ins,kbd,q,s,samp,small,strike,strong,sub,sup,tt,var,b,u,i,center,dl,dt,dd,ol,ul,li,fieldset,form,label,legend,table,caption,tbody,tfoot,thead,tr,th,td {\n/* background: transparent; */\nborder: 0;\nfont-size: 100%;\nmargin: 0;\noutline: 0;\npadding: 0;\nvertical-align: baseline\n}\nbody.jazz {\nbackground-color: rgba(255,255,255,0.65);\ncolor: rgba(0,0,0,1);\nfont-family: Helvetica,Arial,sans-serif;\nfont-size: 62.5%;\nmargin-left: 15px;\n}\n.jazz a[name] {\ndisplay: block;\npadding-top: 85px;\nmargin: -95px 0 0\n}\n.jazz .content-wrapper {\n/* background-color: rgba(255,255,255,1); */\nmargin: 0 auto;\n}\n.jazz .chapter {\n/* background-color: rgba(255,255,255,1); */\nborder: 1px solid rgba(238,238,238,1);\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\ndisplay: block;\nmargin-left: 246px;\nmin-height: calc(100% - 173px);\nmin-height: -moz-calc(100% - 173px);\nmin-height: -webkit-calc(100% - 173px);\nmin-height: -o-calc(100% - 173px);\nposition: absolute;\noverflow: auto;\npadding-bottom: 100px;\ntop: 70px;\n-webkit-overflow-scrolling: touch;\n}\n.jazz #mini_toc {\n/* background-color: rgba(255,255,255,1); */\nbackground-image: url(../Images/plus_2x.png);\nbackground-position: 90% 11px;\nbackground-repeat: no-repeat;\nbackground-size: 12px 12px;\nborder: 1px solid rgba(238,238,238,1);\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\nmargin-left: 505px;\npadding: 10px 10px 0 15px;\nposition: fixed;\ntop: 85px;\nwidth: 190px;\nz-index: 1;\noverflow: auto;\nheight: 25px;\nmax-height: 500px;\n-webkit-transition: height .3s ease,-webkit-transform .3s ease;\n-moz-transition: height .3s ease,-moz-transform .3s ease;\n-o-transition: height .3s ease,-o-transform .3s ease;\n-ms-transition: height .3s ease,-ms-transform .3s ease;\ntransition: height .3s ease,transform .3s ease\n}\n.jazz #mini_toc.slide-out {\n-webkit-transform: translateY(-85px);\n-moz-transform: translateY(-85px);\n-o-transform: translateY(-85px);\n-ms-transform: translateY(-85px);\ntransform: translateY(-85px)\n}\n.jazz #mini_toc.open {\nbackground-image: url(../Images/minus_2x.png);\nz-index: 2\n}\n.jazz #mini_toc #mini_toc_button {\ncursor: pointer;\nwidth: 195px\n}\n\n.jazz .section {\npadding: 20px 25px 20px 35px\n}\n.jazz .section .section {\nmargin: 30px 0 0;\npadding: 0\n}\n.jazz .clear {\n}\n.jazz .two-columns {\nclear: both;\ndisplay: table;\nmargin: 60px auto;\nvertical-align: middle;\nwidth: 85%\n}\n.jazz .left-column,.jazz .right-column {\ndisplay: table-cell;\nheight: 100%;\nvertical-align: middle\n}\n.jazz .left-column {\npadding-right: 10px\n}\n.jazz .right-column {\npadding-left: 10px\n}\n.jazz .right-column.left-align {\nwidth: 100%\n}\n.jazz .right-column.left-align .para {\ncolor: rgba(128,128,128,1);\nfont-size: 1.6em\n}\n.jazz .two-columns .inline-graphic {\nmargin: 0 auto;\ntext-align: center\n}\n.jazz .two-columns .para {\nclear: both;\nfont-size: 1.4em\n}\n.jazz #ios_header {\n/* background-color: rgba(65,65,65,1); */\nbox-shadow: 0 1px 1px rgba(0,0,0,.07);\ncolor: rgba(255,255,255,1);\nheight: 25px;\nletter-spacing: .05em;\nposition: fixed;\ntop: 0;\nwidth: 100%;\nz-index: 4\n}\n.jazz .header-text {\nfont-size: 1.1em;\nmargin: 0 auto;\npadding-top: 6px;\nvertical-align: middle;\nfloat: left\n}\n.jazz .header-text a {\ncolor: rgba(255,255,255,1);\ntext-decoration: none\n}\n.jazz #apple_logo {\npadding-right: 8px;\nvertical-align: -2px\n}\n.jazz #wwdr {\nfloat: right;\npadding-top: 4px;\nfont-size: 1.1em;\nvertical-align: middle;\nmargin: 0 auto\n}\n.jazz #wwdr a {\ncolor: rgba(255,255,255,1);\ntext-decoration: none\n}\n.jazz #valence {\n/* background-color: rgba(242,242,242,1); */\ndisplay: block;\nheight: 60px;\npadding-top: 10px;\nposition: fixed;\ntop: 0;\nwidth: 100%;\nz-index: 3\n}\n.jazz #hierarchial_navigation {\nfloat: left;\nfont-size: 1.4em;\nmargin-top: 29px;\nvertical-align: middle\n}\n.jazz #carat {\nmargin: 0 10px\n}\n.jazz #design_resources_link {\ncolor: rgba(0,136,204,1);\ntext-decoration: none\n}\n.jazz #book_title {\ncolor: rgba(0,0,0,1);\nfont-size: 1em\n}\n.jazz .download-text {\ncolor: rgba(0,136,204,1);\nfloat: right;\nfont-size: 1.1em;\nmargin-right: 20px;\nmargin-top: 32px;\ntext-decoration: none\n}\n.jazz input[type=search] {\nbackground-size: 14px 14px;\nbackground-image: url(../Images/magnify_2x.png);\nbackground-position: 3% 50%;\nbackground-repeat: no-repeat;\nborder: 1px solid rgba(238,238,238,1);\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\n-webkit-appearance: none;\nfloat: right;\nfont-family: Helvetica,Arial,sans-serif;\nfont-size: 1.1em;\nheight: 30px;\nmargin-right: -2px;\nmargin-top: 23px;\npadding-left: 18px;\nvertical-align: middle;\nwidth: 177px\n}\n.jazz #shortstack {\ndisplay: none\n}\n.jazz .para {\ncolor: rgba(65,65,65,1);\nfont-size: 1.4em;\nline-height: 145%;\nmargin-bottom: 5px;\n\n}\n.jazz .chapter-name {\ncolor: rgba(0,0,0,1);\ndisplay: block;\nfont-family: Helvetica;\nfont-size: 2.8em;\nfont-weight: 100;\nmargin-bottom: 0;\npadding: 15px 25px;\nwidth: 63%\n}\n.jazz #mini_toc p {\nfont-size: 1.4em\n}\n.jazz #mini_toc .list-bullet a {\ncolor: rgba(0,136,204,1);\nlist-style-type: none;\nlist-style-position: outside;\nmargin-left: 0;\npadding-left: 0;\ntext-decoration: none\n}\n.jazz #mini_toc ul.list-bullet {\nlist-style-type: none;\nmargin-bottom: 0;\nmargin-left: 0;\nmargin-top: 15px;\noverflow: hidden;\npadding-left: 0;\nwidth: 167px;\ndisplay: none\n}\n.jazz #mini_toc.open ul.list-bullet {\ndisplay: block\n}\n.jazz #mini_toc ul.list-bullet li.item {\npadding-left: 0;\ndisplay: block\n}\n.jazz #mini_toc ul.list-bullet li.item:before {\ncontent: none\n}\n.jazz #mini_toc ul.list-bullet li.item .para {\ncolor: rgba(0,136,204,1);\nfont-size: 1.4em;\nline-height: 135%;\npadding-bottom: 22px;\ntext-decoration: none\n}\n.jazz .chapter a {\ncolor: rgba(0,136,204,1);\ntext-decoration: none\n}\n.jazz h3.section-name:before {\ndisplay: block;\ncontent: \" \";\nmargin-top: -85px;\nheight: 85px;\nvisibility: hidden\n}\n.jazz .section-name {\ncolor: rgba(128,128,128,1);\ndisplay: block;\nfont-family: Helvetica;\nfont-size: 2.2em;\nfont-weight: 100;\nmargin-bottom: 15px;\nmargin-top: 20px;\n}\n.jazz .section .section .section-name {\ncolor: rgba(0,0,0,1);\nfont-size: 1.8em;\nletter-spacing: 0;\npadding-top: 20px\n}\n.jazz .section .section .section .section-name {\nfont-size: 1.6em;\npadding-top: 0\n}\n.jazz .title-three {\ncolor: rgba(0,0,0,1);\nfont-size: 2em;\nfont-weight: 400;\nmargin-bottom: 10px\n}\n.jazz .inline-head {\n}\n.jazz .code-voice {\ncolor: rgba(128,128,128,1);\nfont-family: Menlo,monospace;\nfont-size: .9em;\nword-wrap: break-word\n}\n.jazz .copyright {\nclear: both;\ncolor: rgba(160,160,160,1);\nfloat: none;\nmargin: 70px 25px 10px 0\n}\n.jazz .link {\ncolor: rgba(0,136,204,1);\ntext-decoration: none\n}\n.jazz .u-book {\n}\n.jazz .pediaLink {\n}\n.jazz .x-name-no-link {\n}\n.jazz .u-api {\n}\n.jazz ul.list-bullet {\nlist-style: none;\nmargin-bottom: 12px;\nmargin-left: 24px;\npadding-left: 0\n}\n.jazz ul.list-bullet li.item {\nlist-style-type: none;\nlist-style-image: none;\npadding-left: 1.3em;\nposition: relative\n}\n.jazz .aside ul.list-bullet li.item {\npadding-left: 1.1em\n}\n.jazz ul.list-bullet li.item:before {\ncolor: rgba(65,65,65,1);\ncontent: \"\\02022\";\nfont-size: 1.5em;\nleft: 0;\npadding-top: 2px;\nposition: absolute\n}\n.jazz .aside ul.list-bullet li.item:before {\nfont-size: 1.2em;\nmargin-top: -2px\n}\n.jazz .list-number,.jazz .list-simple,.jazz .list-check {\nmargin-bottom: 12px;\nmargin-left: 20px;\npadding-left: 20px\n}\n.jazz .list-number {\ncolor: rgba(65,65,65,1);\nfont-size: 1.4em\n}\n.jazz .aside .list-number {\nfont-size: 1em\n}\n.jazz ol.list-number li.item ol.list-number {\nfont-size: 1em\n}\n.jazz .list-number .item p {\nfont-size: 1em\n}\n.jazz .list-simple {\nlist-style-type: none\n}\n.jazz .list-check {\nlist-style: url(../Images/check.png) outside none\n}\n.jazz .item p {\nmargin: 0;\npadding-bottom: 6px\n}\n.jazz .book-parts {\n/* background-color: rgba(249,249,249,1); */\nborder: 1px solid rgba(238,238,238,1);\nbottom: 0;\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\ndisplay: block;\noverflow: auto;\n-webkit-overflow-scrolling: touch;\nposition: fixed;\ntop: 70px;\nwidth: 230px\n}\n.jazz .nav-parts {\ncolor: rgba(128,128,128,1);\nfont-weight: 100;\nline-height: 140%;\nlist-style-type: none;\nmargin: 0;\n-webkit-padding-start: 0\n}\n.jazz .part-name {\nborder-bottom: 1px solid rgba(238,238,238,1);\nfont-family: Helvetica;\nfont-size: 1.6em;\nline-height: 150%;\nlist-style-type: none;\nmargin: 0;\npadding: 15px 30px 15px 20px;\ncursor: pointer\n}\n.jazz .nav-chapters {\nfont-weight: 400;\nline-height: 110%;\nlist-style-position: outside;\nlist-style-type: none;\nmargin: 0;\npadding: 0;\nheight: 0;\noverflow: hidden;\n-webkit-transition: height .3s ease-in-out;\n-moz-transition: height .3s ease-in-out;\n-o-transition: height .3s ease-in-out;\n-ms-transition: height .3s ease-in-out;\ntransition: height .3s ease-in-out\n}\n.jazz .nav-chapter {\nfont-size: .8em;\nlist-style-position: outside;\nlist-style-type: none;\nmargin: 0;\npadding: 0 0 8px\n}\n.jazz .nav-chapters .nav-chapter {\nmargin-left: 0\n}\n.jazz .nav-chapter .nav-chapter-active {\ncolor: rgba(0,0,0,1);\nfont-weight: 700;\ntext-decoration: none\n}\n.jazz .book-parts a {\ncolor: rgba(128,128,128,1);\ndisplay: block;\nmargin-left: 15px;\ntext-decoration: none\n}\n.jazz .aside-title {\ncolor: rgba(128,128,128,1);\nfont-size: .6em;\nletter-spacing: 2px;\nmargin-bottom: 8px;\ntext-transform: uppercase\n}\n.jazz .tip,.jazz .warning,.jazz .important,.jazz .note {\nbackground-color: rgba(249,249,249,1);\nborder-left: 5px solid rgba(238,238,238,1);\ncolor: rgba(0,0,0,1);\nfont-size: 1.2em;\nmargin: 25px 45px 35px 35px;\npadding: 15px 15px 7px;\n\n}\n.jazz .note .para,.jazz .important .para,.jazz .tip .para,.jazz .warning .para {\nfont-size: 1em;\nmargin-bottom: 8px\n}\n.jazz .note {\nborder-left: 5px solid rgba(238,238,238,1)\n}\n.jazz .important {\nborder-left: 5px solid rgba(128,128,128,1)\n}\n.jazz .tip {\nborder-left: 5px solid rgba(238,238,238,1)\n}\n.jazz .warning {\nborder-left: 5px solid rgba(247,235,97,1)\n}\n.jazz .rec-container {\nmargin: 40px auto;\ntext-align: center;\nwidth: 95%\n}\n.jazz .rec-container .blurb {\ntext-align: center\n}\n.jazz .rec-container .blurb .para:nth-child(1) {\ncolor: rgba(128,128,128,1);\nfont-size: 2em;\nfont-weight: 100;\nline-height: 120%;\nmargin: 0 auto 20px;\nwidth: 460px\n}\n.jazz .rec-container .blurb .para {\nmargin-bottom: 20px\n}\n.jazz .rec-container .left-container,.jazz .rec-container .right-container {\ndisplay: table-cell;\nmargin-top: 20px;\nwidth: 325px\n}\n.jazz .rec-container .left-container {\npadding-right: 10px\n}\n.jazz .rec-container .right-container {\npadding-left: 10px\n}\n.jazz .rec-container .container-label {\nfont-size: 1.5em;\nmargin-bottom: 10px\n}\n.jazz .rec-container .do {\ncolor: rgba(17,183,40,1)\n}\n.jazz .rec-container .do-not {\ncolor: rgba(208,50,54,1)\n}\n.jazz .rec-container .recommended {\ncolor: rgba(40,103,206,1)\n}\n.jazz .rec-container .not-recommended {\ncolor: rgba(255,133,0,1)\n}\n.jazz .rec-container .inline-graphic {\nmargin: 10px auto;\nmax-width: 100%\n}\n.jazz .code-listing {\nbackground-clip: padding-box;\nmargin: 20px 0;\ntext-align: left\n}\n.jazz .item .code-listing {\npadding: 0;\nmargin: 0 0 15px\n}\n.jazz .code-listing .caption {\ncaption-side: top;\ndisplay: block;\nfont-size: 1.1em;\ntext-align: left;\nmargin-bottom: 16px\n}\n.jazz>.content-wrapper>.chapter>.section>.list-number>.item>.code-listing {\npadding-top: 0;\npadding-bottom: 5px;\nmargin-top: 0;\nmargin-bottom: 0\n}\n.jazz .code-sample {\n/* background-color: rgba(249,249,249,1); */\ndisplay: block;\nfont-size: 1.4em;\nmargin-left: 20px\n}\n.jazz ol .code-sample {\nfont-size: 1em\n}\n.jazz .code-lines {\n/* background-color: rgba(255,255,255,1); */\ncounter-reset: li;\nline-height: 1.6em;\nlist-style: none;\nmargin: 0 0 0 20px;\npadding: 0\n}\n.jazz pre {\nwhite-space: pre-wrap\n}\n.jazz .code-lines li:before {\ncolor: rgba(128,128,128,1);\ncontent: counter(li);\ncounter-increment: li;\nfont-family: Menlo,monospace;\nmargin-right: 10px;\n-webkit-user-select: none\n}\n.jazz .code-lines li {\npadding-left: 10px;\ntext-indent: -24px;\nwhite-space: pre\n}\n.jazz .code-lines li:nth-child(n+10) {\ntext-indent: -28px\n}\n.jazz .code-lines li:nth-child(n+10):before {\nmargin-right: 6px\n}\n.jazz #next_previous {\nbottom: 0;\ncolor: rgba(0,136,204,1);\nmargin: 0 25px;\nposition: absolute;\nwidth: 684px\n}\n.jazz .next-link a,.jazz .previous-link a {\nbackground-size: 6px 12px;\nbackground-repeat: no-repeat;\nfont-size: 1.4em;\nmargin-bottom: 50px;\nmargin-top: 50px;\nwidth: 45%\n}\n.jazz .next-link a {\nbackground-image: url(../Images/right_arrow_2x.png);\nbackground-position: 100% 50%;\nfloat: right;\npadding-right: 16px;\ntext-align: right\n}\n.jazz .previous-link a {\nbackground-image: url(../Images/left_arrow_2x.png);\nbackground-position: 0 50%;\nfloat: left;\npadding-left: 16px;\ntext-align: left\n}\n.jazz #footer {\nbottom: 0;\nposition: fixed;\nwidth: 100%\n}\n.jazz #leave_feedback {\ndisplay: none\n}\n.jazz #footer #leave_feedback {\n/* background-color: rgba(160,160,160,1); */\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\ncolor: rgba(255,255,255,1);\nfont-size: 1.1em;\nmargin-left: 912px;\npadding: 5px 10px;\nposition: absolute;\ntext-align: center;\nright: auto;\nz-index: 3;\ndisplay: block\n}\n.jazz #modal {\nfont-family: Helvetica,Arial,sans-serif;\n-webkit-border-radius: 0;\nwidth: 600px\n}\n.jazz #modal #feedback h2 {\nfont-size: 1.5em;\nfont-weight: 100;\nmargin-bottom: 10px\n}\n.jazz #modal #feedback #star_group,.jazz #modal #feedback #improve {\ntop: 0\n}\n.jazz #modal #feedback #star_group label,.jazz #modal #feedback .right-leaf,.jazz #modal #feedback .checkboxes label {\ncolor: rgba(0,0,0,1)\n}\n.jazz #modal #feedback #star_group label {\nwidth: 200px\n}\n.jazz #modal #feedback .right-leaf {\nwidth: 297px\n}\n.jazz #modal #feedback #comment,.jazz #modal #feedback #email {\nborder: 1px solid rgba(128,128,128,1);\nfont-family: Helvetica,Arial,sans-serif\n}\n.jazz #modal #feedback #comment {\nmargin: 26px 0 12px\n}\n.jazz #modal #feedback #email {\nheight: 13px\n}\n.jazz #modal #feedback #submit {\n/* background-color: rgba(160,160,160,1); */\nbackground-image: none;\ncolor: rgba(255,255,255,1);\nfont-family: Helvetica,Arial,sans-serif;\nheight: 27px;\nmargin: 0 0 0 6px;\n-webkit-border-radius: 0\n}\n.jazz #modal #feedback #legal {\nmargin-top: 22px\n}\n.jazz .caption {\ncaption-side: top;\ndisplay: block;\nfont-size: 1.1em;\ntext-align: left;\nmargin-bottom: 8px\n}\n.jazz .figure {\nmargin: 40px auto;\ntext-align: center\n}\n.jazz .inline-graphic {\nmargin: 20px auto;\ntext-align: center;\ndisplay: block\n}\n.jazz tr td .para .inline-graphic {\nmargin: 10px 0\n}\n.jazz .list-bullet .item .para .inline-graphic,.jazz .list-number .item .para .inline-graphic {\nmargin: 0 4px;\ndisplay: inline;\nvertical-align: middle\n}\n.jazz .tableholder {\n}\n.jazz .tablecaption {\ncaption-side: top;\nfont-size: 1.1em;\ntext-align: left;\nmargin-bottom: 8px\n}\n.jazz ol .tablecaption {\nfont-size: .78em\n}\n.jazz .caption-number {\npadding-right: .4em\n}\n.jazz .graybox {\nborder: 1px solid rgba(238,238,238,1);\nborder-collapse: collapse;\nborder-spacing: 0;\nempty-cells: hide;\nmargin: 20px 0 36px;\ntext-align: left;\nwidth: 100%\n}\n.jazz .graybox p {\nmargin: 0\n}\n.jazz .TableHeading_TableRow_TableCell {\npadding: 5px 10px;\nborder-left: 1px solid rgba(238,238,238,1);\n/* background-color: rgba(249,249,249,1); */\nfont-weight: 400;\nwhite-space: normal\n}\n.jazz td {\nborder: 1px solid rgba(238,238,238,1);\npadding: 5px 25px 5px 10px;\nmargin: 0;\nvertical-align: middle;\nmax-width: 260px\n}\n.jazz .row-heading {\n/* background-color: rgba(249,249,249,1) */\n}\n.video-container {\nposition: relative\n}\n.video-container video {\noutline: 0;\n-webkit-transition: -webkit-filter .3s ease;\n-moz-transition: -moz-filter .3s ease;\n-o-transition: -o-filter .3s ease;\ncursor: pointer\n}\n.playButtonOverlay {\nopacity: 1;\ndisplay: block;\n-webkit-transition: opacity .3s ease;\nposition: absolute;\nbackground: url(../Images/playbutton.svg) no-repeat;\nbackground-size: cover;\nleft: 312px;\nwidth: 60px;\nheight: 60px;\npointer-events: none;\ntop: 40%\n}\n.playButtonOverlay.hide {\nopacity: 0\n}\n.jazz #big_button.active {\nposition: fixed;\ntop: 0;\nbottom: 0;\nleft: 0;\nright: 0;\nz-index: 1;\n/* background-color: transparent */\n}\n#conceptual_flow_with_tasks #carat {\nmargin: 0 10px\n}\n#conceptual_flow_with_tasks #design_resources_link {\ncolor: rgba(0,136,204,1);\ntext-decoration: none\n}\n#conceptual_flow_with_tasks .list-check {\nlist-style: url(../Images/check.png) outside none\n}\n#conceptual_flow_with_tasks .nav-part-active {\n/* background-color: rgba(255,255,255,1); */\ncolor: rgba(0,0,0,1);\ncursor: default\n}\n#conceptual_flow_with_tasks .nav-chapters {\nfont-weight: 400;\nline-height: 110%;\nlist-style-position: outside;\nlist-style-type: none;\nmargin: 0;\npadding: 0;\nheight: 0;\noverflow: hidden;\n-webkit-transition: height .3s ease-in-out;\n-moz-transition: height .3s ease-in-out;\n-o-transition: height .3s ease-in-out;\n-ms-transition: height .3s ease-in-out;\ntransition: height .3s ease-in-out\n}\n#conceptual_flow_with_tasks .nav-part-active .nav-chapters {\nmargin: 15px 0 0\n}\n#conceptual_flow_with_tasks .nav-chapter {\nfont-size: .8em;\nlist-style-position: outside;\nlist-style-type: none;\nmargin: 0;\npadding: 0 0 8px\n}\n#conceptual_flow_with_tasks .nav-chapters .nav-chapter {\nmargin-left: 0\n}\n#conceptual_flow_with_tasks .nav-chapter .nav-chapter-active {\ncolor: rgba(0,0,0,1);\nfont-weight: 700;\ntext-decoration: none\n}\n#conceptual_flow_with_tasks .book-parts a {\ncolor: rgba(128,128,128,1);\ndisplay: block;\nmargin-left: 15px;\ntext-decoration: none\n}\n#conceptual_flow_with_tasks .rec-container {\nmargin: 40px auto;\ntext-align: center;\nwidth: 95%\n}\n#conceptual_flow_with_tasks .rec-container .blurb {\ntext-align: center\n}\n#conceptual_flow_with_tasks .rec-container .blurb .para:nth-child(1) {\ncolor: rgba(128,128,128,1);\nfont-size: 2em;\nfont-weight: 100;\nline-height: 120%;\nmargin: 0 auto 20px;\nwidth: 460px\n}\n#conceptual_flow_with_tasks .rec-container .blurb .para {\nmargin-bottom: 20px\n}\n#conceptual_flow_with_tasks .rec-container .left-container,#conceptual_flow_with_tasks .rec-container .right-container {\ndisplay: table-cell;\nmargin-top: 20px;\nwidth: 325px\n}\n#conceptual_flow_with_tasks .rec-container .left-container {\npadding-right: 10px\n}\n#conceptual_flow_with_tasks .rec-container .right-container {\npadding-left: 10px\n}\n#conceptual_flow_with_tasks .rec-container .container-label {\nfont-size: 1.5em;\nmargin-bottom: 10px\n}\n#conceptual_flow_with_tasks .rec-container .do {\ncolor: rgba(17,183,40,1)\n}\n#conceptual_flow_with_tasks .rec-container .do-not {\ncolor: rgba(208,50,54,1)\n}\n#conceptual_flow_with_tasks .rec-container .recommended {\ncolor: rgba(40,103,206,1)\n}\n#conceptual_flow_with_tasks .rec-container .not-recommended {\ncolor: rgba(255,133,0,1)\n}\n#conceptual_flow_with_tasks .rec-container .inline-graphic {\nmargin: 10px auto;\nmax-width: 100%\n}\n#roadmap.jazz .nav-chapters {\nfont-weight: 400;\nline-height: 110%;\nlist-style-position: outside;\nlist-style-type: none;\nmargin: 0;\npadding: 8px 0 0;\nheight: 100%;\nwidth: 200px\n}\n#roadmap .nav-part-active {\n/* background-color: rgba(255,255,255,1); */\ncolor: rgba(0,0,0,1);\ncursor: default\n}\n#roadmap.jazz .conceptual-with-tasks:before {\nborder: 2px solid rgba(128,128,128,1);\nborder-radius: 50%;\ncontent: \"\";\ndisplay: block;\nfloat: left;\nheight: 10px;\nmargin: 2px 8px 0 0;\nwidth: 10px\n}\n#roadmap.jazz .tutorial:before {\nborder: 2px solid rgba(128,128,128,1);\ncontent: \"\";\ndisplay: block;\nfloat: left;\nheight: 10px;\nmargin: 2px 8px 0 0;\nwidth: 10px\n}\n#roadmap.jazz .nav-visited-chapter.conceptual-with-tasks:before {\n/* background-color: rgba(128,128,128,1) */\n}\n#roadmap.jazz .nav-visited-chapter.tutorial:before {\n/* background-color: rgba(128,128,128,1) */\n}\n#roadmap.jazz .nav-current-chapter.conceptual-with-tasks:before {\n/* background-color: rgba(0,0,0,1); */\nborder-color: rgba(0,0,0,1)\n}\n#roadmap.jazz .nav-current-chapter.tutorial:before {\n/* background-color: rgba(0,0,0,1); */\nborder-color: rgba(0,0,0,1)\n}\n.jazz .book-parts a {\nmargin-left: 24px\n}\n#roadmap .nav-chapters li:first-child .pipe {\nheight: 9px;\ntop: auto\n}\n#roadmap .nav-chapters .pipe {\n/* background-color: gray; */\nheight: 9px;\npadding-top: 2px;\nposition: absolute;\nright: auto;\nbottom: auto;\nleft: 26px;\nwidth: 2px;\nmargin-top: -1px\n}\n#roadmap .nav-chapters li:last-child .pipe {\nheight: 0;\ndisplay: none\n}\n#roadmap.jazz .part-name {\ncursor: default\n}\n/*! Copyright © 2012 Apple Inc.  All rights reserved. */#release_notes .chapter-name {\nwidth: auto\n}\n#release_notes .nav-part-active {\n/* background-color: rgba(255,255,255,1); */\ncolor: rgba(0,0,0,1);\ncursor: default\n}\n#release_notes #contents {\nwidth: 980px;\nmargin-left: 0\n}\n#release_notes .section {\nwidth: 734px;\nmargin: 0 auto\n}\n#release_notes #mini_toc {\nleft: 434px\n}\n/*! Copyright © 2010 Apple Inc.  All rights reserved. */@media only print {.jazz #valence {\ndisplay: none\n}\n.jazz #ios_header {\ndisplay: none\n}\n.jazz #footer #leave_feedback {\ndisplay: none\n}\n.jazz #mini_toc {\ndisplay: none\n}\n.jazz .chapter {\nposition: relative;\nmargin: 0 auto;\ntop: 0;\nborder: 0;\nbox-shadow: none;\npadding-bottom: 0\n}\n.jazz .book-parts {\ndisplay: none\n}\nbody.jazz,.jazz .content-wrapper {\n/* background-color: rgba(255,255,255,1) */\n}\n.jazz a[name] {\nmargin: auto;\npadding-top: 0;\ndisplay: static\n}\n.jazz .next-link a {\ndisplay: none\n}\n.jazz .previous-link a {\ndisplay: none\n}\n.jazz .rec-container .left-container {\npadding-right: 0;\nfloat: left\n}\n.jazz .rec-container .right-container {\nfloat: right;\npadding-left: 0\n}\n.jazz .rec-container .left-container,.jazz .rec-container .right-container {\ndisplay: static;\nwidth: auto\n}\n.jazz .para {\nclear: both\n}\n.jazz .copyright {\nmargin: auto\n}\n\n}\n@media only screen and (min-device-width:768px) and (max-device-width:1024px) and (orientation:portrait) {body.jazz {\nfont-size: 75%\n}\n.jazz .content-wrapper {\nwidth: 100%\n}\n.jazz #ios_header .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz #valence .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz #ios_header {\nheight: 30px;\nletter-spacing: 0;\nmargin-bottom: 0;\nposition: fixed;\ntop: 0;\nwidth: 100%;\nz-index: 3\n}\n.jazz #valence {\nheight: 70px;\ntop: 30px;\nposition: fixed;\nwidth: 100%;\nz-index: 2\n}\n.jazz #hierarchial_navigation {\nmargin-top: 2px\n}\n.jazz .download-text {\nbackground-image: url(../Images/download_2x.png);\nbackground-size: 30px 30px;\nbackground-position: 0;\ncolor: transparent;\nheight: 30px;\nmargin: 0;\nwidth: 30px;\noverflow: hidden\n}\n.jazz #search {\nbackground-image: url(../Images/search_2x.png);\nbackground-size: 30px 30px;\nbackground-position: 0;\nfloat: right;\nheight: 30px;\nmargin: 0 0 0 10px;\npadding: 0;\nwidth: 30px\n}\n.jazz #search.enabled {\n}\n.jazz input[type=search] {\ndisplay: none\n}\n.jazz input[type=search].enabled {\nbackground-image: none;\ndisplay: block;\nheight: 30px;\nmargin-top: 34px;\npadding-left: 8px;\n-webkit-border-radius: 0;\nwidth: 248px\n}\n.jazz #shortstack {\ndisplay: block;\nfloat: none;\nheight: 30px;\nmargin-left: -12px;\nmargin-top: 18px;\npadding: 13px 10px;\nposition: absolute;\nwidth: 30px\n}\n.jazz .chapter {\nbottom: 0;\nleft: 0;\nmargin-left: 0;\npadding-bottom: 0;\nposition: relative;\nright: 0;\ntop: 110px;\nz-index: -2\n}\n.jazz .part-name {\npadding: 20px 20px 20px 25px\n}\n.jazz .book-parts {\nbox-shadow: 0 0 1px rgba(0,0,0,.07);\ndisplay: none;\ntop: 110px;\nposition: fixed;\nleft: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 295px;\nz-index: -1\n}\n.jazz .nav-parts {\noverflow: auto\n}\n.jazz .book-parts.open {\nbox-shadow: 7px 0 5px rgba(0,0,0,.05);\ndisplay: block;\nz-index: 5\n}\n.jazz #big_button {\n}\n.jazz #big_button.active {\nposition: fixed;\ntop: 0;\nbottom: 0;\nleft: 0;\nright: 0;\nz-index: 4;\n/* background-color: transparent */\n}\n.jazz .nav-chapter {\npadding: 0 0 16px\n}\n.jazz #mini_toc {\nbackground-position: 90% 14px;\nmargin-top: 2px;\npadding: 10px 10px 5px 15px;\nwidth: 220px;\ntop: 125px\n}\n.jazz #mini_toc ul.list-bullet {\nmargin-top: 15px;\npadding-bottom: 0;\nwidth: 200px\n}\n.jazz .section {\npadding: 20px 13px\n}\n.jazz .chapter {\nmargin: 0 auto;\nwidth: 100%;\nz-index: 0;\noverflow: visible\n}\n.jazz .chapter-name {\npadding: 15px 20px 15px 13px\n}\n.jazz .figure img {\nmax-width: 600px\n}\n.jazz .two-columns .inline-graphic {\nmax-width: 100%\n}\n.jazz .intro ul.list-bullet {\nwidth: 100%\n}\n.jazz .intro ul.list-bullet li.item {\nwidth: 40%;\npadding-right: 80px\n}\n.jazz #next_previous {\nmargin: 0 13px;\nposition: static;\nwidth: 95%\n}\n.jazz .copyright {\nmargin: 70px 13px 15px 0;\nposition: relative;\nbottom: 0\n}\n.jazz #footer {\nposition: relative\n}\n.jazz #footer #leave_feedback {\nheight: 17px;\nright: 0;\nposition: fixed\n}\n.jazz #modal #feedback #comment {\n-webkit-border-radius: 0;\nheight: 111px;\nmargin: 16px 0 12px\n}\n.jazz #feedback .asterisk#a1.ipad,.asterisk#modal_a1.ipad {\nleft: 257px\n}\n.jazz #feedback .asterisk#a2.ipad,.asterisk#modal_a2.ipad {\ntop: 178px\n}\n.jazz .fineprint.invalid,#modal_feedback .fineprint.invalid {\nbottom: 53px\n}\n.jazz #modal #feedback #email {\n-webkit-border-radius: 0\n}\n.jazz #modal #feedback input[type=button] {\n/* background-color: rgba(160,160,160,1); */\nbackground-image: none;\ncolor: rgba(255,255,255,1);\nfont-family: Helvetica,Arial,sans-serif;\nmargin: 10px 0 0;\n-webkit-border-radius: 0;\n-webkit-appearance: none;\n-moz-appearance: none;\nappearance: none\n}\n\n}\n@media only screen and (min-device-width:768px) and (max-device-width:1024px) and (orientation:landscape) {body.jazz {\n}\n.jazz .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz #ios_header {\nletter-spacing: 0\n}\n.jazz #valence {\ntop: 25px;\nheight: 35px\n}\n.jazz #hierarchial_navigation {\nmargin-top: 4px\n}\n.jazz .download-text {\nmargin-top: 6px\n}\n.jazz input[type=search] {\nmargin-right: 0;\nmargin-top: 0;\npadding-left: 25px;\n-webkit-border-radius: 0\n}\n.jazz .book-parts {\n-webkit-overflow-scrolling: touch\n}\n.jazz .part-name {\npadding: 15px 20px\n}\n.jazz .chapter {\nbottom: 0;\nleft: 246px;\nmargin-left: 20px;\npadding-bottom: 0;\noverflow: visible\n}\n.jazz .section {\nbackground: rgba(255,255,255,1)\n}\n.jazz #next_previous {\nposition: static;\nbackground: rgba(255,255,255,1);\nmargin: 0;\npadding: 0 25px\n}\n.jazz #dpf_leave_feedback {\nheight: 16px;\nmargin-left: 797px\n}\n.jazz .two-columns .inline-graphic {\nmax-width: 100%\n}\n.jazz #footer {\nposition: relative\n}\n.jazz .copyright {\nmargin: 0;\nposition: relative;\nbottom: 8px\n}\n.jazz #footer #leave_feedback {\nposition: fixed\n}\n.jazz #modal #feedback #comment {\n-webkit-border-radius: 0;\nheight: 106px\n}\n.jazz #feedback .asterisk#a1.ipad,.asterisk#modal_a1.ipad {\nleft: 257px\n}\n.jazz .fineprint.invalid,#modal_feedback .fineprint.invalid {\nbottom: 48px\n}\n.jazz #modal #feedback #email {\n-webkit-border-radius: 0\n}\n.jazz #modal #feedback input[type=button] {\n/* background-color: rgba(160,160,160,1); */\nbackground-image: none;\ncolor: rgba(255,255,255,1);\nfont-family: Helvetica,Arial,sans-serif;\nmargin: 10px 0 0;\n-webkit-border-radius: 0;\n-webkit-appearance: none;\n-moz-appearance: none;\nappearance: none\n}\n\n}\n@media only screen and (min-device-width:320px) and (max-device-width:480px) and (orientation:portrait) {html {\n-webkit-text-size-adjust: none\n}\nbody.jazz {\n/* background-color: rgba(255,255,255,1); */\nfont-size: 70%;\noverflow-x: hidden\n}\n.jazz #ios_header {\ndisplay: block;\nheight: 30px;\nposition: static;\ntop: 0;\nz-index: 3\n}\n.jazz #ios_header .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz .header-text {\nletter-spacing: 0;\npadding-top: 8px\n}\n.jazz #wwdr {\npadding-top: 8px\n}\n.jazz #valence {\ndisplay: block;\nheight: 91px;\nleft: 0;\nposition: relative;\ntop: 0;\nwidth: 100%;\nz-index: 2\n}\n.jazz #valence .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz #hierarchial_navigation {\nfont-size: 1.4em;\nmargin-bottom: 0;\nmargin-top: 0;\npadding-left: 10%;\npadding-right: 10%;\ntext-align: center\n}\n.jazz #search {\nbackground-image: url(../Images/search_2x.png);\nbackground-position: 50% 50%;\nbackground-repeat: no-repeat;\nbackground-size: 32px 32px;\nfloat: right;\nheight: 44px;\nmargin: 0 80px 0 0;\npadding: 0;\nwidth: 44px\n}\n.jazz input[type=search] {\ndisplay: none\n}\n.jazz input[type=search].enabled {\nbackground-image: none;\ndisplay: block;\nfont-size: 1.4em;\nheight: 40px;\nmargin-right: -75px;\nmargin-top: 64px;\noutline: 13px solid rgba(160,160,160,1);\npadding-left: 8px;\n-webkit-border-radius: 0;\nwidth: 297px\n}\n.jazz .download-text {\nbackground-image: url(../Images/download_2x.png);\nbackground-position: 50% 50%;\nbackground-repeat: no-repeat;\nbackground-size: 32px 32px;\ncolor: transparent;\nheight: 44px;\nmargin: 0 10px 0 0;\nwidth: 44px\n}\n.jazz #shortstack {\nfloat: none;\ndisplay: block;\nheight: 32px;\nmargin-left: 75px;\nmargin-top: 42px;\npadding: 6px;\nposition: absolute;\nwidth: 32px\n}\n.jazz .book-parts {\nborder: 0;\nbox-shadow: 0 0 0;\nclear: both;\nmargin: 61px 0 0 -20px;\n-webkit-overflow-scrolling: auto;\nz-index: -1\n}\n.jazz .book-parts.open {\ndisplay: block;\nmargin-left: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 100%;\nz-index: 2\n}\n.jazz .part-name {\npadding-left: 30px\n}\n.jazz .nav-part-active {\npadding-bottom: 0\n}\n.jazz .nav-chapters {\nline-height: 180%\n}\n.jazz .nav-chapter {\nline-height: 140%;\npadding-bottom: 22px;\npadding-left: 5px\n}\n.jazz .content-wrapper {\n/* background-color: rgba(255,255,255,1); */\nwidth: 100%\n}\n.jazz .chapter {\nborder: 0;\nbox-shadow: none;\nleft: 0;\nmargin: 0 auto;\npadding-bottom: 50px;\npadding-top: 6px;\nposition: relative;\nright: 0;\ntop: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 96%\n}\n.jazz .frozen {\nposition: fixed;\nz-index: -10\n}\n.jazz .chapter-name {\nmargin-top: 0;\npadding: 10px 15px 10px 5px;\nwidth: 100%\n}\n.jazz #mini_toc {\nbackground-position-y: 14px;\nmargin: 10px 0 10px 5px;\npadding: 10px 10px 5px;\nposition: static;\nwidth: 246px\n}\n.jazz #mini_toc #mini_toc_button {\nwidth: 246px\n}\n.jazz .section {\npadding: 10px 5px 20px\n}\n.jazz .section-name {\nmargin-top: 0\n}\n.jazz .figure img {\nmax-width: 275px\n}\n.jazz .list-bullet {\nmargin-left: 18px;\npadding-left: 15px\n}\n.jazz .intro ul.list-bullet {\nmargin-top: 10px\n}\n.jazz .intro ul.list-bullet li.item {\nfloat: none;\npadding: 5px 0;\nwidth: 100%\n}\n.jazz ul.list-bullet li.item:before {\npadding-top: 1px\n}\n.jazz .intro ul.list-bullet li.item .para {\nline-height: 200%\n}\n.jazz .two-columns {\ndisplay: block;\nmargin: 80px auto\n}\n.jazz .two-columns .inline-graphic {\nmax-width: 100%\n}\n.jazz .left-column {\ndisplay: block\n}\n.jazz .right-column {\ndisplay: block;\npadding-left: 0\n}\n.jazz .two-columns img {\npadding-bottom: 10px\n}\n.jazz .two-columns .para {\nfont-size: 1.2em\n}\n.jazz .rec-container .blurb .para:nth-child(1) {\nwidth: 95%\n}\n.jazz .rec-container .left-container {\ndisplay: block;\nwidth: 100%\n}\n.jazz .rec-container .right-container {\ndisplay: block;\nmargin-top: 10px;\nwidth: 100%\n}\n.jazz #next_previous {\nmargin: 0 10px;\nposition: static;\nwidth: 95%\n}\n.jazz .previous-link {\ndisplay: table-cell;\nheight: 60px;\nmargin-bottom: 30px;\nwidth: 40%\n}\n.jazz .next-link {\ndisplay: table-cell;\nheight: 60px;\nmargin-bottom: 30px;\nwidth: 40%\n}\n.jazz .next-link a,.jazz .previous-link a {\ndisplay: table-cell;\nvertical-align: middle;\nwidth: 90%\n}\n.jazz #next_previous .copyright a {\ndisplay: inline;\nvertical-align: baseline\n}\n.jazz .copyright {\nmargin: 0;\ntext-align: center\n}\n.jazz #footer {\n/* background-color: rgba(255,255,255,1); */\npadding-bottom: 20px;\nposition: relative\n}\n.jazz #footer #leave_feedback {\nmargin: 0 auto;\nheight: 15px;\nposition: static;\nwidth: 60px\n}\n.jazz #modal {\nmargin-bottom: 7px;\noverflow: scroll!important;\npadding: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 300px\n}\n.jazz #modal #closebox {\nleft: 266px;\ntop: 5px\n}\n.jazz .activated {\nheight: 700px;\nmargin-bottom: 0\n}\n.jazz #feedback {\npadding: 10px;\nwidth: 280px\n}\n.jazz #modal #sending {\nwidth: 300px\n}\n.jazz #modal #feedback h2 {\nfont-size: 1.1em;\nmargin-bottom: 5px;\nmargin-top: 0;\npadding-top: 0\n}\n.jazz #modal #feedback .left-leaf {\nfloat: none;\nmargin-bottom: 15px;\nwidth: 250px\n}\n.jazz #modal #feedback .right-leaf {\nfloat: none;\nwidth: 250px\n}\n.jazz #modal #feedback #comment {\n-webkit-border-radius: 0;\nheight: 90px;\nwidth: 266px\n}\n.jazz #feedback .asterisk#a1 {\nleft: 185px;\ntop: 5px\n}\n.jazz #feedback .asterisk#a2 {\ntop: 270px;\nleft: 279px\n}\n.jazz #modal #feedback #email {\n-webkit-border-radius: 0;\nwidth: 266px\n}\n.jazz #modal #feedback .fineprint {\nbottom: 0;\nposition: relative;\nwidth: 200px\n}\n.jazz #modal #feedback input[type=button] {\n/* background-color: rgba(160,160,160,1); */\nbackground-image: none;\ncolor: rgba(255,255,255,1);\nfont-family: Helvetica,Arial,sans-serif;\nleft: 0;\nmargin: 10px 0 0;\n-webkit-border-radius: 0;\n-webkit-appearance: none;\n-moz-appearance: none;\nappearance: none\n}\n.jazz #modal #feedback #submit {\nmargin: 10px 0 0\n}\n\n}\n@media only screen and (min-device-width:320px) and (max-device-width:568px) and (orientation:landscape) {html {\n-webkit-text-size-adjust: none\n}\nbody.jazz {\n/* background-color: rgba(255,255,255,1); */\nfont-size: 70%;\noverflow-x: hidden\n}\n.jazz #ios_header {\ndisplay: block;\nheight: 30px;\nposition: static;\ntop: 0;\nz-index: 3\n}\n.jazz #ios_header .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz .header-text {\nletter-spacing: 0;\npadding-top: 8px\n}\n.jazz #wwdr {\npadding-top: 8px\n}\n.jazz #valence {\ndisplay: block;\nheight: 82px;\nleft: 0;\nposition: relative;\ntop: 0;\nwidth: 100%;\nz-index: 2\n}\n.jazz #valence .content-wrapper {\n/* background-color: rgba(242,242,242,1); */\nmargin: 0 auto;\nwidth: 96%\n}\n.jazz #hierarchial_navigation {\nfloat: none;\nfont-size: 1.4em;\nmargin: 0 auto;\npadding-top: 0;\ntext-align: center;\nwidth: 90%\n}\n.jazz #search {\nbackground-image: url(../Images/search_2x.png);\nbackground-position: 50% 50%;\nbackground-repeat: no-repeat;\nbackground-size: 32px 32px;\nfloat: right;\nheight: 44px;\nmargin: 4px 199px 0 0;\npadding: 0;\nwidth: 44px\n}\n.jazz input[type=search] {\ndisplay: none\n}\n.jazz input[type=search].enabled {\nbackground-image: none;\ndisplay: block;\nfont-size: 1.4em;\nheight: 40px;\nmargin-right: -200px;\nmargin-top: 60px;\noutline: 13px solid rgba(128,128,128,1);\npadding-left: 8px;\n-webkit-border-radius: 0;\nwidth: 545px\n}\n.jazz .download-text {\nbackground-image: url(../Images/download_2x.png);\nbackground-position: 50% 50%;\nbackground-repeat: no-repeat;\nbackground-size: 32px 32px;\ncolor: transparent;\nheight: 44px;\nmargin: 4px 10px 0 0;\nwidth: 44px\n}\n.jazz #shortstack {\nfloat: none;\ndisplay: block;\nheight: 32px;\nmargin-left: 192px;\nmargin-top: 5px;\npadding: 6px;\nposition: absolute;\nwidth: 32px\n}\n.jazz .book-parts {\nclear: both;\ndisplay: none;\nmargin: 51px 0 0 -20px;\n-webkit-overflow-scrolling: touch;\nz-index: 1\n}\n.jazz .book-parts.open {\ndisplay: block;\nwidth: 60%;\nz-index: 2\n}\n.jazz .part-name {\npadding-left: 30px\n}\n.jazz .nav-part-active {\npadding-bottom: 0\n}\n.jazz .nav-chapters {\nline-height: 180%\n}\n.jazz .nav-chapter {\nline-height: 140%;\npadding-bottom: 22px;\npadding-left: 5px\n}\n.jazz .content-wrapper {\n/* background-color: rgba(255,255,255,1); */\nwidth: 100%\n}\n.jazz .chapter {\nborder: 0;\nbox-shadow: none;\nleft: 0;\nmargin: 0 auto;\npadding-bottom: 50px;\npadding-top: 6px;\nposition: relative;\nright: 0;\ntop: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 96%\n}\n.jazz .frozen {\npadding-top: 112px;\nposition: fixed;\nz-index: -10\n}\n.jazz .chapter-name {\npadding: 10px 15px 10px 5px;\nwidth: 100%\n}\n.jazz #mini_toc {\nbackground-position-y: 14px;\nmargin: 10px 0 10px 5px;\npadding: 10px 10px 5px;\nposition: static;\nwidth: 246px\n}\n.jazz #mini_toc #mini_toc_button {\nwidth: 246px\n}\n.jazz .section {\npadding: 10px 5px 20px\n}\n.jazz .figure img {\nmax-width: 275px\n}\n.jazz .list-bullet {\nmargin-left: 18px;\npadding-left: 15px\n}\n.jazz .intro ul.list-bullet {\nmargin-top: 10px\n}\n.jazz .intro ul.list-bullet li.item {\nfloat: none;\npadding: 5px 0;\nwidth: 100%\n}\n.jazz ul.list-bullet li.item:before {\npadding-top: 1px\n}\n.jazz .intro ul.list-bullet li.item .para {\nline-height: 200%\n}\n.jazz .two-columns {\ndisplay: block;\nmargin: 80px auto\n}\n.jazz .left-column {\ndisplay: block\n}\n.jazz .right-column {\ndisplay: block;\npadding-left: 0\n}\n.jazz .two-columns img {\npadding-bottom: 10px\n}\n.jazz .two-columns .inline-graphic {\nmax-width: 100%\n}\n.jazz .two-columns .para {\nfont-size: 1.2em\n}\n.jazz .rec-container .blurb .para:nth-child(1) {\nwidth: 95%\n}\n.jazz .rec-container .left-container {\ndisplay: block;\nwidth: 100%\n}\n.jazz .rec-container .right-container {\ndisplay: block;\nmargin-top: 10px;\nwidth: 100%\n}\n.jazz #next_previous {\nmargin: 0 10px;\nposition: static;\nwidth: 95%\n}\n.jazz .previous-link {\ndisplay: table-cell;\nheight: 60px;\nmargin-bottom: 30px;\nwidth: 40%\n}\n.jazz .next-link {\ndisplay: table-cell;\nheight: 60px;\nmargin-bottom: 30px;\nwidth: 40%\n}\n.jazz .next-link a,.jazz .previous-link a {\ndisplay: table-cell;\nvertical-align: middle;\nwidth: 90%\n}\n.jazz #next_previous .copyright a {\ndisplay: inline;\nvertical-align: baseline\n}\n.jazz .copyright {\nmargin: 0;\ntext-align: center\n}\n.jazz #footer {\n/* background-color: rgba(255,255,255,1); */\npadding-bottom: 20px;\nposition: relative\n}\n.jazz #footer #leave_feedback {\nmargin: 0 auto;\nheight: 15px;\nposition: static;\nwidth: 100px\n}\n.jazz #modal {\nmargin-bottom: 7px;\noverflow: scroll!important;\npadding: 0;\n-webkit-overflow-scrolling: touch;\nwidth: 300px\n}\n.jazz #modal #closebox {\nleft: 266px;\ntop: 5px\n}\n.jazz .activated {\nheight: 700px;\nmargin-bottom: 0\n}\n.jazz #feedback {\npadding: 10px;\nwidth: 280px\n}\n.jazz #modal #sending {\nwidth: 300px\n}\n.jazz #modal #feedback h2 {\nfont-size: 1.1em;\nmargin-bottom: 5px;\nmargin-top: 0;\npadding-top: 0\n}\n.jazz #modal #feedback .left-leaf {\nfloat: none;\nmargin-bottom: 15px;\nwidth: 250px\n}\n.jazz #modal #feedback .right-leaf {\nfloat: none;\nwidth: 250px\n}\n.jazz #modal #feedback #comment {\n-webkit-border-radius: 0;\nheight: 90px;\nwidth: 266px\n}\n.jazz #feedback .asterisk#a1 {\nleft: 185px;\ntop: 5px\n}\n.jazz #feedback .asterisk#a2 {\ntop: 270px;\nleft: 279px\n}\n.jazz #modal #feedback #email {\n-webkit-border-radius: 0;\nwidth: 266px\n}\n.jazz #modal #feedback .fineprint {\nbottom: 0;\nposition: relative;\nwidth: 200px\n}\n.jazz #modal #feedback input[type=button] {\n/* background-color: rgba(160,160,160,1); */\nbackground-image: none;\ncolor: rgba(255,255,255,1);\nfont-family: Helvetica,Arial,sans-serif;\nleft: 0;\nmargin: 10px 0 0;\n-webkit-border-radius: 0;\n-webkit-appearance: none;\n-moz-appearance: none;\nappearance: none\n}\n.jazz #modal #feedback #submit {\nmargin: 10px 0 0\n}\n\n}\n.svg-container {\nposition: relative\n}\n.svg-play-button {\nbackground: url(../Images/playbutton.svg) no-repeat;\nbackground-position: 0 0;\nbackground-size: cover;\nwidth: 32px;\nheight: 32px;\nposition: absolute;\ntop: 90px;\nleft: 90px;\npointer-events: none;\nopacity: 1;\n-webkit-transition: opacity .3s ease\n}\n.svg-play-button.faded {\nopacity: 0\n}\n.p {\ncolor: rgba(0,0,0,1)\n}\n.c {\ncolor: rgba(0,116,0,1);\nfont-style: italic\n}\n.err {\n}\n.k {\ncolor: rgba(170,13,145,1)\n}\n.o {\ncolor: #666\n}\n.cm {\ncolor: rgba(0,116,0,1);\nfont-style: italic\n}\n.cp {\ncolor: rgba(100,56,32,1)\n}\n.c1 {\ncolor: rgba(0,116,0,1);\nfont-style: italic\n}\n.cs {\ncolor: rgba(0,116,0,1);\nfont-style: italic\n}\n.gd {\ncolor: #A00000\n}\n.ge {\nfont-style: italic\n}\n.gr {\ncolor: #F00\n}\n.gh {\ncolor: navy;\nfont-weight: 700\n}\n.gi {\ncolor: #00A000\n}\n.go {\ncolor: gray\n}\n.gp {\ncolor: navy;\nfont-weight: 700\n}\n.gs {\nfont-weight: 700\n}\n.gu {\ncolor: purple;\nfont-weight: 700\n}\n.gt {\ncolor: #0040D0\n}\n.kc {\ncolor: rgba(170,13,145,1)\n}\n.kd {\ncolor: rgba(170,13,145,1)\n}\n.kp {\ncolor: rgba(170,13,145,1)\n}\n.kr {\ncolor: rgba(170,13,145,1)\n}\n.kt {\ncolor: rgba(170,13,145,1)\n}\n.m {\ncolor: rgba(28,0,207,1)\n}\n.s {\ncolor: rgba(196,26,22,1)\n}\n.n {\ncolor: rgba(46,13,110,1)\n}\n.na {\ncolor: rgba(131,48,30,1)\n}\n.nb {\ncolor: rgba(170,13,145,1)\n}\n.nc {\ncolor: rgba(63,110,116,1)\n}\n.no {\ncolor: rgba(38,71,75,1)\n}\n.nd {\ncolor: #A2F\n}\n.ni {\ncolor: #999;\nfont-weight: 700\n}\n.ne {\ncolor: #D2413A;\nfont-weight: 700\n}\n.nf {\ncolor: rgba(0,0,0,1)\n}\n.nl {\ncolor: rgba(46,13,110,1)\n}\n.nn {\ncolor: #00F;\nfont-weight: 700\n}\n.nt {\ncolor: green;\nfont-weight: 700\n}\n.nv {\ncolor: #19177C\n}\n.ow {\ncolor: #A2F;\nfont-weight: 700\n}\n.w {\ncolor: #bbb\n}\n.mf {\ncolor: rgba(28,0,207,1)\n}\n.mh {\ncolor: rgba(28,0,207,1)\n}\n.mi {\ncolor: rgba(28,0,207,1)\n}\n.mo {\ncolor: rgba(28,0,207,1)\n}\n.sb {\ncolor: rgba(196,26,22,1)\n}\n.sc {\ncolor: rgba(196,26,22,1)\n}\n.sd {\ncolor: rgba(196,26,22,1)\n}\n.s2 {\ncolor: rgba(196,26,22,1)\n}\n.se {\ncolor: rgba(196,26,22,1)\n}\n.sh {\ncolor: rgba(196,26,22,1)\n}\n.si {\ncolor: rgba(196,26,22,1)\n}\n.sx {\ncolor: rgba(196,26,22,1)\n}\n.sr {\ncolor: rgba(196,26,22,1)\n}\n.s1 {\ncolor: rgba(196,26,22,1)\n}\n.ss {\ncolor: rgba(196,26,22,1)\n}\n.bp {\ncolor: green\n}\n.vc {\ncolor: rgba(63,110,116,1)\n}\n.vg {\ncolor: #19177C\n}\n.vi {\ncolor: #19177C\n}\n.il {\ncolor: rgba(28,0,207,1)\n}\n"
//}
//#endif
