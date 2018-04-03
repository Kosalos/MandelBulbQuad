// https://pastebin.com/PMq3jBHQ

import UIKit
import Metal
import simd

let MAP3DSIZE = MemoryLayout<Map3D>.stride
let HBUFFERSIZE = MemoryLayout<Int32>.size * 256

enum Busy { case idle,calc,calc2,smooth,smooth2,quantize,vertices,controlLoaded }

let FORMULA_JULIA = 5

extension CGPoint {
    mutating func reset() { x = 0; y = 0 }
}

let NUM_CLOUD = 8
var cloudCount:Int = 1
let vMax = Int(Float(255000000) / Float( MemoryLayout<TVertex>.size))
var hBuffer:MTLBuffer! = nil
var pointSize:Float = 4
var vCount:Int = 0

class Bulb {
    var busyCode:Busy = .idle
    var vertices:[TVertex] = []
    var vBuffer:MTLBuffer! = nil

    init() {
        for _ in 0 ..< vMax+10 { vertices.append(TVertex())  }
        reset()
    }
    
    func reset() {
        control.basex = -1.14133
        control.basey = -1.12
        control.basez = -1.102
        control.scale = 0.008
        control.power = 8
        
        if control.formula == JULIA_FORMULA { 
            control.basex = -0.6296
            control.basey = -0.5722
            control.basez = -3.3456
            control.scale = 0.01492
            control.re1 = -0.3617
            control.im1 = -0.5633
            control.mult1 = 3.3201
            control.zoom1 = 553
            control.re2 = -0.3617
            control.im2 = -0.5633
            control.mult2 = 3.3201
            control.zoom2 = 553
        }
        
        if control.formula == BOX_FORMULA {
            control.re1 = 1.04
            control.im1 = 1.77
            control.mult1 = 0.81
            control.zoom1 = 1.47
            control.re2 = 1     // scale
            control.im2 = 1.9   // cutoff
        }
        
        previousControl = control
    }
    
    //MARK: ==================================
    
    var cagePointCount:Int = 0
    var cagePointData = Array(repeating:TVertex(), count:100)
    var cageBuffer:MTLBuffer! = nil
    
    func drawCages(_ renderEncoder:MTLRenderCommandEncoder) {
        if cagePointData.count > 0 {
            if cageBuffer == nil {
                cageBuffer = gDevice?.makeBuffer(bytes: cagePointData, length: 100 * MemoryLayout<TVertex>.size, options: MTLResourceOptions())
            }
            else {
                cageBuffer = gDevice?.makeBuffer(bytes: cagePointData, length: cagePointData.count * MemoryLayout<TVertex>.size, options: MTLResourceOptions())
            }

            renderEncoder.setVertexBuffer(cageBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount:cagePointCount)
        }
    }
    
    func calcCages() {
        func addLine(_ v1:float3, _ v2:float3, _ color:float4) {
            func lineEndPoint(_ pos:float3) {
                cagePointData[cagePointCount].color = color
                cagePointData[cagePointCount].pos = pos
                cagePointCount += 1
            }

            lineEndPoint(v1)
            lineEndPoint(v2)
        }
        
        func addCage(_ x1:Float, _ x2:Float, _ y1:Float, _ y2:Float, _ z1:Float, _ z2:Float, _ color:float4) {
            let p1 = float3(x1,y1,z1)
            let p2 = float3(x2,y1,z1)
            let p3 = float3(x2,y2,z1)
            let p4 = float3(x1,y2,z1)
            let p5 = float3(x1,y1,z2)
            let p6 = float3(x2,y1,z2)
            let p7 = float3(x2,y2,z2)
            let p8 = float3(x1,y2,z2)
            
            addLine(p1,p2,color);  addLine(p2,p3,color);  addLine(p3,p4,color);  addLine(p4,p1,color)
            addLine(p1,p5,color);  addLine(p2,p6,color);  addLine(p3,p7,color);  addLine(p4,p8,color)
            addLine(p5,p6,color);  addLine(p6,p7,color);  addLine(p7,p8,color);  addLine(p8,p5,color)
        }
        
        func plusMinusSigns(_ pt:float3) {
            let SS:Float = 2.5
            let x1 = pt.x - SS
            let x2 = pt.x + SS
            let y1 = pt.y - SS
            let y2 = pt.y + SS
            let z1 = pt.z - SS
            let z2 = pt.z + SS
            let color = float4(1,1,1,1)
            
            addLine(float3(x1,pt.y,pt.z),float3(x2,pt.y,pt.z),color)
            addLine(float3(pt.x,y1,pt.z),float3(pt.x,y2,pt.z),color)
            addLine(float3(pt.x,pt.y,z1),float3(pt.x,pt.y,z2),color)
            
            if pt.x != 0 { addLine(float3(-x1,pt.y,pt.z),float3(-x2,pt.y,pt.z),color) }
            if pt.y != 0 { addLine(float3(pt.x,-y1,pt.z),float3(pt.x,-y2,pt.z),color) }
            if pt.z != 0 { addLine(float3(pt.x,pt.y,-z1),float3(pt.x,pt.y,-z2),color) }
        }
        
        // ======================================================================
        
        cagePointCount = 0
        
        let gwidth = Float(WIDTH)/2    /// /2 because of render scaling
        let centerOffset = gwidth / 2

        // current Calc
        let GG:Float = 0.3
        let color = float4(GG,GG,GG,1)
        var x1:Float = -centerOffset
        var y1:Float = -centerOffset
        var z1:Float = -centerOffset
        var x2:Float = x1 + gwidth
        var y2:Float = y1 + gwidth
        var z2:Float = z1 + gwidth
        addCage(x1,x2,y1,y2,z1,z2,color)
        
        // old position -----------------------------
        let oldBasex = previousControl.basex
        let oldBasey = previousControl.basey
        let oldBasez = previousControl.basez
        let oldScl = previousControl.scale
        let oldGScale = gwidth * oldScl     // # pixels = 1.0

        // new position -----------------------------
        let newBasex = control.basex
        let newBasey = control.basey
        let newBasez = control.basez
        let newScl = control.scale
        
        let dx = newBasex - oldBasex
        let dy = newBasey - oldBasey
        let dz = newBasez - oldBasez
        
        let gg = gwidth / oldGScale / 2
        x1 += dx * gg
        y1 += dy * gg
        z1 += dz * gg

        let sclRatio = newScl / oldScl
        let ggg = gwidth * sclRatio
        x2 = x1 + ggg
        y2 = y1 + ggg
        z2 = z1 + ggg
        addCage(x1,x2,y1,y2,z1,z2,float4(1,1,0,1))
        
        // axes ---------------------------------------
        let AA:Float = Float(30 + WIDTH / 4)
        let BB:Float = AA + 10
        addLine(float3(-AA,0,0),float3(AA,0,0),float4(1,0,0,1))
        addLine(float3(0,-AA,0),float3(0,AA,0),float4(0,1,0,1))
        addLine(float3(0,0,-AA),float3(0,0,AA),float4(0,0,1,1))
        
        plusMinusSigns(float3(BB,0,0))
        plusMinusSigns(float3(0,BB,0))
        plusMinusSigns(float3(0,0,BB))
    }
    
