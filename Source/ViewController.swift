import UIKit
import MetalKit

var gDevice: MTLDevice!
let bulb = Bulb()
let threadGroupCount = MTLSizeMake(16,16,1)
let threadGroups: MTLSize = { MTLSizeMake(Int(WIDTH) / threadGroupCount.width, Int(WIDTH) / threadGroupCount.height, Int(WIDTH) / threadGroupCount.depth) }()

var camera:float3 = float3(0,0,170)

var vc:ViewController! = nil

class ViewController: UIViewController {
    var rotateTimer = Timer()
    var renderer: Renderer!
    
    @IBOutlet var mtkView: MTKView!

    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: ==================================

    override func viewDidLoad() {
        super.viewDidLoad()
        mtkView.device =  MTLCreateSystemDefaultDevice()
        gDevice = mtkView.device
        
        guard let newRenderer = Renderer(metalKitView: mtkView) else { fatalError("Renderer cannot be initialized") }
        renderer = newRenderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
        
        rotateTimer = Timer.scheduledTimer(timeInterval:0.01, target:self, selector: #selector(rotateTimerHandler), userInfo: nil, repeats:true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vc = self
        bulb.newBusy(.calc)
    }
    
    //MARK: ==================================

    func rotate(_ pt:CGPoint) {
        arcBall.mouseDown(CGPoint(x: 500, y: 500))
        arcBall.mouseMove(CGPoint(x: 500 + pt.x, y: 500 + pt.y))
    }

    @objc func rotateTimerHandler() { rotate(paceRotate) }
    
    //MARK: ==================================

    let xRange = float2(-100,100)
    let yRange = float2(-100,100)
    let zRange = float2(50,2000)
    let rRange = float2(-3,3)
    
    func parseRotation(_ pt:CGPoint) {
        let scale:Float = 0.05
        paceRotate.x = CGFloat(fClamp(Float(pt.x) * scale, rRange))
        paceRotate.y = CGFloat(fClamp(Float(pt.y) * scale, rRange))
    }

    func parseTranslation(_ pt:CGPoint) {
        let den = 30 * control.scale / 0.008
        camera.x = fClamp(camera.x + Float(pt.x) / den, xRange)
        camera.y = fClamp(camera.y - Float(pt.y) / den, xRange)
    }

    func parseZoom(_ scale:Float) {
        camera.z = fClamp(camera.z * scale,zRange)
    }
    
    var numberPanTouches:Int = 0
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let count = sender.numberOfTouches
        if count == 0 { numberPanTouches = 0 }  else if count > numberPanTouches { numberPanTouches = count }
        
        switch sender.numberOfTouches {
        case 1 : if numberPanTouches < 2 { parseRotation(pt) } // prevent rotation after releasing translation
        case 2 : parseTranslation(pt)
        case 3 : parseZoom(Float(1) + Float(pt.y) / 200)
        default : break
        }
    }
    
    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) { parseZoom(Float(1 + (1-sender.scale) / 10 )) }
    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) { paceRotate.reset() }
}

func fClamp(_ v:Float, _ range:float2) -> Float {
    if v < range.x { return range.x }
    if v > range.y { return range.y }
    return v
}


