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


extension ChannelType where Source.Element == Directory, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var author𝚭: Channel<LensSource<Self, Person>, StatePulse<Person>> { return channelZLens({ $0.author }, { $0.author = $1 }) }
    var companies𝚭: Channel<LensSource<Self, [Company]>, StatePulse<[Company]>> { return channelZLens({ $0.companies }, { $0.companies = $1 }) }
}

extension ChannelType where Source.Element == Company, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var address𝚭: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.address }, { $0.address = $1 }) }
    var employees𝚭: Channel<LensSource<Self, [PersonID: Person]>, StatePulse<[PersonID: Person]>> { return channelZLens({ $0.employees }, { $0.employees = $1 }) }
    var ceoID𝚭: Channel<LensSource<Self, PersonID>, StatePulse<PersonID>> { return channelZLens({ $0.ceoID }, { $0.ceoID = $1 }) }
    var ctoID𝚭: Channel<LensSource<Self, PersonID?>, StatePulse<PersonID?>> { return channelZLens({ $0.ctoID }, { $0.ctoID = $1 }) }
}

extension ChannelType where Source.Element == Person, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var firstName𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.firstName }, { $0.firstName = $1 }) }
    var lastName𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.lastName }, { $0.lastName = $1 }) }
    var gender𝚭: Channel<LensSource<Self, Person.Gender>, StatePulse<Person.Gender>> { return channelZLens({ $0.gender }, { $0.gender = $1 }) }
    var homeAddress𝚭: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.homeAddress }, { $0.homeAddress = $1 }) }
    var workAddress𝚭: Channel<LensSource<Self, Address?>, StatePulse<Address?>> { return channelZLens({ $0.workAddress }, { $0.workAddress = $1 }) }
    var previousAddresses𝚭: Channel<LensSource<Self, [Address]>, StatePulse<[Address]>> { return channelZLens({ $0.previousAddresses }, { $0.previousAddresses = $1 }) }
}

extension ChannelType where Source.Element == Address, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var line1𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.line1 }, { $0.line1 = $1 }) }
    var line2𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0.line2 }, { $0.line2 = $1 }) }
    var postalCode𝚭: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.postalCode }, { $0.postalCode = $1 }) }
}

extension ChannelType where Source.Element == Address?, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var line1𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0?.line1 }, { if let value = $1 { $0?.line1 = value }  }) }
    var line2𝚭: Channel<LensSource<Self, String??>, StatePulse<String??>> { return channelZLens({ $0?.line2 }, { if let value = $1 { $0?.line2 = value }  }) }
    var postalCode𝚭: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0?.postalCode }, { if let value = $1 { $0?.postalCode = value }  }) }
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

//        dump(dir)
        dir.companies[0].employees[dir.companies[0].ceoID]?.workAddress?.line2 = "Suite #111"
//        dump(dir)

        // let dir𝚭 = channelZPropertyState(dir)

        do {
            let dir𝚭 = channelZPropertyState(dir)

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


            var lines: [String?] = []
            bebe𝚭.previousAddresses𝚭.index(1).line1𝚭.sieve().new().receive { line in
                lines.append(line)
            }

            XCTAssertEqual(0, bebe𝚭.$.previousAddresses.count)
            bebe𝚭.previousAddresses𝚭.index(2).coalesce({ _ in defaddr }).line1𝚭.$ = "XYZ"
            XCTAssertEqual(3, bebe𝚭.$.previousAddresses.count)
            XCTAssertEqual(["XYZ", "XYZ", "XYZ"], bebe𝚭.$.previousAddresses.map({ $0.line1 }))

            bebe𝚭.previousAddresses𝚭.index(1).coalesce({ _ in defaddr }).line1𝚭.$ = "ABC"
            XCTAssertEqual(["XYZ", "ABC", "XYZ"], bebe𝚭.$.previousAddresses.map({ $0.line1 }))


            XCTAssertEqual(["XYZ", "ABC"].flatMap({ $0 }), lines.flatMap({ $0 }))

            var persons: [Person] = []
            dir𝚭.companies𝚭.index(0).coalesce({ _ in nil as Company! }).employees𝚭.at("359414").value().some().receive { person in
                persons.append(person)
            }

            let empname𝚭 = dir𝚭.companies𝚭.index(0).coalesce({ _ in nil as Company! }).employees𝚭.at("359414").coalesce({ _ in nil as Person! }).firstName𝚭
            empname𝚭.$ = "Marcus"

            XCTAssertEqual("Marcus", dir𝚭.$.companies.first?.employees["359414"]?.firstName)
        }

    }
}