    //MARK: ==================================

    var pipeLineJulia:MTLComputePipelineState! = nil
    var pipeLineAdjacent:MTLComputePipelineState! = nil
    var pipeLineSmooth:MTLComputePipelineState! = nil
    var pipeLineQuantize:MTLComputePipelineState! = nil
    var pipeLineHistogram:MTLComputePipelineState! = nil
    var pipeLineVertices:MTLComputePipelineState! = nil
    var mBuffer:MTLBuffer! = nil    // map3d
    var mBuffer2:MTLBuffer! = nil
    
    var controlBuffer:MTLBuffer! = nil
    var jetBuffer:MTLBuffer! = nil
    var vCountBuffer:MTLBuffer! = nil
    var commandQueue:MTLCommandQueue! = nil

    //MARK: ==================================

    func calcMap() {
        if commandQueue == nil {
            commandQueue = gDevice.makeCommandQueue()

            let defaultLibrary = gDevice.makeDefaultLibrary()

            func makePipeline(_ name:String) -> MTLComputePipelineState {
                guard let kf1 = defaultLibrary!.makeFunction(name: name)  else { fatalError("Error attaching shader: " + name) }
                
                do {
                    return try gDevice.makeComputePipelineState(function: kf1)
                }
                catch { fatalError("Error making pipline to: " + name) }
            }
        
            pipeLineJulia = makePipeline("mapShader")
            pipeLineAdjacent = makePipeline("adjacentShader")
            pipeLineSmooth = makePipeline("smoothingShader")
            pipeLineQuantize = makePipeline("quantizeShader")
            pipeLineHistogram = makePipeline("histogramShader")
            pipeLineVertices = makePipeline("verticeShader")
            
            mBuffer  = gDevice.makeBuffer(length:MAP3DSIZE * NUM_CLOUD, options:MTLResourceOptions.storageModeShared)
            mBuffer2 = gDevice.makeBuffer(length:MAP3DSIZE * NUM_CLOUD, options:MTLResourceOptions.storageModeShared)
            
            controlBuffer = gDevice.makeBuffer(length:MemoryLayout<Control>.stride,  options:MTLResourceOptions.storageModeShared)
            vCountBuffer = gDevice.makeBuffer(length:MemoryLayout<Counter>.stride,  options:MTLResourceOptions.storageModeShared)
            hBuffer = gDevice.makeBuffer(length:MemoryLayout<Histogram>.stride,  options:MTLResourceOptions.storageModeShared)
            jetBuffer = gDevice.makeBuffer(length:MemoryLayout<float3>.stride * 256,  options:MTLResourceOptions.storageModeShared)

            vBuffer = gDevice.makeBuffer(bytes:vertices, length: vMax * MemoryLayout<TVertex>.stride, options: MTLResourceOptions())

            loadNextColorMap()
        }
        
        for i in 0 ..< cloudCount {
            control.cloudIndex = Int32(i)
            controlBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)
            
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            commandEncoder.setComputePipelineState(pipeLineJulia)
            commandEncoder.setBuffer(mBuffer, offset:MAP3DSIZE * i, index: 0)
            commandEncoder.setBuffer(controlBuffer, offset: 0, index: 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            if true { // control.formula != 3 { // adjacent shader removes completely surrounded pixels
                let commandBuffer = commandQueue.makeCommandBuffer()!
                let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
                
                commandEncoder.setComputePipelineState(pipeLineAdjacent)
                commandEncoder.setBuffer(mBuffer, offset:MAP3DSIZE * i, index: 0)
                
                commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
                commandEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }
    }
    
    //MARK: ==================================

    func calcVertices() {
        if mBuffer == nil { return }
        memset(vCountBuffer.contents(),0,MemoryLayout<Counter>.stride)
        
        for i in 0 ..< cloudCount {
            control.cloudIndex = Int32(i)
            controlBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)

            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            commandEncoder.setComputePipelineState(pipeLineVertices)
            commandEncoder.setBuffer(mBuffer,       offset:MAP3DSIZE * i, index: 0)
            commandEncoder.setBuffer(vCountBuffer,  offset: 0, index: 1)
            commandEncoder.setBuffer(controlBuffer, offset: 0, index: 2)
            commandEncoder.setBuffer(jetBuffer,     offset: 0, index: 3)
            commandEncoder.setBuffer(vBuffer,       offset: 0, index: 4)
            
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        var result = Counter()
        memcpy(&result,vCountBuffer.contents(),MemoryLayout<Counter>.stride)
        vCount = Int(result.count)

        vc.updateCalcButton(CALC_BUTTON_IDLE)
        
        if hv != nil {
            histogramUpdate()
            hv.setNeedsDisplay()
        }
    }
    
    //MARK: ==================================
    
    var colorMapIndex:Int = -1
    
    func loadNextColorMap() {
        colorMapIndex += 1
        if colorMapIndex > 3 { colorMapIndex = 0 }
        
        let jbSize = MemoryLayout<float3>.stride * 256
        
        switch colorMapIndex {
        case 0 : jetBuffer.contents().copyMemory(from:colorMap1, byteCount:jbSize)
        case 1 : jetBuffer.contents().copyMemory(from:colorMap2, byteCount:jbSize)
        case 2 : jetBuffer.contents().copyMemory(from:colorMap3, byteCount:jbSize)
        case 3 : jetBuffer.contents().copyMemory(from:colorMap4, byteCount:jbSize)
        default : break
        }
    }
    
    //MARK: ==================================
    func smooth() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeLineSmooth)
        commandEncoder.setBuffer(mBuffer,  offset: 0, index: 0)
        commandEncoder.setBuffer(mBuffer2, offset: 0, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        memcpy(mBuffer.contents(),mBuffer2.contents(),MAP3DSIZE)
    }
    
