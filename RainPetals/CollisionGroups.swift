//
//  CollisionGroups.swift
//  RainPetals
//
//  Created by Sam Hodak on 3/5/24.
//

import Foundation
import RealityKit


// Let petals only collide with planes and rain, not other petals
let meshGroup = CollisionGroup(rawValue: 1 << 0)
let rainGroup = CollisionGroup(rawValue: 1 << 1)
let petalGroup = CollisionGroup(rawValue: 1 << 2)

let petalMask = CollisionGroup.all.subtracting(petalGroup)
let petalFilter = CollisionFilter(group: petalGroup, mask: petalMask)
