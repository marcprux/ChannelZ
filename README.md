# ∞ChannelZ∞

*Declarative & Typesafe Dataflow Programming in Swift*

### Introduction

ChannelZ is a pure Swift framework for simplifying state and event management in iOS and Mac apps. You can create `Channels` to both native Swift properties and Objective-C properties, and connect those `Channels` using `Conduits`, enabling the underlying values of the properties to be automatically synchronized.

Following is an overview of the API. To get started using ChannelZ in your own project, jump straight to [Setting up ChannelZ](#settingup).

#### Example: Basic Usage

```swift
import ChannelZ

let a1 = ∞(Int(0))∞ // create a field channel
let a2 = ∞(Int(0))∞ // create another field channel

a1 <=∞=> a2 // create a two-way conduit between the properties

a1.value // the underlying value of the field channel is accessed with the `value` property
a2.value = 42 // changing a2's value…
a1.value // …will automatically set a1 to that same value!

assert(a1.value == 42)
assert(a2.value == 42)
```

### Operators & Fuctions

ChannelZ defines the operator **∞**, which can be entered with `Option-5` on the Mac keyboard. You can alternatively use functions for all of ChannelZ's operations.

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
```


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
```

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
```

### Mixing Swift & Objective-C

ChannelZ allows synchronization between properties in Swift and Objective-C instances.

#### Example: Creating a Conduit between a Swift property and Objective-C property

```swift
class ObjcStringClass : NSObject {
    dynamic var stringField = ""
}

struct SwiftStringStruct {
    let stringChannel = ∞("")∞
}

let ojc = ObjcStringClass()
let swc = SwiftStringStruct()

ojc∞ojc.stringField <=∞=> swc.stringChannel


swc.stringChannel.value
ojc.stringField += "ABC"
swc.stringChannel.value

assert(swc.stringChannel.value == ojc.stringField)
```

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

```

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


