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
    @State var i = 0
    @State var rootEntity = Entity()
    @State var rainDrops = Deque<ModelEntity>()
    let rainTimer = Timer.publish(every: 0.005, on: .main, in: .common).autoconnect()
    @State var collisionSubscription: EventSubscription?
    
    var body: some View {
        RealityView { content in
            rootEntity.addChild(ARSession.shared.sessionRootEntity)
            
            collisionSubscription = content.subscribe(to: CollisionEvents.Began.self) { ce in
                Task {
                    await self.handleCollision(ce)
                }
            }
            
            content.add(rootEntity)
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
    
    func spawnRaindrop() {
        // Spawn physical raindrops from a random point in a given area
        let radius: Float = 0.003
        let mesh = MeshResource.generateSphere(radius: radius)
        let shape = ShapeResource.generateSphere(radius: radius)
        var raindropMaterial = PhysicallyBasedMaterial()
        raindropMaterial.baseColor = .init(tint: .white)
        raindropMaterial.roughness = 0.0
        raindropMaterial.metallic = 0.1
        let rainDrop = ModelEntity(mesh: mesh,
                                   materials: [raindropMaterial])
        rainDrop.components.set(OpacityComponent(opacity: 0.2))
        rainDrop.components.set(CollisionComponent(shapes: [shape]))
        rainDrop.components.set(PhysicsBodyComponent())
        rainDrop.position = [Float.random(in: -3...3),
                             Float.random(in: 2...2.5),
                             Float.random(in: (-2)...(-1))]
        rainDrop.name = "RainDrop"
        rainDrops.append(rainDrop)
        if rainDrops.count > 500 {
            if let oldRainDrop = rainDrops.popFirst() {
                rootEntity.removeChild(oldRainDrop)
            }
        }
        rootEntity.addChild(rainDrop)
    }
    
    @MainActor
    func handleCollision(_ ce: CollisionEvents.Began) async {
        i += 1
        if i == 100 {
            print(ce)
        }
        var rainDropEntity: Entity? = nil
        if ce.entityA.name.contains("RainDrop") && !ce.entityB.name.contains("RainDrop") {
            rainDropEntity = ce.entityA
        } else if !ce.entityA.name.contains("RainDrop") && ce.entityB.name.contains("RainDrop") {
            rainDropEntity = ce.entityB
        } else if ce.entityA.name.contains("RainDrop") && ce.entityB.name.contains("RainDrop") {
            // TODO: combine into puddle
        }
        
        if let rainDropEntity = rainDropEntity {
            print("raindrops hit a surface")
            // Maybe turn into a petal
            let turnIntoPetal = Float.random(in: 0...1) > 0.5
            if turnIntoPetal {
                // a. get entity location and place a new flowerpetal entity there
                // b. replace entity mesh with flowerpetal model
                do {
                    let randomPetal = Int.random(in: 1...9)
                    let petalEntity = try await Entity(named: "rosePetals\(randomPetal)", in: realityKitContentBundle)
                    petalEntity.position = rainDropEntity.position
                    rootEntity.removeChild(rainDropEntity)
                    rootEntity.addChild(petalEntity)
                } catch {
                    print("Error loading rose petal")
                    print(error)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
#endif
