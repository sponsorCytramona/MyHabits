//
//  UserCount.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 12/09/2022.
//

import Foundation

struct UserCount {
    var user: User
    var count: Int
}



extension UserCount: Codable {}

extension UserCount: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }
    
    static func ==(_ lhs: UserCount, _ rhs: UserCount) -> Bool {
        return lhs.user == rhs.user
    }
}
