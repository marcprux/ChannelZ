//
//  Combinators.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 4/5/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//


/// One of a set number of options
public protocol OneOfN {
    /// Returns the number of choices
    var arity: Int { get }

    /// The first type in thie OneOf
    associatedtype T1
    var first: T1? { get }
}

/// One of 2 options
public enum OneOf2<T1, T2>: OneOfN {
    public var arity: Int { return 2 }

    /// First of 2
    case V1(T1)
    /// Second of 2
    case V2(T2)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }
}

/// One of 3 options
public enum OneOf3<T1, T2, T3>: OneOfN {
    public var arity: Int { return 3 }

    /// First of 3
    case V1(T1)
    /// Second of 3
    case V2(T2)
    /// Third of 3
    case V3(T3)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<T1, T2>, T3> {
        switch self {
        case .V1(let v): return .V1(.V1(v))
        case .V2(let v): return .V1(.V2(v))
        case .V3(let v): return .V2(v)
        }
    }
}

/// One of 4 options
public enum OneOf4<T1, T2, T3, T4>: OneOfN {
    public var arity: Int { return 4 }

    /// First of 4
    case V1(T1)
    /// Second of 4
    case V2(T2)
    /// Third of 4
    case V3(T3)
    /// Fourth of 4
    case V4(T4)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(v)))
        case .V2(let v): return .V1(.V1(.V2(v)))
        case .V3(let v): return .V1(.V2(v))
        case .V4(let v): return .V2(v)
        }
    }
}

/// One of 5 options
public enum OneOf5<T1, T2, T3, T4, T5>: OneOfN {
    public var arity: Int { return 5 }

    /// First of 5
    case V1(T1)
    /// Second of 5
    case V2(T2)
    /// Third of 5
    case V3(T3)
    /// Fourth of 5
    case V4(T4)
    /// Fifth of 5
    case V5(T5)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(v))))
        case .V2(let v): return .V1(.V1(.V1(.V2(v))))
        case .V3(let v): return .V1(.V1(.V2(v)))
        case .V4(let v): return .V1(.V2(v))
        case .V5(let v): return .V2(v)
        }
    }
}

/// One of 6 options
public enum OneOf6<T1, T2, T3, T4, T5, T6>: OneOfN {
    public var arity: Int { return 6 }

    /// First of 6
    case V1(T1)
    /// Second of 6
    case V2(T2)
    /// Third of 6
    case V3(T3)
    /// Fourth of 6
    case V4(T4)
    /// Fifth of 6
    case V5(T5)
    /// Sixth of 6
    case V6(T6)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(v)))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V3(let v): return .V1(.V1(.V1(.V2(v))))
        case .V4(let v): return .V1(.V1(.V2(v)))
        case .V5(let v): return .V1(.V2(v))
        case .V6(let v): return .V2(v)
        }
    }
}

/// One of 7 options
public enum OneOf7<T1, T2, T3, T4, T5, T6, T7>: OneOfN {
    public var arity: Int { return 7 }

    /// First of 7
    case V1(T1)
    /// Second of 7
    case V2(T2)
    /// Third of 7
    case V3(T3)
    /// Fourth of 7
    case V4(T4)
    /// Fifth of 7
    case V5(T5)
    /// Sixth of 7
    case V6(T6)
    /// Seventh of 7
    case V7(T7)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(v))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V4(let v): return .V1(.V1(.V1(.V2(v))))
        case .V5(let v): return .V1(.V1(.V2(v)))
        case .V6(let v): return .V1(.V2(v))
        case .V7(let v): return .V2(v)
        }
    }
}

/// One of 8 options
public enum OneOf8<T1, T2, T3, T4, T5, T6, T7, T8>: OneOfN {
    public var arity: Int { return 8 }

    /// First of 8
    case V1(T1)
    /// Second of 8
    case V2(T2)
    /// Third of 8
    case V3(T3)
    /// Fourth of 8
    case V4(T4)
    /// Fifth of 8
    case V5(T5)
    /// Sixth of 8
    case V6(T6)
    /// Seventh of 8
    case V7(T7)
    /// Eighth of 8
    case V8(T8)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V5(let v): return .V1(.V1(.V1(.V2(v))))
        case .V6(let v): return .V1(.V1(.V2(v)))
        case .V7(let v): return .V1(.V2(v))
        case .V8(let v): return .V2(v)
        }
    }
}

/// One of 9 options
public enum OneOf9<T1, T2, T3, T4, T5, T6, T7, T8, T9>: OneOfN {
    public var arity: Int { return 9 }

