<img src="http://glimpseio.github.io/ChannelZ/images/ChannelZ.svg" width="100%" />

[![Build Status](https://travis-ci.org/glimpseio/ChannelZ.svg?branch=master)](https://travis-ci.org/glimpseio/ChannelZ)

*ChannelZ: Lightweight Reactive Swift*

### Introduction

ChannelZ is a pure Swift framework for simplifying state and event management in iOS and Mac apps. You can create `Channels` to both native Swift properties and Objective-C properties, and connect those `Channels` using `Conduits`, enabling the underlying values of the properties to be automatically synchronized.

Following is an overview of the API. To get started using ChannelZ in your own project, jump straight to [Setting up ChannelZ](#setting-up-channelz).

#### Example: Basic Usage

```swift
import ChannelZ

let a1 = ∞(Int(0))∞ // create a field channel
let a2 = ∞(Int(0))∞ // create another field channel

a1 <=∞=> a2 // create a two-way conduit between the properties

println(a1.source.value) // the underlying value of the field channel is accessed with the `value` property
a2.source.value = 42 // then changing a2's value…
println(a1.source.value) // …will automatically set a1 to that same value!

assert(a1.source.value == 42)
assert(a2.source.value == 42)
```
<!-- extra backtick to fix Xcode's faulty syntax highlighting `  -->

> **Note**: this documentation is also available as an executable Playground within the ChannelZ framework.

### Operators & Functions

ChannelZ's central operator is **∞**, which can be entered with `Option-5` on the Mac keyboard. Variants of this operator are used throughout the framework, but you can alternatively use functions for all of ChannelZ's operations. The major operators are listed in section [Operator Glossary](#operator-glossary).

#### Example: Usings Functions Instead of ∞

```swift
let b1: ChannelZ<Int> = channelField(Int(0))
let b2: ChannelZ<Int> = channelField(Int(0))

let b1b2: Receptor = conduit(b1, b2)

b1.source.value
b2.source.value = 99
b1.source.value

assert(b1.source.value == 99)
assert(b2.source.value == 99)

b1b2.unsubscribe() // you can manually disconnect the conduit if you like
```
<!--`-->

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
<!--`-->

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
<!--`-->

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


sst1.stringChannel.source.value
scl1.stringField += "ABC"
sst1.stringChannel.source.value

assert(sst1.stringChannel.source.value == scl1.stringField)
```
<!--`-->

The above is an example if a bi-directional conduit using the `<=∞=>` operator. You can also create a uni-directional conduit that only synchronizes state changes in one direction using the `∞=>` and `<=∞` operators.

#### Example: A Unidirectional Condit

```swift
let scl2 = StringClass()
let sst2 = StringStruct()

scl2∞scl2.stringField ∞=> sst2.stringChannel

scl2.stringField += "XYZ"
assert(sst2.stringChannel.source.value == scl2.stringField, "stringField conduit to stringChannel")

sst2.stringChannel.source.value = "QRS"
assert(sst2.stringChannel.source.value != scl2.stringField, "conduit is unidirectional")
```
<!--`-->

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
swsc.stringChannel.source.value // will be "55"

swsc.stringChannel.source.value = "89"
ojic.intField // will be 89

```
<!--`-->

#### Example: Observing Button Taps

```swift
import UIKit

let button = UIButton()
button.controlz() ∞> { (event: UIEvent) in println("Tapped Button!") }
```
<!--`-->

Note that `controlz()` method on `UIButton`. This is a category method added by `ChannelZ` to all `UIControl` instances on iOS' `UIKit` and `NSControl` instances on Mac's `AppKit`. The extensions of UIKit and AppKit also permit channeling other control events, which are not normally observable through KVO.

#### Example: Sychronizing a Slider and a Stepper through a Model

```swift
struct ViewModel {
    let amount = ∞(Double(0))∞
    let amountMax = Double(100.0)
}

let vm = ViewModel()

let stepper = UIStepper()
stepper.maximumValue = vm.amountMax
stepper∞stepper.value <=∞=> vm.amount

let slider = UISlider()
slider.maximumValue = Float(vm.amountMax)
slider∞slider.value <~∞~> vm.amount

stepper.value += 25.0
assert(slider.value == 25.0)
assert(vm.amount.source.value == 25.0)

slider.value += 30.0
assert(stepper.value == 55.0)
assert(vm.amount.source.value == 55.0)

println("slider: \(slider.value) stepper: \(stepper.value)")
```
<!--`-->

> The `<~∞~>` operator a variant of the `<=∞=>` operator that coerces between different numeric types. It is used above because `UIStepper.value` is a `Double` and `UISlider.value` is a `Float`. The `<=∞=>` operator respects Swift's design decision to prohibit automatic numeric type coersion and is generally recommended.

Note that channels and Observables are not restricted to a single conduit or subscription. We can supplement the above example with a progress indicator.

#### Example: Adding a UIProgressView channel

```swift
let progbar = UIProgressView()

// UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value 
vm.amount.map({ Float($0 / vm.amountMax) }) ∞=> progbar∞progbar.progress

vm.amount.source.value += 20

assert(slider.value == 75.0)
assert(stepper.value == 75.0)
assert(progbar.progress == 0.75)

println("slider: \(slider.value) stepper: \(stepper.value) progress: \(progbar.progress)")
```
<!--`-->


> The `ViewModel` struct above demonstrates using the [Model View ViewModel(MVVM)](https://en.wikipedia.org/wiki/Model_View_ViewModel) variant of the traditional *Model View Control* design pattern for user interfaces. ChannelZ can be used as the data binding layer for implementing MVVM, which has the benefit of being more easily testable and better facilitating the creation of re-usable UI code for cross-platform iOS & Mac apps.

### Memory Management

Receptors are weakly associated with their target objects, so when the objects are released, their subscriptions are also released. Note that when using closures, the standard practice of declaring `[unowned self]` is recommended in order to avert retain cycles in your own code.


### Operator Glossary

Following is a list of the variants of the ∞ operator that is used throughout the ChannelZ framework:

* `∞(SWTYPE)∞`: Wraps the given Swift reference type in a field channel
* `ObjC ∞ ObjC.key`: Creates a channel to the given Objective-C object's auto-detected KVO-compliant key.
* `ObjC ∞ (ObjC.key, "keyPath")`: Creates a channel to the given Objective-C's property with a manually specified keypath.
* `Fz ∞> { (arg: Type) -> Void }`: subscribes a subscription to the given Observable or channel.
* `Fz ∞-> { (arg: Type) -> Void }`: subscribes a subscription to the given Observable or channel and primes it with the current value.
* `Cz1 ∞=> Cz2`: Unidirectionally conduits state from channel `Cz1` to channel `Cz2`.
* `Cz1 ∞=-> Cz2`: Unidirectionally conduits state from channel `Cz1` to channel `Cz2` and primes the subscription.
* `Cz1 <-=∞ Cz2`: Unidirectionally conduits state from channel `Cz2` to channel `Cz1` and primes the subscription.
* `Cz1 <=∞=> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2`.
* `Cz1 <=∞=-> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` and primes the right side subscription.
* `Cz1 <~∞~> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` by coercing numeric types.
* `Cz1 <?∞?> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` by attempting an optional cast.
* `(Cz1 | Cz2) ∞> { (cz1Type?, cz2Type?) -> Void }`: subscribe a subscription to the combination of `Cz1` and `Cz2` such that when either changes, the subscription will be fired.
* `(Cz1 & Cz2) ∞> { (cz1Type, cz2Type) -> Void }`: subscribe a subscription to the combination of `Cz1` and `Cz2` such that when both change, the subscription will be fired.

### Setting up ChannelZ

`ChannelZ` is a single cross-platform iOS & Mac Framework. To set it up in your project, simply add it as a github submodule, drag the `ChannelZ.xcodeproj` into your own project file, add `ChannelZ.framework` to your target's dependencies, and `import ChannelZ` from any Swift file that should use it.

**Set up Git submodule**

1. Open a Terminal window
1. Change to your projects directory `cd /path/to/MyProject`
1. If this is a new project, initialize Git: `git init`
1. Add the submodule: `git submodule add https://github.com/glimpseio/ChannelZ.git ChannelZ`.

**Set up Xcode**

1. Find the `ChannelZ.xcodeproj` file inside of the cloned ChannelZ project directory.
1. Drag & Drop it into the `Project Navigator` (⌘+1).
1. Select your project in the `Project Navigator` (⌘+1).
1. Select your target.
1. Select the tab `Build Phases`.
1. Expand `Link Binary With Libraries`.
1. Add `ChannelZ.framework`
1. Add `import ChannelZ` to the top of your Swift source files.


### FAQ:

1. **Why the Operator ∞?** A common complaint about overloading existing operators (such as +) is that they can defy intuition. ∞ was chosen because it is not used by any other known Swift framework, and so developers are unlikely to have preconceived notions about what it should mean. Also, the infinity symbol is a good metaphor for the infinite nature of modeling state changes over time.
1. **Can I use ChannelZ from Objective-C?** No. ChannelZ uses generic, structs, and enums, none of which can be used from Objective-C code. The framework will interact gracefully with any Objective-C code you have, but you cannot access channels from Objective-C, only from Swift.
1. **Optionals?**
1. **NSMutableDictionary keys?**
1. **System requirements?** ChannelZ requires Xcode 6.1+ with iOS 8.1+ or Mac OS 10.10+.
1. **How is automatic keypath identification done?** In order to turn the code `ob∞ob.someField` into a KVO subscription, we need to figure out that `someField` is equivalent to the `"someField"` key path. This is accomplished by temporarily swizzling the class at the time of channel creation in order to instrument the properties and track which property is accessed by the autoclosure, and then immediately swizzling it back to the original class. This is usually transparent, but may fail on classes that dynamically implement their properties, such as Core Data's '`NSManagedObject`. In those cases, you can always manually specify the key path of a field with the operator variant that takes a tuple with the original value and the name of the property: `ob∞(ob.someField, "someField")`
1. **Automatic Keypath Identification Performance?** `ob∞ob.someField` is about 12x slower than `ob∞(ob.someField, "someField")`
1. **Memory management?** All channels are rooted in a reference type: either a reference wrapper around a Swift value, or by the owning class instance itself for KVO. The reference type owns all the subscribed subscriptions, and they are deallocated whenever the reference is released. You shouldn't need to manually track subscriptions and unsubscribe them, although there is nothing preventing you from doing so if you wish.
1. **Unstable conduit & reentrancy?** A state channel conduit is considered *unstable* when it cannot reach equilibrium. For example, `ob1∞ob1.intField <=∞=> (ob2∞ob2.intField).map({ $0 + 1 })` would mean that setting `ob1.intField` to 1 would set `ob2.intField` to 1, and then the map on the channel would cause `ob1.intField` to be set to 2. This cycle is prevented by limited the levels of re-entrancy that a subscription will allow, and is controlled by the global `ChannelZReentrancyLimit` field, which default to 1. You can change this value globally if you have channel cycles that may take a few passes to settle into equilibrium.
1. **Threading & Queuing?** ChannelZ doesn't touch threads or queues. You can always perform queue jumping yourself in a subscription.
1. **UIKit/AppKit and KVO?** `UIKit`'s `UIControl` and `AppKit`'s `NSControl` are not KVO-compliant for user interaction. For example, the `value` field of a `UISlider` does not receive KVO messages when the user drags the slider. We work around this by supplementing channel subscriptions with an additional Observable for the control events. See the `KeyValueChannelSupplementing` implementation in the `UIControl` extension for an example of how you can supplement your own control events.
1. **Problems?** Please file a Github [ChannelZ issue](https://github.com/mprudhom/ChannelZ/issues/new).
1. **Questions** Please use StackOverflow's [#channelz tag](http://stackoverflow.com/questions/tagged/channelz).

## References

* [Deprecating the Observer Pattern with Scala.React](http://infoscience.epfl.ch/record/176887)
* [Groovy Parallel Systems](http://gpars.codehaus.org/Dataflow)


