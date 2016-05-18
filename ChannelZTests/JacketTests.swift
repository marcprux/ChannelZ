//
//  JacketTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/1/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

import ChannelZ
import XCTest


// MARK: Jacket Test Data Model


typealias PersonID = String

struct Directory {
    var author: Person
    var companies: [Company]
}

struct Company {
    var employees: [PersonID: Person]
    var ceoID: PersonID
    var ctoID: PersonID?
    var address: Address
}

struct Person {
    var firstName: String
    var lastName: String
    var gender: Gender
    var homeAddress: Address
    var workAddress: Address?
    var previousAddresses: [Address]
    enum Gender { case Male, Female }
}

struct Address {
    var line1: String
    var line2: String?
    var postalCode: String
}


extension ChannelType where Source.Element == Directory, Source : TransceiverType, Pulse : StatePulseType, Pulse.Element == Source.Element {
    var author𝚭: Channel<LensSource<Self, Person>, StatePulse<Person>> { return focus({ $0.author }, { $0.author = $1 }) }
    var companies𝚭: Channel<LensSource<Self, [Company]>, StatePulse<[Company]>> { return focus({ $0.companies }, { $0.companies = $1 }) }
}

extension ChannelType where Source.Element == Company, Source : TransceiverType, Pulse : StatePulseType, Pulse.Element == Source.Element {
    var address𝚭: Channel<LensSource<Self, Address>, StatePulse<Address>> { return focus({ $0.address }, { $0.address = $1 }) }
    var employees𝚭: Channel<LensSource<Self, [PersonID: Person]>, StatePulse<[PersonID: Person]>> { return focus({ $0.employees }, { $0.employees = $1 }) }
    var ceoID𝚭: Channel<LensSource<Self, PersonID>, StatePulse<PersonID>> { return focus({ $0.ceoID }, { $0.ceoID = $1 }) }
    var ctoID𝚭: Channel<LensSource<Self, PersonID?>, StatePulse<PersonID?>> { return focus({ $0.ctoID }, { $0.ctoID = $1 }) }
}

extension ChannelType where Source.Element == Person, Source : TransceiverType, Pulse : StatePulseType, Pulse.Element == Source.Element {
    var firstName𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return focus({ $0.firstName }, { $0.firstName = $1 }) }
    var lastName𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return focus({ $0.lastName }, { $0.lastName = $1 }) }
    var gender𝚭: Channel<LensSource<Self, Person.Gender>, StatePulse<Person.Gender>> { return focus({ $0.gender }, { $0.gender = $1 }) }
    var homeAddress𝚭: Channel<LensSource<Self, Address>, StatePulse<Address>> { return focus({ $0.homeAddress }, { $0.homeAddress = $1 }) }
    var workAddress𝚭: Channel<LensSource<Self, Address?>, StatePulse<Address?>> { return focus({ $0.workAddress }, { $0.workAddress = $1 }) }
    var previousAddresses𝚭: Channel<LensSource<Self, [Address]>, StatePulse<[Address]>> { return focus({ $0.previousAddresses }, { $0.previousAddresses = $1 }) }
}

extension ChannelType where Source.Element == Address, Source : TransceiverType, Pulse : StatePulseType, Pulse.Element == Source.Element {
    var line1𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return focus({ $0.line1 }, { $0.line1 = $1 }) }
    var line2𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return focus({ $0.line2 }, { $0.line2 = $1 }) }
    var postalCode𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return focus({ $0.postalCode }, { $0.postalCode = $1 }) }
}

extension ChannelType where Source.Element == Address?, Source : TransceiverType, Pulse : StatePulseType, Pulse.Element == Source.Element {
    var line1𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return focus({ $0?.line1 }, { if let value = $1 { $0?.line1 = value }  }) }
    var line2𝚭: Channel<LensSource<Self, String??>, StatePulse<String??>> { return focus({ $0?.line2 }, { if let value = $1 { $0?.line2 = value }  }) }
    var postalCode𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return focus({ $0?.postalCode }, { if let value = $1 { $0?.postalCode = value }  }) }
}


