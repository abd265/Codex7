// Adapted from lucasnewman/vocos-swift (MIT). See THIRD_PARTY_NOTICES.txt.
import Foundation
import MLX
import MLXFFT
import MLXNN

final class VocosConvNeXtBlock: Module {
    let norm: LayerNorm
    let dwconv: GroupableConv1d
    let pwconv1: Linear
    let act: GELU
    let pwconv2: Linear
    let gamma: MLXArray
    init(dim: Int = 512, intermediateDim: Int = 1536) {
        dwconv = GroupableConv1d(inputChannels: dim, outputChannels: dim, kernelSize: 7, padding: 3, groups: dim)
        norm = LayerNorm(dimensions: dim, eps: 1e-6)
        pwconv1 = Linear(dim, intermediateDim)
        act = GELU()
        pwconv2 = Linear(intermediateDim, dim)
        gamma = MLXArray.ones([dim]) / 8
        super.init()
    }
    func callAsFunction(_ x: MLXArray) -> MLXArray { x + gamma * pwconv2(act(pwconv1(norm(dwconv(x))))) }
}

final class VocosBackbone: Module {
    let embed: Conv1d
    let norm: LayerNorm
    let convnext: [VocosConvNeXtBlock]
    let final_layer_norm: LayerNorm
    override init() {
        embed = Conv1d(inputChannels: 100, outputChannels: 512, kernelSize: 7, padding: 3)
        norm = LayerNorm(dimensions: 512, eps: 1e-6)
        convnext = (0..<8).map { _ in VocosConvNeXtBlock() }
        final_layer_norm = LayerNorm(dimensions: 512, eps: 1e-6)
        super.init()
    }
    func callAsFunction(_ input: MLXArray) -> MLXArray {
        var x = norm(embed(input))
        for block in convnext { x = block(x) }
        return final_layer_norm(x)
    }
}

final class VocosISTFT: Module {
    let window = MLXArray((0..<1024).map { Float(0.5 * (1 - cos(2 * Double.pi * Double($0) / 1024))) })
}

final class VocosISTFTHead: Module {
    let out = Linear(512, 1026)
    let istft = VocosISTFT()
    func decode(_ input: MLXArray) throws -> [Float] {
        let projection = out(input).asType(.float32)
        let pieces = projection.split(parts: 2, axis: -1)
        let magnitude = MLX.minimum(MLX.exp(pieces[0]), 100)
        let phase = pieces[1]
        let spectrum = magnitude * (MLX.cos(phase) + MLX.sin(phase).asImaginary())
        let framesArray = MLXFFT.irfft(spectrum.squeezed(axis: 0))
        MLX.eval(framesArray)
        let frameCount = framesArray.shape[0]
        guard framesArray.shape.count == 2, framesArray.shape[1] == 1024, frameCount > 1 else {
            throw DarjaF5Error.invalidAudio("The vocoder produced an invalid spectrogram.")
        }
        let frames = framesArray.asArray(Float.self)
        let window = istft.window.asArray(Float.self)
        let total = (frameCount - 1) * 256 + 1024
        var output = [Float](repeating: 0, count: total)
        var denominator = [Float](repeating: 0, count: total)
        for frame in 0..<frameCount {
            if frame % 32 == 0 { try Task.checkCancellation() }
            for sample in 0..<1024 {
                let index = frame * 256 + sample
                output[index] += frames[frame * 1024 + sample] * window[sample]
                denominator[index] += window[sample] * window[sample]
            }
        }
        return (512..<(total - 512)).map { denominator[$0] > 1e-10 ? output[$0] / denominator[$0] : 0 }
    }
}

final class DarjaVocos: Module {
    let backbone = VocosBackbone()
    let head = VocosISTFTHead()
    func decode(_ mel: MLXArray) throws -> [Float] {
        try head.decode(backbone(mel.asType(.float32)))
    }
}
