//
//  ImmersiveView.swift
//  RainPetals
//
//  Created by Sam Hodak on 3/4/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import DequeModule


struct ImmersiveView: View {
    @State var rootEntity = Entity()
    let rainTimer = Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()
    @State var collisionSubscription: EventSubscription?
    
    var body: some View {
        RealityView { content in
            rootEntity.addChild(ARSession.shared.sessionRootEntity)
            content.add(rootEntity)
            
            collisionSubscription = content.subscribe(to: CollisionEvents.Began.self) { ce in
                Task {
                    await self.handleCollision(ce)
                }
            }
        }
        .task {
            await runARSession()
        }
        .onDisappear() {
            ARSession.shared.endSession()
        }
        .onReceive(rainTimer, perform: { _ in
            spawnRaindrop()
            
        })
    }
    
    @MainActor
    func runARSession() async {
        await ARSession.shared.authorize()
        if ARSession.shared.isAuthorized {
            await ARSession.shared.startSession()
            Task {
                await ARSession.shared.runSceneReconstruction()
            }
        }
    }
    
    @MainActor
    func spawnRaindrop() {
        // Spawn physical raindrops from a random point in a given area
        let radius: Float = 0.002
        let mesh = MeshResource.generateSphere(radius: radius)
        let shape = ShapeResource.generateSphere(radius: radius)
        var raindropMaterial = PhysicallyBasedMaterial()
        raindropMaterial.baseColor = .init(tint: .white)
        raindropMaterial.roughness = 0.0
        raindropMaterial.metallic = 0.0
        raindropMaterial.blending = .transparent(opacity: 0.1)
        let rainDrop = ModelEntity(mesh: mesh,
                                   materials: [raindropMaterial])
        rainDrop.components.set(CollisionComponent(shapes: [shape],
                                                   isStatic: false,
                                                   filter: CollisionFilter(group: rainGroup, mask: .all)))
        var physicsComponent = PhysicsBodyComponent()
        physicsComponent.linearDamping = 5
        physicsComponent.massProperties.mass = 0.1
        rainDrop.components.set(physicsComponent)
        rainDrop.position = [Float.random(in: (-0.3)...(0.3)),
                             Float.random(in: 2...2.5),
                             Float.random(in: (-1.5)...(0))]
        rainDrop.name = "RainDrop"
        rootEntity.addChild(rainDrop)
    }
    
    @MainActor
    func handleCollision(_ ce: CollisionEvents.Began) async {
        var raindropEntity: Entity? = nil
        if ce.entityA.name.contains("RainDrop") && !ce.entityB.name.contains("RainDrop") {
            raindropEntity = ce.entityA
        } else if !ce.entityA.name.contains("RainDrop") && ce.entityB.name.contains("RainDrop") {
            raindropEntity = ce.entityB
        } else if ce.entityA.name.contains("RainDrop") && ce.entityB.name.contains("RainDrop") {
            // TODO: combine into puddle
        }
        
        guard let raindropEntity = raindropEntity else { return }
        
        let turnIntoPetal = Float.random(in: 0...1) > 0.2
        if turnIntoPetal {
            await spawnPetal(for: raindropEntity)
        } else {
            rootEntity.removeChild(raindropEntity)
        }
    }
    
    @MainActor
    func spawnPetal(for rainDropEntity: Entity) async {
        do {
            let randomPetal = Int.random(in: 1...9)
            let petalEntity = try await Entity(named: "rosePetals\(randomPetal)", in: realityKitContentBundle)
            petalEntity.position = rainDropEntity.position
            if let petalModel = petalEntity.findEntity(named: "Mesh") {
                petalModel.components[PhysicsBodyComponent.self]?.linearDamping = 1
                petalModel.components[PhysicsBodyComponent.self]?.angularDamping = 1
                petalModel.components[CollisionComponent.self]?.filter = petalFilter
            }
            
            rootEntity.addChild(petalEntity)
        } catch {
            print("Error loading rose petal")
            print(error)
        }
    }
}

#if DEBUG
#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
#endif