extension ChannelTests {
    func testJacket() {


        let bebe = Person(firstName: "Beatrice", lastName: "Walter",
                          gender: .Female,
                          homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                          workAddress: nil,
                          previousAddresses: [])

        var dir = Directory(author: bebe,
                            companies: [
                                Company(employees: [
                                    "359414": Person(firstName: "Marc", lastName: "Walter",
                                        gender: .Male,
                                        homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                        workAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                        previousAddresses: [])
                                    ],
                                    ceoID: "359414",
                                    ctoID: nil,
                                    address: Address(line1: "1 NaN Loop", line2: nil, postalCode: "99999"))
            ]
        )

//        let firstNameLens = Lens<Person, String>({ $0.firstName }, { $0.firstName = $1 })
        let lastNameLens = Lens<Person, String>({ $0.lastName }, { $0.lastName = $1 })

        dir.companies[0].employees[dir.companies[0].ceoID]?.workAddress?.line2 = "Suite #111"

        do {
            let dir𝚭 = transceiveZ(dir)

            let bebe𝚭 = dir𝚭.author𝚭

            bebe𝚭.homeAddress𝚭.line1𝚭.$ = "Foo"
            bebe𝚭.homeAddress𝚭.line2𝚭.$ = "Bar"
            XCTAssertEqual("Foo", bebe𝚭.$.homeAddress.line1)
            XCTAssertEqual("Bar", bebe𝚭.$.homeAddress.line2)

            XCTAssertEqual(nil, bebe𝚭.$.workAddress?.line1)

            XCTAssertEqual(nil, bebe𝚭.$.workAddress?.line1)
            XCTAssertEqual(nil, bebe𝚭.$.workAddress?.line2)

            let defaddr = Address(line1: "", line2: nil, postalCode: "")
            bebe𝚭.workAddress𝚭.coalesce({ _ in defaddr }).line1𝚭.$ = "AAA"
            bebe𝚭.workAddress𝚭.coalesce({ _ in defaddr }).line2𝚭.$ = "BBB"

            XCTAssertEqual("AAA", bebe𝚭.$.workAddress?.line1)
            XCTAssertEqual("BBB", bebe𝚭.$.workAddress?.line2)

            let a1 = bebe𝚭.homeAddress𝚭.line1𝚭.sieve(!=).new()
            let a2 = bebe𝚭.workAddress𝚭.coalesce({ _ in defaddr }).line1𝚭.sieve(!=).new()

            let b1 = bebe𝚭.homeAddress𝚭.line2𝚭.sieve(!=).new()
            let b2 = bebe𝚭.workAddress𝚭.coalesce({ _ in defaddr }).line2𝚭.sieve(!=).new()

            a1.bind(a2) // works from home
            b1.bind(b2) // works from home

            bebe𝚭.$.workAddress?.line1 = "XXX"
            XCTAssertEqual("XXX", bebe𝚭.$.homeAddress.line1)
            XCTAssertEqual("XXX", bebe𝚭.$.workAddress?.line1)

            bebe𝚭.homeAddress𝚭.line1𝚭.$ = "YYY"
            XCTAssertEqual("YYY", bebe𝚭.$.homeAddress.line1)
            XCTAssertEqual("YYY", bebe𝚭.$.workAddress?.line1)

            bebe𝚭.workAddress𝚭.coalesce({ _ in defaddr }).line1𝚭.$ = "ZZZ"
            XCTAssertEqual("ZZZ", bebe𝚭.$.homeAddress.line1)
            XCTAssertEqual("ZZZ", bebe𝚭.$.workAddress?.line1)

            let prevZ = bebe𝚭.previousAddresses𝚭

            var lines: [String?] = []
            prevZ.index(1).line1𝚭.sieve().new().receive { line in
                lines.append(line)
            }

            XCTAssertEqual(0, bebe𝚭.$.previousAddresses.count)
            prevZ.index(2).coalesce({ _ in defaddr }).line1𝚭.$ = "XYZ"
            XCTAssertEqual(3, bebe𝚭.$.previousAddresses.count)
            XCTAssertEqual(["XYZ", "XYZ", "XYZ"], bebe𝚭.$.previousAddresses.map({ $0.line1 }))

            prevZ.index(1).coalesce({ _ in defaddr }).line1𝚭.$ = "ABC"
            XCTAssertEqual(["XYZ", "ABC", "XYZ"], bebe𝚭.$.previousAddresses.map({ $0.line1 }))


            XCTAssertEqual(["XYZ", "ABC"].flatMap({ $0 }), lines.flatMap({ $0 }))

            // create an accessor for the prism
            let line1Lens = Lens<Address, String>({ $0.line1 }, { $0.line1 = $1 })
//            let line2Lens = Lens<Address, String?>({ $0.line2 }, { $0.line2 = $1 })

            let line1sZ = prevZ.prism(line1Lens)

            XCTAssertEqual(["XYZ", "ABC", "XYZ"], line1sZ.$)

            line1sZ.$ = ["123", "123", "123"]
            XCTAssertEqual(["123", "123", "123"], line1sZ.$)

            line1sZ.$ = ["QQQ"] // a prism set to a subset will only apply to the subset
            XCTAssertEqual(["QQQ", "123", "123"], line1sZ.$)


            // sets the last two elements of the lensed collection, ignoring any trail-offs
            prevZ.range(1...2).prism(line1Lens).$ = ["PRQ", "PRQ", "PRQ", "PRQ"]
            XCTAssertEqual(["QQQ", "PRQ", "PRQ"], line1sZ.$)


            // check non-contiguous index access
            prevZ.indices([2, 0, 1]).prism(line1Lens).$ = ["Z", "X", "Y"]
            XCTAssertEqual(["X", "Y", "Z"], line1sZ.$)

            // creates a "select" combination of collection and index channels
            let indexChannel = transceiveZ([0])
            let selectZ = prevZ.indexed(indexChannel).prism(line1Lens)

            let seltrap = selectZ.trap(Int.max)
            
            XCTAssertEqual(["X"], selectZ.$)

            XCTAssertEqual(2, seltrap.caught.count)

            // changing the index changes the underlying prism
            indexChannel.$ = [2, 0]
            XCTAssertEqual(["Z", "X"], selectZ.$)
            XCTAssertEqual(3, seltrap.caught.count)


            // changing the values changes the underlying prism
            line1sZ.$ = ["A", "B", "C"]
            XCTAssertEqual(["C", "A"], selectZ.$)
            XCTAssertEqual(["A", "B", "C"], line1sZ.$)
            XCTAssertEqual(4, seltrap.caught.count)

            selectZ.$ = ["Q", "T"]
            XCTAssertEqual(["Q", "T"], selectZ.$)
            XCTAssertEqual(["T", "B", "Q"], line1sZ.$)
            XCTAssertEqual(5, seltrap.caught.count)

            // invalidating an index drops the last selection
            prevZ.$.removeLast()
            XCTAssertEqual(["T"], selectZ.$)
            XCTAssertEqual(6, seltrap.caught.count)

            indexChannel.$ = Array((0...999).reverse()) // go outside the bounds
            XCTAssertEqual(["B", "T"], selectZ.$)
            XCTAssertEqual(["T", "B"], line1sZ.$)

            selectZ.$ = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["T", "B"], line1sZ.$)

            indexChannel.$ = Array((0...999)) // go outside the bounds
            selectZ.$ = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["Y", "X"], line1sZ.$)