    /// First of 9
    case V1(T1)
    /// Second of 9
    case V2(T2)
    /// Third of 9
    case V3(T3)
    /// Fourth of 9
    case V4(T4)
    /// Fifth of 9
    case V5(T5)
    /// Sixth of 9
    case V6(T6)
    /// Seventh of 9
    case V7(T7)
    /// Eighth of 9
    case V8(T8)
    /// Ninth of 9
    case V9(T9)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V6(let v): return .V1(.V1(.V1(.V2(v))))
        case .V7(let v): return .V1(.V1(.V2(v)))
        case .V8(let v): return .V1(.V2(v))
        case .V9(let v): return .V2(v)
        }
    }
}

/// One of 10 options
public enum OneOf10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>: OneOfN {
    public var arity: Int { return 10 }

    /// First of 10
    case V1(T1)
    /// Second of 10
    case V2(T2)
    /// Third of 10
    case V3(T3)
    /// Fourth of 10
    case V4(T4)
    /// Fifth of 10
    case V5(T5)
    /// Sixth of 10
    case V6(T6)
    /// Seventh of 10
    case V7(T7)
    /// Eighth of 10
    case V8(T8)
    /// Ninth of 10
    case V9(T9)
    /// Tenth of 10
    case V10(T10)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V7(let v): return .V1(.V1(.V1(.V2(v))))
        case .V8(let v): return .V1(.V1(.V2(v)))
        case .V9(let v): return .V1(.V2(v))
        case .V10(let v): return .V2(v)
        }
    }
}

/// One of 11 options
public enum OneOf11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>: OneOfN {
    public var arity: Int { return 11 }

    /// First of 11
    case V1(T1)
    /// Second of 11
    case V2(T2)
    /// Third of 11
    case V3(T3)
    /// Fourth of 11
    case V4(T4)
    /// Fifth of 11
    case V5(T5)
    /// Sixth of 11
    case V6(T6)
    /// Seventh of 11
    case V7(T7)
    /// Eighth of 11
    case V8(T8)
    /// Ninth of 11
    case V9(T9)
    /// Tenth of 11
    case V10(T10)
    /// Eleventh of 11
    case V11(T11)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V8(let v): return .V1(.V1(.V1(.V2(v))))
        case .V9(let v): return .V1(.V1(.V2(v)))
        case .V10(let v): return .V1(.V2(v))
        case .V11(let v): return .V2(v)
        }
    }
}


/// One of 12 options
public enum OneOf12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>: OneOfN {
    public var arity: Int { return 12 }

    /// First of 12
    case V1(T1)
    /// Second of 12
    case V2(T2)
    /// Third of 12
    case V3(T3)
    /// Fourth of 12
    case V4(T4)
    /// Fifth of 12
    case V5(T5)
    /// Sixth of 12
    case V6(T6)
    /// Seventh of 12
    case V7(T7)
    /// Eighth of 12
    case V8(T8)
    /// Ninth of 12
    case V9(T9)
    /// Tenth of 12
    case V10(T10)
    /// Eleventh of 12
    case V11(T11)
    /// Twelfth of 12
    case V12(T12)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V9(let v): return .V1(.V1(.V1(.V2(v))))
        case .V10(let v): return .V1(.V1(.V2(v)))
        case .V11(let v): return .V1(.V2(v))
        case .V12(let v): return .V2(v)
        }
    }
}

/// One of 13 options
public enum OneOf13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>: OneOfN {
    public var arity: Int { return 13 }

    /// First of 13
    case V1(T1)
    /// Second of 13
    case V2(T2)
    /// Third of 13
    case V3(T3)
    /// Fourth of 13
    case V4(T4)
    /// Fifth of 13
    case V5(T5)
    /// Sixth of 13
    case V6(T6)
    /// Seventh of 13
    case V7(T7)
    /// Eighth of 13
    case V8(T8)
    /// Ninth of 13
    case V9(T9)
    /// Tenth of 13
    case V10(T10)
    /// Eleventh of 13
    case V11(T11)
    /// Twelfth of 13
    case V12(T12)
    /// Thirteenth of 13
    case V13(T13)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V10(let v): return .V1(.V1(.V1(.V2(v))))
        case .V11(let v): return .V1(.V1(.V2(v)))
        case .V12(let v): return .V1(.V2(v))
        case .V13(let v): return .V2(v)
        }
    }
}

/// One of 14 options
public enum OneOf14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>: OneOfN {
    public var arity: Int { return 14 }

