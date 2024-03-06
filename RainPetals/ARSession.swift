//
//  ARSession.swift
//  RainPetals
//
//  Created by Sam Hodak on 3/5/24.
//

import Foundation
import ARKit
import SwiftUI
import RealityKit


@MainActor
class ARSession {
    static let shared = ARSession()
    
    var sessionRootEntity = Entity()
    var isAuthorized = false
    var meshEntities: [UUID: ModelEntity] = [:]
    
    var sceneData = SceneReconstructionProvider()
    let session = ARKitSession()
    
    func startSession() async {
        do {
            // Assign to new DataProvider, overwriting the existing one
            sceneData = SceneReconstructionProvider()
            try await session.run([sceneData])
        } catch {
            print("Error running AR Session")
            print(error.localizedDescription)
        }
    }
    
    func endSession() {
        session.stop()
        
        for entity in meshEntities.values {
            entity.removeFromParent()
        }
        
        sessionRootEntity.removeFromParent()
        meshEntities = [:]
    }
    
    func runSceneReconstruction() async {
        for await update in sceneData.anchorUpdates {
            await handleSceneDataUpdate(update: update)
        }
    }
    
    func authorize() async {
        let authorizationResult = await session.requestAuthorization(for: [.worldSensing])
        
        for (authorizationType, authorizationStatus) in authorizationResult {
            print("\(authorizationType): \(authorizationStatus)")
            
            switch authorizationStatus {
            case .allowed:
                isAuthorized = true
            case .denied, .notDetermined:
                isAuthorized = false
                // Todo: warn user that app will not function without this and request auth again
            @unknown default:
                break
            }
        }
    }
    
    // MARK: Scene Reconstruction
    
    func handleSceneDataUpdate(update: AnchorUpdate<MeshAnchor>) async {
        let meshAnchor = update.anchor
        
        var shape: ShapeResource? = nil
        do {
            shape = try await ShapeResource.generateStaticMesh(from: meshAnchor)
        } catch {
            print("Could not make shape from MeshAnchor")
            return
        }
        
        guard let shape = shape else { return }
        
        switch update.event {
        case .added:
            guard let mesh = GU.generateMeshFrom(anchorGeometry: meshAnchor.geometry) else { return }
             
//            let materials = [UnlitMaterial(color: .blue)]
            let materials = [OcclusionMaterial()]
            let entity = ModelEntity(mesh: mesh, materials: materials)
            
            entity.components.set(CollisionComponent(shapes: [shape],
                                                     isStatic: true,
                                                     filter: CollisionFilter(group: meshGroup, mask: .all)))
            entity.components.set(PhysicsBodyComponent())
//            entity.components.set(OpacityComponent(opacity: 0.2))
            entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
            
            meshEntities[meshAnchor.id] = entity
            sessionRootEntity.addChild(entity)
        case .updated:
            guard let entity = meshEntities[meshAnchor.id] else { return }
            entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
            entity.collision?.shapes = [shape]
        case .removed:
            meshEntities[meshAnchor.id]?.removeFromParent()
            meshEntities.removeValue(forKey: meshAnchor.id)
        }
    }
}
