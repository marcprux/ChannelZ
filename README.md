# ∞ChannelZ∞

*Declarative & Typesafe Dataflow Programming in Swift*

### Introduction

ChannelZ is a pure Swift framework for simplifying state and event management in iOS and Mac apps. You can create `Channels` to both native Swift properties and Objective-C properties, and connect those `Channels` using `Conduits`, enabling the underlying values of the properties to be automatically synchronized.

Following is an overview of the API. To get started using ChannelZ in your own project, jump straight to [Setting up ChannelZ](#setting-up-channelz).

#### Example: Basic Usage

```swift
import ChannelZ

let a1 = ∞(Int(0))∞ // create a field channel
let a2 = ∞(Int(0))∞ // create another field channel

a1 <=∞=> a2 // create a two-way conduit between the properties

println(a1.value) // the underlying value of the field channel is accessed with the `value` property
a2.value = 42 // then changing a2's value…
println(a1.value) // …will automatically set a1 to that same value!

assert(a1.value == 42)
assert(a2.value == 42)
``` `````````

> **Note**: this documentation is also available as an executable Playground within the ChannelZ framework.

### Operators & Fuctions

ChannelZ's central operator is **∞**, which can be entered with `Option-5` on the Mac keyboard. Variants of this operator are used throughout the framework, but you can alternatively use functions for all of ChannelZ's operations. The major operators are listed in section [Operator Glossary](#operator-glossary).

#### Example: Usings Functions Instead of ∞

```swift
let b1: ChannelZ<Int> = channelField(Int(0))
let b2: ChannelZ<Int> = channelField(Int(0))

let b1b2: Outlet = conduit(b1, b2)

b1.value
b2.value = 99
b1.value

assert(b1.value == 99)
assert(b2.value == 99)

b1b2.detach() // you can manually disconnect the conduit if you like
``` `````````


### Objective-C, KVO, and ChannelZ

The above examples demonstrate creating channels from two separate Swift properties and keeping them in sync by creaing a conduit. In addition to Swift properties, you can also create channels to Objective-C properties that support Cocoa's [Key-Value Observing](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) protocol.


#### Example: Objective-C KVO

```swift
import Foundation

class SomeClass : NSObject {
    dynamic var intField: Int = 0
}

// create two separate instances of our ObjC class
let sc1 = SomeClass()
let sc2 = SomeClass()

sc1∞sc1.intField <=∞=> sc2∞sc2.intField

sc2.intField
sc1.intField += 123
sc2.intField

assert(sc1.intField == sc2.intField)
``` `````````

### KVO Details

KVO is handled somewhat differently from Swift property channeling. Since there is no equivalent of KVO in Swift, channeling requires that the underlying Swift value be wrapped in a ChannelZ reference so that the property can be tracked. In Objective-C's KVO system, the owning class itself is the reference that holds the properties.

ChannelZ makes an effort to automatically discover the name of the property on the right side of the `∞` channel operator. This only works for top-level keys, and not for keyPaths that span multiple levels. Similiarly to using the Swift functions in lieu of operators, you can also use the `channelz` method declared in an extension on `NSObject` for KVO property channeling.

#### Example: Objective-C KVO with Functions

```swift
let sc3 = SomeClass()
let sc4 = SomeClass()

let sc3z = sc3.channelz(sc3.intField, keyPath: "intField")
let sc4z = sc4.channelz(sc4.intField, keyPath: "intField")

conduit(sc3z, sc4z)

sc3.intField
sc4.intField += 789
sc3.intField

assert(sc3.intField == sc4.intField)
``` `````````

### Mixing Swift & Objective-C

ChannelZ allows synchronization between properties in Swift and Objective-C instances.

#### Example: Creating a Conduit between a Swift property and Objective-C property

```swift
class StringClass : NSObject {
    dynamic var stringField = ""
}

struct StringStruct {
    let stringChannel = ∞("")∞
}

let scl1 = StringClass()
let sst1 = StringStruct()

scl1∞scl1.stringField <=∞=> sst1.stringChannel


sst1.stringChannel.value
scl1.stringField += "ABC"
sst1.stringChannel.value

assert(sst1.stringChannel.value == scl1.stringField)
``` `````````

The above is an example if a bi-directional conduit using the `<=∞=>` operator. You can also create a uni-directional conduit that only synchronizes state changes in one direction using the `∞=>` and `<=∞` operators.

#### Example: A Unidirectional Condit

```swift
let scl2 = StringClass()
let sst2 = StringStruct()

scl2∞scl2.stringField ∞=> sst2.stringChannel

scl2.stringField += "XYZ"
assert(sst2.stringChannel.value == scl2.stringField, "stringField conduit to stringChannel")

sst2.stringChannel.value = "QRS"
assert(sst2.stringChannel.value != scl2.stringField, "conduit is unidirectional")
``` `````````


### Channeling between Different Types

Thus far, we have only seen channel conduits between identical types. You can also create mappings on channels that permit creating conduits between the types. Channels define `map`, `filter`, and `combine` functions.

#### Example: Mapping between Different Types

```swift
class ObjcIntClass : NSObject {
    dynamic var intField: Int = 0
}

struct SwiftStringClass {
    let stringChannel = ∞("")∞
}

let ojic = ObjcIntClass()
let swsc = SwiftStringClass()

(ojic∞ojic.intField).map({ "\($0)" }) <=∞=> (swsc.stringChannel).map({ $0.toInt() ?? 0 })

ojic.intField += 55
swsc.stringChannel.value // will be "55"

swsc.stringChannel.value = "89"
ojic.intField // will be 89

``` `````````

### Channels and Funnels

A `Channel` is bi-directional access to some underlying state. It is always backed by a reference type, either a class in Objective-C or a reference wrapper around a Swift value type. A `Channel` is a specialization of a `Funnel`, which provides uni-directional flow of events. Events are not limited to state changes. For example, you funnel button tap events to a custom attached outlet using the `-∞>` operator.

#### Example: Funneling Button Taps

```swift
import UIKit

let button = UIButton()
button.controlz() -∞> { (event: UIEvent) in println("Tapped Button!") }
``` `````````

Note that `controlz()` method on `UIButton`. This is a category method added by `ChannelZ` to all `UIControl` instances on iOS' `UIKit` and `NSControl` instances on Mac's `AppKit`. The extensions of UIKit and AppKit also permit channeling other control events, which are not normally observable through KVO.

#### Example: Sychronizing a Slider and a Stepper

```swift
let stepper = UIStepper()
stepper.maximumValue = 100.0

let slider = UISlider()
slider.maximumValue = 100.0

stepper∞stepper.value <~∞~> slider∞slider.value

stepper.value += 25.0
assert(slider.value == 25.0)

slider.value += 30.0
assert(stepper.value == 55.0)

println("slider: \(slider.value) stepper: \(stepper.value)")
``` `````````

> The `<~∞~>` operator a variant of the `<=∞=>` operator that coerces between different numeric types. It is used above because `UIStepper.value` is a `Double` and `UISlider.value` is a `Float`. The `<=∞=>` operator respects Swift's design decision to prohibit automatic numeric type coersion and is generally recommended.

Note that channels and funnels are not restricted to a single conduit or outlet. We can supplement the above example with a progress indicator.

#### Example: Adding a UIProgressView channel

```swift
let progbar = UIProgressView()
// UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value 
(slider∞slider.value).map({ $0 / slider.maximumValue }) ∞=> progbar∞progbar.progress

slider.value += 20

assert(slider.value == 75.0)
assert(stepper.value == 75.0)
assert(progbar.progress == 0.75)

println("slider: \(slider.value) stepper: \(stepper.value) progress: \(progbar.progress)")
``` `````````

There is no limit to the number of outlets that can be attached to channels and funnels. 

#### Example: Adding an NSProgress and NSTextField

```swift
let progress = NSProgress(totalUnitCount: 100)
let textField = UITextField()

// whenever the progress updates its description, set it in the text field
progress∞progress.localizedDescription ∞=> textField∞textField.text

progress.completedUnitCount += 12

println("progress: \(textField.text)")
``` `````````


### Memory Management

Outlets are weakly associated with their target objects, so when the objects are released, their outlets are also released. Note that when using closures, the standard practice of declaring `[unowned self]` is recommended in order to avert retain cycles in your own code.


### Operator Glossary

Following is a list of the variants of the ∞ operator that is used throughout the ChannelZ framework:

* `∞(SWTYPE)∞`: Wraps the given Swift reference type in a field channel
* `OBJC ∞ OBJC.PROPERTY`: Creates a channel to the given Objective-C object's auto-detected KVO-compliant key.
* `OBJC ∞ (OBJC.PROPERTY, "PROPNAME")`: Creates a channel to the given Objective-C's property with a manually specified keypath.
* `FUNL -∞> { (ARG: TYPE) in VOID }`: Attaches an outlet to the given funnel or channel.
* `C1 ∞=> C2`: Unidirectionally synchronizes state from channel C1 to channel C2
* `C1 <=∞ C2`: Unidirectionally synchronizes state from channel C2 to channel C1
* `C1 <=∞=> C2`: Bidirectionally synchronizes state between channels C1 and C2
* `C1 <~∞~> C2`: Bidirectionally synchronizes state between channels C1 and C2 by coercing numeric types

### Setting up ChannelZ

`ChannelZ` is a single cross-platform iOS & Mac Framework. To set it up in your project, simply add it as a github submodule, drag the `ChannelZ.xcodeproj` into your own project file, add `ChannelZ.framework` to your target's dependencies, and `import ChannelZ` from any Swift file that should use it.

**Set up Git submodule**

1. Open a Terminal window
1. Change to your projects directory `cd /path/to/MyProject`
1. If this is a new project, initialize Git: `git init`
1. Add the submodule: `git submodule add https://github.com/mprudhom/ChannelZ.git ChannelZ`.

**Set up Xcode**

1. Find the `ChannelZ.xcodeproj` file inside of the cloned ChannelZ project directory.
1. Drag & Drop it into the `Project Navigator` (⌘+1).
1. Select your project in the `Project Navigator` (⌘+1).
1. Select your target.
1. Select the tab `Build Phases`.
1. Expand `Link Binary With Libraries`.
1. Add `ChannelZ.framework`
1. Add `import ChannelZ` to the top of your Swift source files.


### Concepts

ChannelZ has four major components:

* **Funnel**: a unidirectional dataflow, such as the tap of a UI button or the receiving of some network data
* **Channel**: a bidirectional dataflow, such as the value of a model property; a Channel is a subtype of a Funnel
* **Outlet**: the recipient of dataflow events
* **Conduit**: a connection between two channels in order to keep their data in sync




### FAQ:

1. Why ∞?
1. UIKit and KVO?
1. Can I use ChannelZ from Objective-C? No.
1. Optionals?
1. NSMutableDictionary keys?
1. System requirements?
1. Automatic keypath identification?
1. Performance? 12x slower to do keypath auto-identification
1. Memory management?
1. Unstable bindings & reentrancy?
1. Threading?
1. What classes support KVO?
1. Core Data?
1. Problems? Please [file an issue](https://github.com/mprudhom/ChannelZ/issues/new).

## References

* [Deprecating the Observer Pattern with Scala.React](http://infoscience.epfl.ch/record/176887)
* [Groovy Parallel Systems](http://gpars.codehaus.org/Dataflow)