    /// First of 14
    case V1(T1)
    /// Second of 14
    case V2(T2)
    /// Third of 14
    case V3(T3)
    /// Fourth of 14
    case V4(T4)
    /// Fifth of 14
    case V5(T5)
    /// Sixth of 14
    case V6(T6)
    /// Seventh of 14
    case V7(T7)
    /// Eighth of 14
    case V8(T8)
    /// Ninth of 14
    case V9(T9)
    /// Tenth of 14
    case V10(T10)
    /// Eleventh of 14
    case V11(T11)
    /// Twelfth of 14
    case V12(T12)
    /// Thirteenth of 14
    case V13(T13)
    /// Fourteenth of 14
    case V14(T14)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V11(let v): return .V1(.V1(.V1(.V2(v))))
        case .V12(let v): return .V1(.V1(.V2(v)))
        case .V13(let v): return .V1(.V2(v))
        case .V14(let v): return .V2(v)
        }
    }
}

/// One of 15 options
public enum OneOf15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>: OneOfN {
    public var arity: Int { return 15 }

    /// First of 15
    case V1(T1)
    /// Second of 15
    case V2(T2)
    /// Third of 15
    case V3(T3)
    /// Fourth of 15
    case V4(T4)
    /// Fifth of 15
    case V5(T5)
    /// Sixth of 15
    case V6(T6)
    /// Seventh of 15
    case V7(T7)
    /// Eighth of 15
    case V8(T8)
    /// Ninth of 15
    case V9(T9)
    /// Tenth of 15
    case V10(T10)
    /// Eleventh of 15
    case V11(T11)
    /// Twelfth of 15
    case V12(T12)
    /// Thirteenth of 15
    case V13(T13)
    /// Fourteenth of 15
    case V14(T14)
    /// Fifteenth of 15
    case V15(T15)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V12(let v): return .V1(.V1(.V1(.V2(v))))
        case .V13(let v): return .V1(.V1(.V2(v)))
        case .V14(let v): return .V1(.V2(v))
        case .V15(let v): return .V2(v)
        }
    }
}

/// One of 16 options
public enum OneOf16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>: OneOfN {
    public var arity: Int { return 16 }

    /// First of 16
    case V1(T1)
    /// Second of 16
    case V2(T2)
    /// Third of 16
    case V3(T3)
    /// Fourth of 16
    case V4(T4)
    /// Fifth of 16
    case V5(T5)
    /// Sixth of 16
    case V6(T6)
    /// Seventh of 16
    case V7(T7)
    /// Eighth of 16
    case V8(T8)
    /// Ninth of 16
    case V9(T9)
    /// Tenth of 16
    case V10(T10)
    /// Eleventh of 16
    case V11(T11)
    /// Twelfth of 16
    case V12(T12)
    /// Thirteenth of 16
    case V13(T13)
    /// Fourteenth of 16
    case V14(T14)
    /// Fifteenth of 16
    case V15(T15)
    /// Sixteenth of 16
    case V16(T16)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V12(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V13(let v): return .V1(.V1(.V1(.V2(v))))
        case .V14(let v): return .V1(.V1(.V2(v)))
        case .V15(let v): return .V1(.V2(v))
        case .V16(let v): return .V2(v)
        }
    }
}

/// One of 17 options
public enum OneOf17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>: OneOfN {
    public var arity: Int { return 17 }

    /// First of 17
    case V1(T1)
    /// Second of 17
    case V2(T2)
    /// Third of 17
    case V3(T3)
    /// Fourth of 17
    case V4(T4)
    /// Fifth of 17
    case V5(T5)
    /// Sixth of 17
    case V6(T6)
    /// Seventh of 17
    case V7(T7)
    /// Eighth of 17
    case V8(T8)
    /// Ninth of 17
    case V9(T9)
    /// Tenth of 17
    case V10(T10)
    /// Eleventh of 17
    case V11(T11)
    /// Twelfth of 17
    case V12(T12)
    /// Thirteenth of 17
    case V13(T13)
    /// Fourteenth of 17
    case V14(T14)
    /// Fifteenth of 17
    case V15(T15)
    /// Sixteenth of 17
    case V16(T16)
    /// Seventeenth of 17
    case V17(T17)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V12(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V13(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V14(let v): return .V1(.V1(.V1(.V2(v))))
        case .V15(let v): return .V1(.V1(.V2(v)))
        case .V16(let v): return .V1(.V2(v))
        case .V17(let v): return .V2(v)
        }
    }
}


/// One of 18 options
public enum OneOf18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>: OneOfN {
    public var arity: Int { return 18 }