            selectZ.$ = Array(count: 2, repeatedValue: "T")
            XCTAssertEqual(["T", "T"], line1sZ.$)

            var persons: [Person] = []
            let company = dir𝚭.companies𝚭.index(0).coalesce({ _ in nil as Company! })

            company.employees𝚭.at("359414").value().some().receive { person in
                persons.append(person)
            }

            let empname𝚭 = company.employees𝚭.at("359414").coalesce({ _ in nil as Person! }).firstName𝚭
            empname𝚭.$ = "Marcus"

            XCTAssertEqual("Marcus", dir𝚭.$.companies.first?.employees["359414"]?.firstName)

            // now add two more employees and edit mutliple aspects of them

            let doeHome = Address(line1: "123 Doe Lane", line2: nil, postalCode: "44556")

            company.employees𝚭.$["888888"] = Person(firstName: "John", lastName: "Doe", gender: .Male, homeAddress: doeHome, workAddress: nil, previousAddresses: [])
            company.employees𝚭.$["999999"] = Person(firstName: "Jane", lastName: "Doe", gender: .Female, homeAddress: doeHome, workAddress: nil, previousAddresses: [])

            XCTAssertEqual(dir𝚭.$.companies.flatMap({ $0.employees.values }).count, 3)

            // TODO: generalize select() to work on collections and dictionaries
            let keysChannel = transceiveZ(["888888"])
            let keyedZ: Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, StatePulse<Directory>>, [Company]>, StatePulse<[Company]>>, Company?>, StatePulse<Company?>>, Company>, StatePulse<Company>>, [PersonID : Person]>, StatePulse<[PersonID : Person]>>, [Person?]>, StatePulse<[Person?]>> = company.employees𝚭.keyed(keysChannel)

            let empselZ = keyedZ.prism(lastNameLens.prism)
            let empseltrap = empselZ.trap(Int.max)

            XCTAssertEqual(3, company.employees𝚭.$.count)

