//
//  File.swift
//  RoomPlanExampleApp
//
//  Created by Guilherme on 20/10/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import RoomPlan

struct SelectedObject: Identifiable {
    let id: UUID
    let type: CapturedRoom.Surface.Category!
    let legend: String
}