    /// First of 18
    case V1(T1)
    /// Second of 18
    case V2(T2)
    /// Third of 18
    case V3(T3)
    /// Fourth of 18
    case V4(T4)
    /// Fifth of 18
    case V5(T5)
    /// Sixth of 18
    case V6(T6)
    /// Seventh of 18
    case V7(T7)
    /// Eighth of 18
    case V8(T8)
    /// Ninth of 18
    case V9(T9)
    /// Tenth of 18
    case V10(T10)
    /// Eleventh of 18
    case V11(T11)
    /// Twelfth of 18
    case V12(T12)
    /// Thirteenth of 18
    case V13(T13)
    /// Fourteenth of 18
    case V14(T14)
    /// Fifteenth of 18
    case V15(T15)
    /// Sixteenth of 18
    case V16(T16)
    /// Seventeenth of 18
    case V17(T17)
    /// Eighteenth of 18
    case V18(T18)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V12(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V13(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V14(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V15(let v): return .V1(.V1(.V1(.V2(v))))
        case .V16(let v): return .V1(.V1(.V2(v)))
        case .V17(let v): return .V1(.V2(v))
        case .V18(let v): return .V2(v)
        }
    }
}


/// One of 19 options
public enum OneOf19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>: OneOfN {
    public var arity: Int { return 19 }

    /// First of 19
    case V1(T1)
    /// Second of 19
    case V2(T2)
    /// Third of 19
    case V3(T3)
    /// Fourth of 19
    case V4(T4)
    /// Fifth of 19
    case V5(T5)
    /// Sixth of 19
    case V6(T6)
    /// Seventh of 19
    case V7(T7)
    /// Eighth of 19
    case V8(T8)
    /// Ninth of 19
    case V9(T9)
    /// Tenth of 19
    case V10(T10)
    /// Eleventh of 19
    case V11(T11)
    /// Twelfth of 19
    case V12(T12)
    /// Thirteenth of 19
    case V13(T13)
    /// Fourteenth of 19
    case V14(T14)
    /// Fifteenth of 19
    case V15(T15)
    /// Sixteenth of 19
    case V16(T16)
    /// Seventeenth of 19
    case V17(T17)
    /// Eighteenth of 19
    case V18(T18)
    /// Nineteenth of 19
    case V19(T19)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18>, T19> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v))))))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V12(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V13(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V14(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V15(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V16(let v): return .V1(.V1(.V1(.V2(v))))
        case .V17(let v): return .V1(.V1(.V2(v)))
        case .V18(let v): return .V1(.V2(v))
        case .V19(let v): return .V2(v)
        }
    }
}


/// One of 20 options
public enum OneOf20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>: OneOfN {
    public var arity: Int { return 20 }

    /// First of 20
    case V1(T1)
    /// Second of 20
    case V2(T2)
    /// Third of 20
    case V3(T3)
    /// Fourth of 20
    case V4(T4)
    /// Fifth of 20
    case V5(T5)
    /// Sixth of 20
    case V6(T6)
    /// Seventh of 20
    case V7(T7)
    /// Eighth of 20
    case V8(T8)
    /// Ninth of 20
    case V9(T9)
    /// Tenth of 20
    case V10(T10)
    /// Eleventh of 20
    case V11(T11)
    /// Twelfth of 20
    case V12(T12)
    /// Thirteenth of 20
    case V13(T13)
    /// Fourteenth of 20
    case V14(T14)
    /// Fifteenth of 20
    case V15(T15)
    /// Sixteenth of 20
    case V16(T16)
    /// Seventeenth of 20
    case V17(T17)
    /// Eighteenth of 20
    case V18(T18)
    /// Nineteenth of 20
    case V19(T19)
    /// Twentieth of 20
    case V20(T20)

    public var first: T1? { if case .V1(let x) = self { return x } else { return nil } }

    /// Split the tuple into nested OneOf2 instances
    public func split() -> OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<OneOf2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18>, T19>, T20> {
        switch self {
        case .V1(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(v)))))))))))))))))))
        case .V2(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))))))
        case .V3(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))))
        case .V4(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))))
        case .V5(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))))
        case .V6(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))))
        case .V7(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))))
        case .V8(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))))
        case .V9(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))))
        case .V10(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))))
        case .V11(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))))
        case .V12(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))))
        case .V13(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V1(.V2(v))))))))
        case .V14(let v): return .V1(.V1(.V1(.V1(.V1(.V1(.V2(v)))))))
        case .V15(let v): return .V1(.V1(.V1(.V1(.V1(.V2(v))))))
        case .V16(let v): return .V1(.V1(.V1(.V1(.V2(v)))))
        case .V17(let v): return .V1(.V1(.V1(.V2(v))))
        case .V18(let v): return .V1(.V1(.V2(v)))
        case .V19(let v): return .V1(.V2(v))
        case .V20(let v): return .V2(v)
        }
    }
}

