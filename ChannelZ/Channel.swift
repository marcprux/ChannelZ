////
////  Channels.swift
////  ChannelZ
////
////  Created by Marc Prud'hommeaux <marc@glimpse.io>
////  License: MIT (or whatever)
////
//
///// A Channel is a observable that has direct access to the underlying source value
//public protocol BaseChannelType : ChannelType {
//    /// The type of element produced by the source of the Channel
//    typealias SourceType
//
//    /// The underlying value of the channel's source
//    var value: Self.SourceType { get nonmutating set } // nonmutating because we are always rooted in a reference type
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    func channel() -> ChannelOf<SourceType, Element>
//}
//
///// A channel with support for filtering, mapping, etc.
//public protocol ExtendedChannelType : BaseChannelType {
//
//    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredChannel itself implements ChannelType, and so is regarded as a circular protocol declaration)
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    func filter(predicate: (Self.Element)->Bool)->FilteredChannel<Self>
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<Self, TransformedType>
//}
//
///// A channel combines basic channel functionality (subscribe/push/pull) with extended functionality
//public protocol ChannelType : BaseChannelType, ExtendedChannelType { }
//
//
///// A type-erased channel with potentially different source and output types
/////
///// Forwards operations to an arbitrary underlying channel with the same 
///// `SourceType` and `Element` types, hiding the specifics of the underlying channel type(s).
/////
///// See also: `ChannelZ<T>`.
//public struct ChannelOf<SourceType, Element> : ChannelType {
//    private let subscriber: (subscription: (Element) -> (Void)) -> Receptor
//    private let setter: (SourceType) -> ()
//    private let getter: () -> (SourceType)
//
//    public var value : SourceType {
//        get { return getter() }
//        nonmutating set(newValue) { setter(newValue) }
//    }
//
//    init<G : BaseChannelType where SourceType == G.SourceType, Element == G.Element>(_ base: G) {
//        self.subscriber = { base.subscribe($0) }
//        self.setter = { base.value = $0 }
//        self.getter = { base.value }
//    }
//
//    public func subscribe(subscription: (Element) -> Void) -> Receptor {
//        let sub = subscriber(subscription)
//        return ReceptorOf(requester: { sub.request() }, unsubscriber: { sub.unsubscribe() })
//    }
//
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = ChannelOf
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Channel<Element> { return Channel(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
///// A type-erased channel with identical source and output types.
/////
///// Forwards operations to an arbitrary underlying channel with the same,
///// hiding the specifics of the underlying channel type(s).
/////
///// See also: `ChannelOf<SourceType, Element>`.
//public struct ChannelZ<T> : ChannelType {
//    typealias SourceType = T
//    typealias Element = T
//
//    private let subscriber: (subscription: (T) -> (Void)) -> Receptor
//    private let setter: (T) -> ()
//    private let getter: () -> (T)
//
//    public var value : T {
//        get { return getter() }
//        nonmutating set(newValue) { setter(newValue) }
//    }
//
//    init<G : BaseChannelType where SourceType == G.SourceType, Element == G.Element>(_ base: G) {
//        self.subscriber = { base.subscribe($0) }
//        self.setter = { base.value = $0 }
//        self.getter = { base.value }
//    }
//
//    public func subscribe(subscription: (Element) -> Void) -> Receptor {
//        let sub = subscriber(subscription)
//        return ReceptorOf(requester: { sub.request() }, unsubscriber: { sub.unsubscribe() })
//    }
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = ChannelZ
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Channel<Element> { return Channel(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
///// A Channel around a field, which can be accessed using the value property
//public final class FieldChannel<T> : ChannelType {
//    // Note: this is a reference type since the field itself is the shared mutable state and Swift doesn't have any KVO equivalent
//
//    public typealias SourceType = T
//    public typealias Element = StateEvent<T>
//
//    private var subscriptions = ReceptorList<Element>()
//
//    /// The underlying value of the channel source
//    private var sourceValue : SourceType
//
//    public var value : SourceType {
//        get { return sourceValue }
//        set(newValue) {
//            if subscriptions.entrancy == 0 {
//                let oldValue = sourceValue
//                sourceValue = newValue
//                subscriptions.receive(StateEvent.change(oldValue, value: newValue))
//            }
//        }
//    }
//
//    public init(source v: T) {
//        sourceValue = v
//    }
//
//    public func subscribe(subscription: (Element)->())->Receptor {
//        let index = subscriptions.addReceptor(subscription)
//        return ReceptorOf(requester: { [weak self] in
//            if let this = self {
//                subscription(StateEvent.push(this.value))
//            }
//        }, unsubscriber: { [weak self] in
//            let _ = self?.subscriptions.removeReceptor(index)
//        })
//    }
//
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = FieldChannel
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Channel<Element> { return Channel(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
///// Creates an embedded Channel field source
//public func channelField<T>(source: T)->ChannelZ<T> {
//    return ChannelZ(FieldChannel(source: source).map({ $0.value }))
//}
//
///// Filter that only passes through state mutations of the underlying equatable element
//public func sieveField<T : Equatable>(source: T)->ChannelZ<T> {
//    return channelStateValues(filterChannel(FieldChannel(source: source))({ event in
//        switch event.op {
//        case .Push: return true
//        case .Change(let lastValue): return event.value != lastValue
//        }
//    }))
//}
//
///// Filter that only passes through state mutations of the underlying equatable element
//public func sieveField<T : Equatable>(source: Optional<T>)->ChannelZ<Optional<T>> {
//    let optchan: ChannelOf<Optional<T>, StateEvent<Optional<T>>> = FieldChannel(source: source).channel()
//    return channelOptionalStateChanges(optchan)
//}
//
//
///// A filtered channel that flows only those values that pass the filter predicate
//public struct FilteredChannel<Source : BaseChannelType> : ChannelType {
//    public typealias Element = Source.Element
//    public typealias SourceType = Source.SourceType
//
//    public let source: Source
//    public let predicate: (Source.Element)->Bool
//
//    public var value : SourceType {
//        get { return source.value }
//        nonmutating set(newValue) { source.value = newValue }
//    }
//
//    public init(source: Source, predicate: (Source.Element)->Bool) {
//        self.source = source
//        self.predicate = predicate
//    }
//
//    public func subscribe(subscription: (Source.Element)->Void)->Receptor {
//        let sub = source.subscribe({ if self.predicate($0) { subscription($0) } })
//        return ReceptorOf(requester: { sub.request() }, unsubscriber: { sub.unsubscribe() })
//    }
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = FilteredChannel
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Channel<Element> { return Channel(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
//
///// Internal FilteredChannel curried creation
//internal func filterChannel<T : BaseChannelType>(source: T)(predicate: (T.Element)->Bool)->FilteredChannel<T> {
//    return FilteredChannel(source: source, predicate: predicate)
//}
//
///// Creates a filter around the channel `source` that only passes elements that satisfy the `predicate` function
//public func filter<T : BaseChannelType>(source: T, predicate: (T.Element)->Bool)->FilteredChannel<T> {
//    return filterChannel(source)(predicate)
//}
//
///// Creates a filter wrapper around the `source` channel that skips the first `count` elements
//public func skip<T : BaseChannelType>(source: T, count: UInt = 1)->FilteredChannel<T> {
//    var num = Int(count)
//    return filterChannel(source)({ _ in num-- > 0 })
//}
//
//
///// A mapped channel passes all values through a transformer function before sending them to its subscribed subscriptions
//public struct MappedChannel<Source : BaseChannelType, TransformedType> : ChannelType {
//    public typealias Element = TransformedType
//    public typealias SourceType = Source.SourceType
//
//    public let source: Source
//    public let transformer: (Source.Element)->TransformedType
//
//    public var value : SourceType {
//        get { return source.value }
//        nonmutating set(newValue) { source.value = newValue }
//    }
//
//    public init(source: Source, transformer: (Source.Element)->TransformedType) {
//        self.source = source
//        self.transformer = transformer
//    }
//
//    public func subscribe(subscription: (TransformedType)->Void)->Receptor {
//        let sub = source.subscribe({ subscription(self.transformer($0)) })
//        return ReceptorOf(requester: { sub.request() }, unsubscriber: { sub.unsubscribe() })
//    }
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = MappedChannel
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Channel<Element> { return Channel(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
///// Internal MappedChannel curried creation
//internal func mapChannel<Source : BaseChannelType, TransformedType>(source: Source)(transformer: (Source.Element)->TransformedType)->MappedChannel<Source, TransformedType> {
//    return MappedChannel(source: source, transformer: transformer)
//}
//
//internal func mapOutput<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.Element)->TransformedType)->MappedChannel<Source, TransformedType> {
//    return mapChannel(source)(transform)
//}
//
///// Creates a map around the observable `source` that passes through elements after applying the `transform` function
//public func map<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.Element)->TransformedType)->MappedChannel<Source, TransformedType> {
//    return mapOutput(source, transform)
//}
//
//
///// Encapsulation of a state event, where `op` is a state operation and `value` is the current state
//public protocol StateEventType {
//    typealias Element
//
//    /// The previous value for the state
//    var op: StateOperation<Element> { get }
//
//    /// The new value for the state
//    var value: Element { get }
//}
//
//
///// Encapsulation of a state event, where `op` is a state operation and `value` is the current state
//public struct StateEvent<T> : StateEventType {
//    typealias Element = T
//
//    /// The previous value for the state
//    public let op: StateOperation<T>
//
//    /// The new value for the state
//    public let value: T
//
//    public static func change(from: T, value: T) -> StateEvent<T> {
//        return StateEvent(op: .Change(from), value: value)
//    }
//
//    public static func push(value: T) -> StateEvent<T> {
//        return StateEvent(op: .Push, value: value)
//    }
//}
//
///// An operation on state
//public enum StateOperation<T> {
//    /// A raw state value, such as when the previous state is unknown or uninitialized
//    case Push
//
//    /// A state change with the new value
//    case Change(T)
//}
//
//
///// Channels a StateEventType into just the new values
//internal func channelStateValues<T where T : BaseChannelType, T.Element : StateEventType, T.SourceType == T.Element.Element>(source: T)->ChannelZ<T.SourceType> {
//    return ChannelZ(mapOutput(source, { $0.value }))
//}
//
//
///// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
//internal func channelStateChanges<T where T : BaseChannelType, T.Element : StateEventType, T.SourceType == T.Element.Element, T.Element.Element : Equatable>(source: T)->ChannelZ<T.SourceType> {
//    return channelStateValues(filterChannel(source)({ event in
//        switch event.op {
//        case .Push: return true
//        case .Change(let lastValue): return event.value != lastValue
//        }
//    }))
//}
//
//internal func channelOptionalStateChanges<T where T : Equatable>(source: ChannelOf<Optional<T>, StateEvent<Optional<T>>>)->ChannelZ<Optional<T>> {
//    let filterChanges = source.filter({ (event: StateEvent<Optional<T>>) -> Bool in
//        switch event.op {
//        case .Push: return true
//        case .Change(let lastValue): return event.value != lastValue
//        }
//    })
//
//    return channelStateValues(filterChanges)
//}
//
//
///// Creates a state pipeline between multiple channels with equivalent source and output types; changes made to either side will push the transformed value to the the other side.
/////
///// Note that the SourceType of either side must be identical to the Element of the other side, which is usually accomplished by adding maps and combinations to the pipelines until they achieve parity.
/////
///// :param: source one side of the pipeline
///// :param: prime whether to prime the targets with source's value
///// :param: targets the other side of the pipeline
///// :returns: a unsubscribeable subscription for the conduit
//public func conduit<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.Element, B.SourceType == A.Element>(source: A, prime: Bool = false)(targets: [B]) -> Receptor {
//    var subscriptions = [Receptor]()
//
//    let src = source.subscribe({ for target in targets { target.value = $0 } })
//    subscriptions += [src as Receptor]
//
//    if prime { // tell the source to prime their initial value to the targets
//        subscriptions.map { $0.request() }
//    }
//
//    for target in targets {
//        let trg = target.subscribe({ source.value = $0 })
//        subscriptions += [trg as Receptor]
//    }
//
//    let subscription = ReceptorOf(requester: { for subscription in subscriptions { subscription.request() } }, unsubscriber: { for subscription in subscriptions { subscription.unsubscribe() } })
//
//    return subscription
//}
//
//public func conduit<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.Element, B.SourceType == A.Element>(source: A, targets: B...) -> Receptor {
//    return conduit(source)(targets: targets)
//}
//
//prefix operator ∞ { }
//postfix operator ∞ { }
//
///// Prefix operator for creating a Swift field sieve reference to the underlying equatable type
///// 
///// :param: arg the trailing argument (without a separating space) will be used to initialize a field refence
/////
///// :returns: a ChannelZ wrapper for the Swift field
//public prefix func ∞ <T : Equatable>(rhs: T)->ChannelZ<T> { return sieveField(rhs) }
//
///// Prefix operator for creating a Swift field channel reference to the underlying type
/////
///// :param: arg the trailing argument (without a separating space) will be used to initialize a field refence
/////
///// :returns: a ChannelZ wrapper for the Swift field
//public prefix func ∞ <T>(rhs: T)->ChannelZ<T> { return channelField(rhs) }
//
//public postfix func ∞ <T>(lhs: T)->T { return lhs }
//
//
///// Operator for setting Channel.value that returns the value itself
//infix operator <- {}
//public func <-<T : ChannelType>(var lhs: T, rhs: T.SourceType) -> T.SourceType {
//    lhs.value = rhs
//    return rhs
//}
//
//
///// Conduit creation operators
//infix operator <=∞=> { }
//infix operator <=∞=-> { }
//infix operator ∞=> { }
//infix operator ∞=-> { }
//infix operator <=∞ { }
//infix operator <-=∞ { }
//
//
///// Bi-directional conduit operator with natural equivalence between two identical types
//public func <=∞=><L : ChannelType, R : ChannelType where L.Element == R.SourceType, L.SourceType == R.Element>(lhs: L, rhs: R)->Receptor {
//    return conduit(lhs, rhs)
//}
//
///// Bi-directional conduit operator with natural equivalence between two identical types
//public func <=∞=><L : ChannelType, R : ChannelType where L.Element == R.SourceType, L.SourceType == R.Element>(lhs: L, rhs: [R])->Receptor {
//    return conduit(lhs)(targets: rhs)
//}
//
///// One-sided conduit operator with natural equivalence between two identical types
//public func ∞=><L : ChannelType, R : ChannelType where L.Element == R.SourceType>(lhs: L, rhs: R)->Receptor {
//    let lsink = lhs.subscribe { rhs.value = $0 }
//    return ReceptorOf(requester: { lsink.request() }, unsubscriber: { lsink.unsubscribe() })
//}
//
///// One-sided conduit operator with natural equivalence between two identical types with priming
//public func ∞=-><L : ChannelType, R : ChannelType where L.Element == R.SourceType>(lhs: L, rhs: R)->Receptor {
//    return request(lhs ∞=> rhs)
//}
//
//// this source compiles, but any source that references it crashes the compiler
///// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
////public func ∞~-><T, L : ChannelType, R : ChannelType where L.Element == T, R.SourceType == Optional<T>>(lhs: L, rhs: R)->Receptor {
////    let lsink = lhs.subscribe { rhs.value = $0 }
////    return ReceptorOf(requester: { lsink.request() }, unsubscriber: { lsink.unsubscribe() })
////}
//
//// limited workaround for the above compiler crash by constraining the RHS to the ChannelZ and ChannelOf implementations
//
///// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
//public func ∞=><T, L : ChannelType where L.Element == T>(lhs: L, rhs: ChannelZ<Optional<T>>)->Receptor {
//    return lhs.subscribe { rhs.value = $0 }
//}
//
///// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
//public func ∞=><T, U, L : ChannelType where L.Element == T>(lhs: L, rhs: ChannelOf<Optional<T>, U>)->Receptor {
//    return lhs.subscribe { rhs.value = $0 }
//}
//
///// Bi-directional conduit operator with natural equivalence between two identical types where the left side is primed
//public func <=∞=-><L : ChannelType, R : ChannelType where L.Element == R.SourceType, L.SourceType == R.Element>(lhs: L, rhs: R)->Receptor {
//    return conduit(lhs, prime: true)(targets: [rhs])
//}
//
///// Bi-directional conduit operator with natural equivalence between two identical types where the left side is primed
//public func <=∞=-><L : ChannelType, R : ChannelType where L.Element == R.SourceType, L.SourceType == R.Element>(lhs: L, rhs: [R])->Receptor {
//    return conduit(lhs, prime: true)(targets: rhs)
//}
//
///// Conduit conversion operators
//infix operator <~∞~> { }
//infix operator ∞~> { }
//infix operator ∞~-> { }
//infix operator <~∞ { }
//
//
///// Conduit operator that filters out nil values with a custom transformer
//public func <~∞~> <L : ChannelType, R : ChannelType>(lhs: (o: L, f: L.Element->Optional<R.SourceType>), rhs: (o: R, f: R.Element->Optional<L.SourceType>))->Receptor {
//    let lhsm = lhs.o.map({ lhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! }).channel()
//    let rhsm = rhs.o.map({ rhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! }).channel()
//
//    return conduit(lhsm, rhsm)
//}
//
//
///// Convert (possibly lossily) between two numeric types
//public func <~∞~> <L : ChannelType, R : ChannelType where L.SourceType: ConduitNumericCoercible, L.Element: ConduitNumericCoercible, R.SourceType: ConduitNumericCoercible, R.Element: ConduitNumericCoercible>(lhs: L, rhs: R)->Receptor {
//    return conduit(lhs.map({ convertNumericType($0) }).channel(), rhs.map({ convertNumericType($0) }).channel())
//}
//
//
/////// Convert (possibly lossily) between two numeric types
////public func ∞~> <L : ChannelType, R : ChannelType where L.Element: ConduitNumericCoercible, R.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Receptor {
////    let lsink = lhs.map({ convertNumericType($0) }).subscribe { rhs.value = $0 }
////    return ReceptorOf(unsubscriber: { lsink.unsubscribe() })
////}
////
/////// Convert (possibly lossily) between two numeric types
////public func <~∞ <L : ChannelType, R : ChannelType where R.Element: ConduitNumericCoercible, L.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Receptor {
////    let rsink = rhs.map({ convertNumericType($0) }).subscribe { lhs.value = $0 }
////    return ReceptorOf(unsubscriber: { rsink.unsubscribe() })
////}
//
//
//
/////// Conduit conversion operators
////infix operator <?∞?> { }
////infix operator ∞?> { }
////infix operator <?∞ { }
////
/////// Conduit operator to convert (possibly lossily) between optionally castable types
////public func <?∞?><L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Receptor {
////    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).subscribe { rhs.value = $0 }
////    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).subscribe { lhs.value = $0 }
////    return ReceptorOf(requester: {
////        rsink.request()
////        lsink.request()
////    }, unsubscriber: {
////        rsink.unsubscribe()
////        lsink.unsubscribe()
////    })
////}
////
////
/////// Conduit operator to convert (possibly lossily) between optionally castable types
////public func ∞?> <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Receptor {
////    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).subscribe { rhs.value = $0 }
////    return ReceptorOf(requester: { lsink.request() }, unsubscriber: { lsink.unsubscribe() })
////}
////
/////// Conduit operator to convert (possibly lossily) between optionally castable types
////public func <?∞ <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Receptor {
////    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).subscribe { lhs.value = $0 }
////    return ReceptorOf(requester: { rsink.request() }, unsubscriber: { rsink.unsubscribe() })
////}
