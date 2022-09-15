//
//  User.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 11/09/2022.
//

import Foundation

struct User {
    let id: String
    let name: String
    let color: Color?
    let bio: String?
}



extension User: Codable {}



extension User: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}



extension User: Comparable {
    static func < (lhs: User, rhs: User) -> Bool {
        return lhs.name < rhs.name
    }
}