    func quantize() {
        controlBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeLineQuantize)
        commandEncoder.setBuffer(mBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(controlBuffer, offset: 0, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func histogramUpdate() {
        memset(hBuffer.contents(),0,HBUFFERSIZE)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeLineHistogram)
        commandEncoder.setBuffer(mBuffer,  offset: 0, index: 0)
        commandEncoder.setBuffer(hBuffer,  offset: 0, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    //MARK: ==================================
    
    func render(_ renderEncoder:MTLRenderCommandEncoder) {
        if vCount > 0 {
            renderEncoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount:vCount)
        }
        
        if showAxesFlag { drawCages(renderEncoder) }
    }
    
    //MARK: ==================================

    var previousControl = Control()

    func smoothData() { newBusy(.smooth) }
    func smoothData2() { newBusy(.smooth2) }

    func quantizeData() {
        control.unused1 = 0xf8;
        newBusy(.quantize)
    }

    func quantizeData2() {
        control.unused1 = 0xfe;
        newBusy(.quantize)
    }

    func newBusy(_ code:Busy) {
        busyCode = code
        vc.mtkViewL.setNeedsDisplay()
        vc.mtkViewR.setNeedsDisplay()
    }
    
    func fastCalc() {
        control.hop = control.formula == BOX_FORMULA ? 2 : 8
        newBusy(.calc2)
    }
    
    //MARK: ==================================

    func finishedRendering() {
        //if busyCode > 0 { Swift.print("Busycode ",busyCode) }
        
        switch busyCode {
        case .smooth :
            for _ in 0 ..< 1 { smooth() }
            calcVertices()
        case .smooth2 :
            for _ in 0 ..< 4 { smooth() }
            calcVertices()
        case .quantize :
            quantize()
            calcVertices()
        case .vertices :
            calcVertices()
        case .calc, .calc2 :
            previousControl = control   // copy of params for current calc
            calcMap()
            calcVertices()
            calcCages()
            if control.hop > 4 { control.hop = 1 }  // finished fast calc
        case .controlLoaded :
            vc.controlLoaded()
        case .idle :
            break
        }
        
        busyCode = .idle
    }
}


