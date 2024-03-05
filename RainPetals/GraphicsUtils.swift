//
//  GraphicsUtils.swift
//  RainPetals
//
//  Created by Sam Hodak on 3/5/24.
//

import Foundation
import RealityKit
import CoreGraphics
import ARKit

typealias GU = GraphicsUtils

class GraphicsUtils {
    
    @MainActor static func generateMeshFrom(anchorGeometry geometry: MeshAnchor.Geometry) -> MeshResource? {
        do {
            var desc = MeshDescriptor()
            let posValues = geometry.vertices.asSIMD3(ofType: Float.self)
            desc.positions = .init(posValues)
            let normalValues = geometry.normals.asSIMD3(ofType: Float.self)
            desc.normals = .init(normalValues)
            
            // Why is this "do" block wrapping this code without a try or a catch?
            do {
                desc.primitives = .polygons(
                    // They should all be triangles, so write 3 here.
                    (0..<geometry.faces.count).map { _ in UInt8(3) },
                    (0..<geometry.faces.count * 3).map {
                        geometry.faces.buffer.contents()
                            .advanced(by: $0 * geometry.faces.bytesPerIndex)
                            .assumingMemoryBound(to: UInt32.self).pointee
                    }
                )
            }
            
            let meshResource = try MeshResource.generate(from: [desc])
            return meshResource
        } catch {
            print("Error creating model entity: \(error)")
            return nil
        }
    }
    
    static func getTextureFrom(cgImage: CGImage) async -> TextureResource? {
        do {
            let textureOptions = TextureResource.CreateOptions(semantic: .color)
            let texture = try await TextureResource.generate(from: cgImage, options: textureOptions)
            
            return texture
        } catch {
            print("Error creating texture from object")
            print(error.localizedDescription)
            return nil
        }
    }
    
    static func getModelEntityDimensions(_ modelEntity: ModelEntity) -> SIMD3<Float>? {
        guard let boundingBox = modelEntity.model?.mesh.bounds else { return nil }
        
        return boundingBox.max - boundingBox.min
    }
}