// MARK - Channel either with flatten operation: |

/// Channel either & flattening operation
public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), OneOf2<T1, T2>> {
    return lhs.either(rhs)
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), OneOf2<T1, T2>>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), OneOf3<T1, T2, T3>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V2(let x): return .V3(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), OneOf3<T1, T2, T3>>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), OneOf4<T1, T2, T3, T4>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V2(let x): return .V4(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), OneOf4<T1, T2, T3, T4>>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), OneOf5<T1, T2, T3, T4, T5>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V2(let x): return .V5(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), OneOf5<T1, T2, T3, T4, T5>>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), OneOf6<T1, T2, T3, T4, T5, T6>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V2(let x): return .V6(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), OneOf6<T1, T2, T3, T4, T5, T6>>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), OneOf7<T1, T2, T3, T4, T5, T6, T7>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V2(let x): return .V7(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), OneOf7<T1, T2, T3, T4, T5, T6, T7>>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), OneOf8<T1, T2, T3, T4, T5, T6, T7, T8>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V2(let x): return .V8(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), OneOf8<T1, T2, T3, T4, T5, T6, T7, T8>>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), OneOf9<T1, T2, T3, T4, T5, T6, T7, T8, T9>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V2(let x): return .V9(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), OneOf9<T1, T2, T3, T4, T5, T6, T7, T8, T9>>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), OneOf10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V2(let x): return .V10(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), OneOf10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), OneOf11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V2(let x): return .V11(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), OneOf11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), OneOf12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V2(let x): return .V12(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), OneOf12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), OneOf13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V2(let x): return .V13(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), OneOf13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), OneOf14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V2(let x): return .V14(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), OneOf14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), OneOf15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V2(let x): return .V15(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), OneOf15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), OneOf16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V1(.V15(let x)): return .V15(x)
        case .V2(let x): return .V16(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), OneOf16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), OneOf17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V1(.V15(let x)): return .V15(x)
        case .V1(.V16(let x)): return .V16(x)
        case .V2(let x): return .V17(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), OneOf17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), OneOf18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V1(.V15(let x)): return .V15(x)
        case .V1(.V16(let x)): return .V16(x)
        case .V1(.V17(let x)): return .V17(x)
        case .V2(let x): return .V18(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), OneOf18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), OneOf19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V1(.V15(let x)): return .V15(x)
        case .V1(.V16(let x)): return .V16(x)
        case .V1(.V17(let x)): return .V17(x)
        case .V1(.V18(let x)): return .V18(x)
        case .V2(let x): return .V19(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), OneOf19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>>, rhs: Channel<S20, T20>) -> Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), OneOf20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>> {
    return combineSources(lhs.either(rhs)).map { oneof in
        switch oneof {
        case .V1(.V1(let x)): return .V1(x)
        case .V1(.V2(let x)): return .V2(x)
        case .V1(.V3(let x)): return .V3(x)
        case .V1(.V4(let x)): return .V4(x)
        case .V1(.V5(let x)): return .V5(x)
        case .V1(.V6(let x)): return .V6(x)
        case .V1(.V7(let x)): return .V7(x)
        case .V1(.V8(let x)): return .V8(x)
        case .V1(.V9(let x)): return .V9(x)
        case .V1(.V10(let x)): return .V10(x)
        case .V1(.V11(let x)): return .V11(x)
        case .V1(.V12(let x)): return .V12(x)
        case .V1(.V13(let x)): return .V13(x)
        case .V1(.V14(let x)): return .V14(x)
        case .V1(.V15(let x)): return .V15(x)
        case .V1(.V16(let x)): return .V16(x)
        case .V1(.V17(let x)): return .V17(x)
        case .V1(.V18(let x)): return .V18(x)
        case .V1(.V19(let x)): return .V19(x)
        case .V2(let x): return .V20(x)
        }
    }
}


// MARK - Channel combine with flatten operation: &

/// Channel `combine` & flattening operation
public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.combine(rhs)
}
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineAll(lhs.combine(rhs))) }


// MARK - Channel zip with flatten operation: ^

/// Channel zipping & flattening operation
public func ^<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineAll(lhs.zip(rhs))) }


private func combineSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.1) } }
private func combineSources<S1, S2, S3, S4, T>(rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.0.18, src.1) } }

private func combineAll<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func combineAll<S, T1, T2, T3, T4>(rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.0.18, $0.1) } }
