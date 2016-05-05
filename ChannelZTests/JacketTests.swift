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
    var authorZ: Channel<LensSource<Self, Person>, StatePulse<Person>> { return channelZLens({ $0.author }, { $0.author = $1 }) }
    var companiesZ: Channel<LensSource<Self, [Company]>, StatePulse<[Company]>> { return channelZLens({ $0.companies }, { $0.companies = $1 }) }
}

extension ChannelType where Source.Element == Company, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var addressZ: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.address }, { $0.address = $1 }) }
    var employeesZ: Channel<LensSource<Self, [PersonID: Person]>, StatePulse<[PersonID: Person]>> { return channelZLens({ $0.employees }, { $0.employees = $1 }) }
    var ceoIDZ: Channel<LensSource<Self, PersonID>, StatePulse<PersonID>> { return channelZLens({ $0.ceoID }, { $0.ceoID = $1 }) }
    var ctoIDZ: Channel<LensSource<Self, PersonID?>, StatePulse<PersonID?>> { return channelZLens({ $0.ctoID }, { $0.ctoID = $1 }) }
}

extension ChannelType where Source.Element == Person, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var firstNameZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.firstName }, { $0.firstName = $1 }) }
    var lastNameZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.lastName }, { $0.lastName = $1 }) }
    var genderZ: Channel<LensSource<Self, Person.Gender>, StatePulse<Person.Gender>> { return channelZLens({ $0.gender }, { $0.gender = $1 }) }
    var homeAddressZ: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.homeAddress }, { $0.homeAddress = $1 }) }
    var workAddressZ: Channel<LensSource<Self, Address?>, StatePulse<Address?>> { return channelZLens({ $0.workAddress }, { $0.workAddress = $1 }) }
    var previousAddressesZ: Channel<LensSource<Self, [Address]>, StatePulse<[Address]>> { return channelZLens({ $0.previousAddresses }, { $0.previousAddresses = $1 }) }
}

extension ChannelType where Source.Element == Address, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var line1Z: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.line1 }, { $0.line1 = $1 }) }
    var line2Z: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0.line2 }, { $0.line2 = $1 }) }
    var postalCodeZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.postalCode }, { $0.postalCode = $1 }) }
}

extension ChannelType where Source.Element == Address?, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var line1Z: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0?.line1 }, { if let value = $1 { $0?.line1 = value }  }) }
    var line2Z: Channel<LensSource<Self, String??>, StatePulse<String??>> { return channelZLens({ $0?.line2 }, { if let value = $1 { $0?.line2 = value }  }) }
    var postalCodeZ: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0?.postalCode }, { if let value = $1 { $0?.postalCode = value }  }) }
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

        dump(dir)
        dir.companies[0].employees[dir.companies[0].ceoID]?.workAddress?.line2 = "Suite #111"
        dump(dir)

        // let dirZ = channelZPropertyState(dir)

        do {
            let dirz = channelZPropertyState(dir)

            let bebeZ = dirz.authorZ

            bebeZ.homeAddressZ.line1Z.$ = "Foo"
            bebeZ.homeAddressZ.line2Z.$ = "Bar"
            XCTAssertEqual("Foo", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("Bar", bebeZ.$.homeAddress.line2)

            XCTAssertEqual(nil, bebeZ.$.workAddress?.line1)

            XCTAssertEqual(nil, bebeZ.$.workAddress?.line1)
            XCTAssertEqual(nil, bebeZ.$.workAddress?.line2)

            let defaddr = Address(line1: "", line2: nil, postalCode: "")
            bebeZ.workAddressZ.fill({ defaddr }).line1Z.$ = "AAA"
            bebeZ.workAddressZ.fill({ defaddr }).line2Z.$ = "BBB"

            XCTAssertEqual("AAA", bebeZ.$.workAddress?.line1)
            XCTAssertEqual("BBB", bebeZ.$.workAddress?.line2)

            let a1 = bebeZ.homeAddressZ.line1Z.sieve(!=).new()
            let a2 = bebeZ.workAddressZ.fill({ defaddr }).line1Z.sieve(!=).new()

            let b1 = bebeZ.homeAddressZ.line2Z.sieve(!=).new()
            let b2 = bebeZ.workAddressZ.fill({ defaddr }).line2Z.sieve(!=).new()

            a1.bind(a2) // works from home
            b1.bind(b2) // works from home

            bebeZ.$.workAddress?.line1 = "XXX"
            XCTAssertEqual("XXX", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("XXX", bebeZ.$.workAddress?.line1)

            bebeZ.homeAddressZ.line1Z.$ = "YYY"
            XCTAssertEqual("YYY", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("YYY", bebeZ.$.workAddress?.line1)

            bebeZ.workAddressZ.fill({ defaddr }).line1Z.$ = "ZZZ"
            XCTAssertEqual("ZZZ", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("ZZZ", bebeZ.$.workAddress?.line1)


            bebeZ.previousAddressesZ.index(1).line1Z.sieve().new().receive { line in
                print("##### line1", line)
            }

            XCTAssertEqual(0, bebeZ.$.previousAddresses.count)
            bebeZ.previousAddressesZ.index(2).fill({ defaddr }).line1Z.$ = "XYZ"
            XCTAssertEqual(3, bebeZ.$.previousAddresses.count)
            XCTAssertEqual(["XYZ", "XYZ", "XYZ"], bebeZ.$.previousAddresses.map({ $0.line1 }))

            bebeZ.previousAddressesZ.index(1).fill({ defaddr }).line1Z.$ = "ABC"
            XCTAssertEqual(["XYZ", "ABC", "XYZ"], bebeZ.$.previousAddresses.map({ $0.line1 }))


            dirz.companiesZ.index(0).fill({ nil as Company! }).employeesZ.at("359414").value().some().receive {
                print("emp #359414", $0)
            }

            let empnameZ = dirz.companiesZ.index(0).fill({ nil as Company! }).employeesZ.at("359414").fill({ nil as Person! }).firstNameZ
            empnameZ.$ = "Marcus"

            XCTAssertEqual("Marcus", dirz.$.companies.first?.employees["359414"]?.firstName)
        }

    }
}