            XCTAssertEqual(2, empseltrap.caught.count)
            XCTAssertEqual(["Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            keysChannel.$ += ["NaN", "999999"]
            XCTAssertEqual(3, empseltrap.caught.count)
            XCTAssertEqual(["Doe", "Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            empselZ.$ = ["A", "B"] // missing key won't be updated
            XCTAssertEqual(4, empseltrap.caught.count)
            XCTAssertEqual(3, company.employees𝚭.$.count)

            XCTAssertEqual(["A", "Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            empselZ.$ = ["X", "Y", "Z"]
            XCTAssertEqual(5, empseltrap.caught.count)
            XCTAssertEqual(3, company.employees𝚭.$.count)
            XCTAssertEqual("X", empseltrap.value?.new[0])
            XCTAssertEqual(nil, empseltrap.value?.new[1])
            XCTAssertEqual("Z", empseltrap.value?.new[2])

            empselZ.$ = [nil, nil, nil] // no effect since lastName is non-nullable
            XCTAssertEqual(6, empseltrap.caught.count)
            XCTAssertEqual(3, company.employees𝚭.$.count)
            XCTAssertEqual(3, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 3 {
                XCTAssertEqual("X", empseltrap.value?.new[0])
                XCTAssertEqual(nil, empseltrap.value?.new[1])
                XCTAssertEqual("Z", empseltrap.value?.new[2])
            }

            // include duplicates in the channel
            keysChannel.$ = ["999999", "888888", "999999", "888888", "999999"]
            empselZ.$ = ["A", "B", "C", "D", "E"]
            XCTAssertEqual(5, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 5 {
                XCTAssertEqual("E", empseltrap.value?.new[0])
                XCTAssertEqual("D", empseltrap.value?.new[1])
                XCTAssertEqual("E", empseltrap.value?.new[2])
                XCTAssertEqual("D", empseltrap.value?.new[3])
                XCTAssertEqual("E", empseltrap.value?.new[4])
            }
            XCTAssertEqual(company.employees𝚭.$["888888"]?.lastName, "D")
            XCTAssertEqual(company.employees𝚭.$["999999"]?.lastName, "E")
        }

    }

    func testLensChannels() {
        let prop = transceiveZ((int: 1, dbl: 2.2, str: "Foo", sub: (a: true, b: 22, c: "")))

        let str = prop.focus({ $0.str }, { $0.str = $1 })
        let int = prop.focus({ $0.int }, { $0.int = $1 })
        let dbl = prop.focus({ $0.dbl }, { $0.dbl = $1 })
        let sub = prop.focus({ $0.sub }, { $0.sub = $1 })
        let suba = sub.focus({ $0.a }, { $0.a = $1 })
        let subb = sub.focus({ $0.b }, { $0.b = $1 })
        let subc = sub.focus({ $0.c }, { $0.c = $1 })

        // subc = Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<X>, StatePulse<X>>, Y>, StatePulse<Y>>, String>, StatePulse<String>>

        str.$ = "Bar"
        int.$ = 2
        dbl.$ = 5.5

        suba.$ = false
        subb.$ = 999
        subc.$ = "x"

        XCTAssertEqual(prop.$.str, "Bar")
        XCTAssertEqual(prop.$.int, 2)
        XCTAssertEqual(prop.$.dbl, 5.5)

        XCTAssertEqual(prop.$.sub.a, false)
        XCTAssertEqual(prop.$.sub.b, 999)
        XCTAssertEqual(prop.$.sub.c, "x")

        // children can affect parent values and it will update state and fire receivers
        var strUpdates = 0
        var strChanges = 0
        str.subsequent().receive({ _ in strUpdates += 1 })
        str.subsequent().sieve(!=).receive({ _ in strChanges += 1 })
        XCTAssertEqual(0, strChanges)

        subc.owner.owner.$.str = "Baz"
        XCTAssertEqual(prop.$.str, "Baz")
        XCTAssertEqual(1, strUpdates)
        XCTAssertEqual(1, strChanges)

        subc.owner.$.b = 7
        XCTAssertEqual(prop.$.sub.b, 7)
        XCTAssertEqual(2, strUpdates) // note that str changes even when a different property changed
        XCTAssertEqual(1, strChanges) // so we sieve for changes

        subc.owner.owner.$.str = "Baz"

        let compound = str.new() & subb.new()
//        dump(compound)
        compound.receive { str, int in
            XCTAssertEqual("Baz", str)
            XCTAssertEqual(7, int)
        }

//        dump(compound.$)
//        let MVλ = 1
    }
}
