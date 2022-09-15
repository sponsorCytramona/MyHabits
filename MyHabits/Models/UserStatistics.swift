//
//  UserStatistics.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 13/09/2022.
//

import Foundation

struct UserStatistics {
    let user: User
    let habitCounts: [HabitCount]
}



extension UserStatistics: Codable {}
