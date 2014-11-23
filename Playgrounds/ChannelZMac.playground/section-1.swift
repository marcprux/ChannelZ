// Playground - noun: a place where people can play

import Cocoa
import ChannelZ
import XCPlayground

let progress = NSProgress(totalUnitCount: 100)

let indicator = NSProgressIndicator()
indicator.minValue = 0
indicator.maxValue = 100

progress∞progress.fractionCompleted ∞=> indicator∞indicator.doubleValue

//progress.completedUnitCount++

indicator.doubleValue = 50
indicator.usesThreadedAnimation = false
indicator.displayedWhenStopped = true

indicator.translatesAutoresizingMaskIntoConstraints = false
indicator.frame.size = NSSize(width: 300, height: 20)
XCPShowView("indicator", indicator)

let label = NSTextField()
label.frame.size = NSSize(width: 300, height: 20)
label.stringValue = "Progress..."
XCPShowView("label", label)

progress∞progress.localizedDescription ∞=> label∞label.stringValue

XCPSetExecutionShouldContinueIndefinitely(continueIndefinitely: true)

var block: ()->()

let inasec = { dispatch_time(0, 1_000_000_000) }

block = {
    progress.completedUnitCount = Int64(drand48() * Double(progress.totalUnitCount))
    dispatch_after(inasec(), dispatch_get_main_queue(), block)
}

dispatch_after(inasec(), dispatch_get_main_queue(), block)

