//
//  CombinedStatistics.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 13/09/2022.
//

import Foundation

struct CombinedStatistics {
    let userStatistics: [UserStatistics]
    let habitStatistics: [HabitStatistics]
}

extension CombinedStatistics: Codable {}

