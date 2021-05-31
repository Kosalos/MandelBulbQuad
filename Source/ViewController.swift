import UIKit
import MetalKit

let sMin:Float = 0.00001
let sMax:Float = 0.07
let sRange = (sMax - sMin)
let SDELTA:Float   = 0.0002
let SCLDELTA:Float = 0.00002
var sdx:Float = 0
var sdy:Float = 0
var sdz:Float = 0
var sscaledz:Float = 0
var deltaRe:Float = 0
var deltaIm:Float = 0
var deltaMult:Float = 0
var centerDelta:Float = 0
var centerValue:Float = 0
var showAxesFlag = true
var paceRotate = CGPoint()

var histogram = Histogram()
var control = Control()
var undoControl1 = Control()
var undoControl2 = Control()
var launchFastCalc = false

var paceTimer = Timer()
let CALC_BUTTON_IDLE = 0
let CALC_BUTTON_READY = 1
let CALC_BUTTON_BUSY = 2
let POWER_SLIDER_TAG = 99
let JULIA_FORMULA = 5
let BOX_FORMULA = 6

var hv:HistogramView! = nil

var gDevice: MTLDevice!
let bulb = Bulb()
var camera:float3 = float3(0,0,170)
var vc:ViewController! = nil

let threadGroupCount = MTLSizeMake(20,20,1)
let threadGroups: MTLSize = { MTLSizeMake(Int(WIDTH) / threadGroupCount.width, Int(WIDTH) / threadGroupCount.height, Int(WIDTH) / threadGroupCount.depth) }()

// used during development of rotated() layout routine to simulate other iPad sizes
let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait 9.7, 10.5, 12.9" iPads
let scrnIndex = 2
let scrnLandscape:Bool = true

class ViewController: UIViewController {
    @IBOutlet var mtkViewL: MTKView!
    @IBOutlet var mtkViewR: MTKView!
    @IBOutlet var nsvX: SliderViewNew!
    @IBOutlet var nsvY: SliderViewNew!
    @IBOutlet var nsvZ: SliderViewNew!
    @IBOutlet var nsvS: SliderViewNew!
    @IBOutlet var nsvJR: SliderViewNew!
    @IBOutlet var nsvJI: SliderViewNew!
    @IBOutlet var nsvJM: SliderViewNew!
    @IBOutlet var nsvJZ: SliderViewNew!
    @IBOutlet var nsdvJR: SliderViewNew!
    @IBOutlet var nsdvJI: SliderViewNew!
    @IBOutlet var nsdvJM: SliderViewNew!
    @IBOutlet var nsdvJZ: SliderViewNew!
    @IBOutlet var colorSpread: SliderViewNew!
    @IBOutlet var colorRange: SliderViewNew!
    @IBOutlet var colorOffset: SliderViewNew!
    @IBOutlet var histogramView: HistogramView!
    @IBOutlet var powerView: SliderViewNew!
    @IBOutlet var formulaSeg: UISegmentedControl!
    @IBOutlet var cloudCountSeg: UISegmentedControl!
    @IBOutlet var ptSizeSeg: UISegmentedControl!
    @IBOutlet var vCountLegend: UILabel!
    @IBOutlet var calcButton: UIButton!
    @IBOutlet var copyParamsButton: UIButton!
    @IBOutlet var copyParams2Button: UIButton!
    @IBOutlet var cnvergeButtonRe: UIButton!
    @IBOutlet var divergeButtonRe: UIButton!
    @IBOutlet var cnvergeButtonIm: UIButton!
    @IBOutlet var divergeButtonIm: UIButton!
    @IBOutlet var cnvergeButtonMult: UIButton!
    @IBOutlet var divergeButtonMult: UIButton!
    @IBOutlet var centerMinusButton: UIButton!
    @IBOutlet var centerPlusButton: UIButton!
    @IBOutlet var colorButton: UIButton!
    @IBOutlet var undoButton: UIButton!
    @IBOutlet var axisButton: UIButton!
    @IBOutlet var resetButton: UIButton!
    @IBOutlet var qtButton: UIButton!
    @IBOutlet var qt2Button: UIButton!
    @IBOutlet var smButton: UIButton!
    @IBOutlet var sm2Button: UIButton!
    @IBOutlet var slButton: UIButton!
    @IBOutlet var hlpButton: UIButton!
    @IBAction func centerMinusDown(_ sender: Any)   { centerDelta = -0.75; centerValue = Float(control.center) }
    @IBAction func centerPlusDown(_ sender: Any)    { centerDelta = +0.75; centerValue = Float(control.center) }
    @IBAction func centerMinusUp(_ sender: Any)     { centerDelta = 0 }
    @IBAction func centerPlusUp(_ sender: Any)      { centerDelta = 0 }
    
    @IBAction func colorButtonPressed(_ sender: Any) {
        bulb.loadNextColorMap()
        bulb.newBusy(.vertices)
    }
  
    func convergeDivergeEnded() {
        deltaRe = 0
        deltaIm = 0
        deltaMult = 0
        control.hop = 1
        bulb.newBusy(.calc)
    }
    
    let dAmount:Float = 0.05
    @IBAction func cnvergeButtonRePressed(_ sender: Any) { deltaRe = +dAmount }
    @IBAction func divergeButtonRePressed(_ sender: Any) { deltaRe = -dAmount }
    @IBAction func cnvergeButtonReRleased(_ sender: Any) { convergeDivergeEnded() }
    @IBAction func divergeButtonReRleased(_ sender: Any) { convergeDivergeEnded() }
    
    @IBAction func cnvergeButtonImPressed(_ sender: Any) { deltaIm = +dAmount }
    @IBAction func divergeButtonImPressed(_ sender: Any) { deltaIm = -dAmount }
    @IBAction func cnvergeButtonImRleased(_ sender: Any) { convergeDivergeEnded() }
    @IBAction func divergeButtonImRleased(_ sender: Any) { convergeDivergeEnded() }
    
    @IBAction func cnvergeButtonMultPressed(_ sender: Any) { deltaMult = +dAmount }
    @IBAction func divergeButtonMultPressed(_ sender: Any) { deltaMult = -dAmount }
    @IBAction func cnvergeButtonMultRleased(_ sender: Any) { convergeDivergeEnded() }
    @IBAction func divergeButtonMultRleased(_ sender: Any) { convergeDivergeEnded() }
    
    @IBAction func quantizeButtonPressed(_ sender: UIButton)  { bulb.quantizeData() }
    @IBAction func quantize2ButtonPressed(_ sender: UIButton)  { bulb.quantizeData2() }
    @IBAction func smoothingButtonPressed(_ sender: UIButton) { bulb.smoothData() }
    @IBAction func smoothing2ButtonPressed(_ sender: UIButton) { bulb.smoothData2() }

    var rotateTimer = Timer()
    var rendererL: Renderer!
    var rendererR: Renderer!

    override var prefersStatusBarHidden: Bool { return true }

    var sList:[SliderViewNew] = []

    //MARK:-

    override func viewDidLoad() {
        super.viewDidLoad()
        gDevice = MTLCreateSystemDefaultDevice()
        mtkViewL.device = gDevice
        mtkViewR.device = gDevice
        
        guard let newRenderer = Renderer(metalKitView: mtkViewL, 0) else { fatalError("Renderer cannot be initialized") }
        rendererL = newRenderer
        rendererL.mtkView(mtkViewL, drawableSizeWillChange: mtkViewL.drawableSize)
        mtkViewL.delegate = rendererL

        guard let newRenderer2 = Renderer(metalKitView: mtkViewR, 1) else { fatalError("Renderer cannot be initialized") }
        rendererR = newRenderer2
        rendererR.mtkView(mtkViewR, drawableSizeWillChange: mtkViewR.drawableSize)
        mtkViewR.delegate = rendererR

        hv = histogramView
        updateCalcButton(CALC_BUTTON_READY)
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        rotated()

        paceTimer = Timer.scheduledTimer(timeInterval:0.01, target:self, selector: #selector(paceTimerHandler), userInfo: nil, repeats:true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vc = self
        
        sList.append(nsvX)
        sList.append(nsvY)
        sList.append(nsvZ)
        sList.append(nsvS)
        sList.append(nsvJR)
        sList.append(nsvJI)
        sList.append(nsvJM)
        sList.append(nsvJZ)
        sList.append(nsdvJR)
        sList.append(nsdvJI)
        sList.append(nsdvJM)
        sList.append(nsdvJZ)
        sList.append(colorRange)
        sList.append(colorOffset)
        sList.append(colorSpread)
        sList.append(powerView)
        for s in sList {
            s.initialize()
            s.setNeedsDisplay()
        }
        
        control.basex = 0
        control.basey = 0
        control.basez = 0
        control.scale = 0.01
        control.power = 8
        control.re1 = 1
        control.im1 = 1
        control.mult1 = 1.9
        control.zoom1 = 740
        control.re2 = 0
        control.im2 = 0
        control.mult2 = 0
        control.zoom2 = 0
        
        control.formula = 0
        control.hop = 1
        control.center = 5
        control.spread = 2
        control.offset = 64
        control.range = 128
        control.cloudIndex = 0
        
        colorRange.initializeInt32(&control.range, .direct, 0,256,0, "Color Range")
        colorOffset.initializeInt32(&control.offset, .direct, 0,256,0, "Color Offset")
        colorSpread.initializeInt32(&control.spread, .direct, 0,10,0, "Spread")
        nsvX.initializeFloat(&control.basex, .delta, -5,5,0.5, "X")
        nsvY.initializeFloat(&control.basey, .delta, -5,5,0.5, "Y")
        nsvZ.initializeFloat(&control.basez, .delta, -5,5,0.5, "Z")
        
        controlLoaded()
        bulb.newBusy(.calc)
    }
    
    //MARK: -
    
    var oldXS:CGFloat = 0
    
    @objc func rotated() {
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height
//        let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
//        let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y

        let gap:CGFloat = 5
        let fullWidth:CGFloat = 760
        let fullHeight:CGFloat = 320

        if xs == oldXS { return }
        oldXS = xs
        
        let left:CGFloat = (xs - fullWidth)/2
        var ixs = (xs - 4) / 2
        if ixs + fullHeight > ys { ixs = ys - fullHeight - 5 }
        mtkViewL.frame = CGRect(x:xs/2 - ixs - 2, y:0, width:ixs, height:ixs)
        mtkViewR.frame = CGRect(x:xs/2 + 2, y:0, width:ixs, height:ixs)
        
        let by:CGFloat = ixs + 5     // button row1
        let bys:CGFloat = 35
        var y:CGFloat = by
        var x:CGFloat = left
        histogramView.frame =       CGRect(x:x, y:y, width:240, height:bys); x += 240 + gap
        centerMinusButton.frame =   CGRect(x:x, y:y, width:45, height:bys); x += 50 + gap
        centerPlusButton.frame =    CGRect(x:x, y:y, width:45, height:bys)
        
        y = by
        x += 160
        colorSpread.frame =     CGRect(x:x, y:y, width:140, height:bys); x += 140 + gap
        colorRange.frame =      CGRect(x:x, y:y, width:140, height:bys); y += bys + gap
        colorOffset.frame =     CGRect(x:x, y:y, width:140, height:bys)
        
        x = left  // button row2
        y = by + bys + 10
        formulaSeg.frame =      CGRect(x:x, y:y, width:280, height:bys); x += 280 + 30
        vCountLegend.frame =    CGRect(x:x, y:y, width:130, height:bys)
        
        x = left  // button row3
        y += bys + 10
        powerView.frame =       CGRect(x:x, y:y, width:280, height:bys); x += 280 + gap * 3
        cloudCountSeg.frame =   CGRect(x:x, y:y, width:100, height:bys); x += 100 + gap * 3
        colorButton.frame =     CGRect(x:x, y:y, width:45, height:bys); x += 50 + gap * 3
        ptSizeSeg.frame =       CGRect(x:x, y:y, width:140, height:bys)
        
        x = left  // undo,axis,reset
        y += bys + 10
        let y2 = y
        undoButton.frame =  CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        axisButton.frame =  CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        resetButton.frame = CGRect(x:x, y:y, width:45, height:bys)
        
        x += 60 // x,y,z,s
        y = y2
        let cxs:CGFloat = 130
        nsvX.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvY.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvZ.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvS.frame = CGRect(x:x, y:y, width:cxs, height:bys)
        
        x += cxs + gap // r,i,m,z
        y = y2
        nsvJR.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvJI.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvJM.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsvJZ.frame = CGRect(x:x, y:y, width:cxs, height:bys)
        
        x += cxs + gap // r2,i2,m2,z2
        y = y2
        nsdvJR.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsdvJI.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsdvJM.frame = CGRect(x:x, y:y, width:cxs, height:bys); y += bys + 10
        nsdvJZ.frame = CGRect(x:x, y:y, width:cxs, height:bys)
        
        x += cxs + gap // converge
        y = y2
        cnvergeButtonRe.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        cnvergeButtonIm.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        cnvergeButtonMult.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        copyParamsButton.frame = CGRect(x:x, y:y, width:45, height:bys)
        
        x += 50 + gap // diverge
        y = y2
        divergeButtonRe.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        divergeButtonIm.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        let y3 = y
        divergeButtonMult.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        copyParams2Button.frame = CGRect(x:x, y:y, width:45, height:bys)
        
        x += 50 + gap // qt
        y = y3
        qtButton.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        qt2Button.frame = CGRect(x:x, y:y, width:45, height:bys)
        x += 50 + 20
        let x2 = x
        y = y3
        smButton.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        sm2Button.frame = CGRect(x:x, y:y, width:45, height:bys)
        x += 50 + gap
        y = y3
        slButton.frame = CGRect(x:x, y:y, width:45, height:bys); y += bys + 10
        hlpButton.frame = CGRect(x:x, y:y, width:45, height:bys)
        
        calcButton.frame = CGRect(x:x2, y:y2, width:90, height:35)
    }
    
    //MARK:-

    func rotate(_ pt:CGPoint) {
        let center:CGFloat = 300    // 0.5 x nib image size
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center + pt.x, y: center + pt.y))
    }

    @objc func paceTimerHandler() {
        rotate(paceRotate)
        
        if sscaledz != 0 { changeScale(control.scale * sscaledz) }
        
        // > 0 = converge,  < 0 = diverge
        
        if deltaRe != 0 {
            let diff = (control.re2 - control.re1) * dAmount
            control.re1 += diff
            control.re2 -= diff
            sList[4].setNeedsDisplay()
            sList[8].setNeedsDisplay()
            launchFastCalc = true
        }
        
        if deltaIm != 0 {
            let diff = (control.im2 - control.im1) * dAmount
            control.im1 += diff
            control.im2 -= diff
            sList[5].setNeedsDisplay()
            sList[9].setNeedsDisplay()
            launchFastCalc = true
        }
        
        if deltaMult != 0 {
            let diff = (control.mult2 - control.mult1) * dAmount
            control.mult1 += diff
            control.mult2 -= diff
            sList[6].setNeedsDisplay()
            sList[10].setNeedsDisplay()
            launchFastCalc = true
        }
        
        if centerDelta != 0 {
            centerValue += centerDelta
            if centerValue < 1 { centerValue = 1 } else if centerValue > 255 { centerValue = 255 }
            control.center = Int32(centerValue)
            bulb.newBusy(.vertices)
        }
        
        for s in sList { s.update() }
        
        if launchFastCalc {
            launchFastCalc = false
            bulb.fastCalc()
        }
    }
    
    //MARK:-

    func controlLoaded() {
        updateCalcButton(CALC_BUTTON_READY)
        
        for i in 4 ... 11 { sList[i].setActive(false) }  // re,im,mult 1 & 2
        
        switch Int(control.formula) {
        case JULIA_FORMULA :
            for i in 4 ... 11 { sList[i].setActive(true) } // re,im,mult 1 & 2
        case BOX_FORMULA :
            for i in 4 ... 9 { sList[i].setActive(true) } // fold 2, radius 2, scale, cutoff
        default : break
        }
        
        sList[12].slidertype = .direct  // color sliders
        sList[13].slidertype = .direct
        sList[14].slidertype = .direct
        sList[12].setActive(true)
        sList[13].setActive(true)
        sList[14].setActive(true)
        
        powerView.isHidden = control.formula == JULIA_FORMULA || control.formula == BOX_FORMULA
        
        let fJulia = control.formula != JULIA_FORMULA
        copyParamsButton.isHidden = fJulia
        copyParams2Button.isHidden = fJulia
        cnvergeButtonRe.isHidden = fJulia
        divergeButtonRe.isHidden = fJulia
        cnvergeButtonIm.isHidden = fJulia
        divergeButtonIm.isHidden = fJulia
        cnvergeButtonMult.isHidden = fJulia
        divergeButtonMult.isHidden = fJulia
        
        formulaSeg.selectedSegmentIndex = Int(control.formula)
        
        if control.formula == JULIA_FORMULA {
            nsvJR.initializeFloat(&control.re1,     .delta, -3,3,   0.25,   "-R")
            nsvJI.initializeFloat(&control.im1,     .delta, -3,3,   0.25,   "-I")
            nsvJM.initializeFloat(&control.mult1,   .delta, -3,3,   0.25,   "-M")
            nsvJZ.initializeFloat(&control.zoom1,   .delta, 0,5000, 1500,   "-Z")
            
            nsdvJR.initializeFloat(&control.re2,    .delta, -3,3,   0.25,   "+R")
            nsdvJI.initializeFloat(&control.im2,    .delta, -3,3,   0.25,   "+I")
            nsdvJM.initializeFloat(&control.mult2,  .delta, -3,3,   0.25,   "+M")
            nsdvJZ.initializeFloat(&control.zoom2,  .delta, 0,5000, 1500,   "+Z")
        }
        else {  // box
            nsvJR.initializeFloat(&control.re1,     .delta, 0.1,3,  0.3,    "F Lim")
            nsvJI.initializeFloat(&control.im1,     .delta, 0.1,4,  0.3,    "F Val")
            nsvJM.initializeFloat(&control.mult1,   .delta, 0.1,3,  0.3,    "M Rad")
            nsvJZ.initializeFloat(&control.zoom1,   .delta, 0.1,3,  0.3,    "F Rad")
            nsdvJR.initializeFloat(&control.re2,    .delta, 0.1,3,   1,     "Scale")
            nsdvJI.initializeFloat(&control.im2,    .delta, 0.1,10,  1,     "Cutoff")
        }
        
        for s in sList { s.setNeedsDisplay() }
    }
    
    //MARK:-

    @IBAction func formulaChanged(_ sender: UISegmentedControl) {
        control.formula = Int32(sender.selectedSegmentIndex)
        controlLoaded()
    }
    
    @IBAction func cloudCountChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0 : cloudCount = 1
        case 1 : cloudCount = 2
        case 2 : cloudCount = 4
        default : break
        }
        
        bulb.newBusy(.calc)
    }
    
    //MARK:-

    @IBAction func ptSizeChanged(_ sender: UISegmentedControl) { // 1,2,4,8
        let pList:[Float] = [ 1,2,4,8 ]
        pointSize = pList[sender.selectedSegmentIndex]
    }
    
    @IBAction func copyParamsPressed(_ sender: UIButton) {
        control.re2 = control.re1
        control.im2 = control.im1
        control.mult2 = control.mult1
        control.zoom2 = control.zoom1
        for s in 0 ..< sList.count { sList[s].setNeedsDisplay() }
    }
    
    @IBAction func copyParams2Pressed(_ sender: UIButton) {
        control.re1 = control.re2
        control.im1 = control.im2
        control.mult1 = control.mult2
        control.zoom1 = control.zoom2
        for s in 0 ..< sList.count { sList[s].setNeedsDisplay() }
    }
    
    @IBAction func showAxesPressed(_ sender: UIButton) { showAxesFlag = !showAxesFlag }
    @IBAction func calcPressed(_ sender: UIButton) { updateCalcButton(CALC_BUTTON_BUSY) }
    
    @IBAction func undoPressed(_ sender: UIButton) {
        control = undoControl2
        for s in sList { s.setNeedsDisplay() }
        updateCalcButton(CALC_BUTTON_READY)
    }
    
    @IBAction func resetButton(_ sender: Any) {
        bulb.reset();
        undoControl1 = control
        undoControl2 = control
        updateCalcButton(CALC_BUTTON_READY)
        camera = float3(0,0,170)
        for s in sList { s.setNeedsDisplay() }
    }
    
    func changeScale(_ ns:Float) {
        let cc = Float(WIDTH)/2
        let q1 = control.scale * cc
        
        var centerx = control.basex
        var centery = control.basey
        var centerz = control.basez
        centerx += q1
        centery += q1
        centerz += q1
        
        control.scale = ns
        if control.scale < sMin { control.scale = sMin } else if control.scale > sMax { control.scale = sMax }
        
        let q2 = control.scale * cc
        control.basex = centerx - q2
        control.basey = centery - q2
        control.basez = centerz - q2
        
        sList[0].setNeedsDisplay()
        sList[1].setNeedsDisplay()
        sList[2].setNeedsDisplay()
        sList[3].setNeedsDisplay()
    }

    var oldStatus:Int = CALC_BUTTON_READY
    
    func updateCalcButton(_ status:Int) {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        vCountLegend.text = "#Pts: " + numberFormatter.string(from: NSNumber(value:vCount))!
        
        if status == oldStatus { return }
        
        bulb.calcCages()
        
        oldStatus = status
        
        switch status {
        case CALC_BUTTON_IDLE :
            calcButton.backgroundColor = UIColor.gray
            calcButton.setTitle("Ready", for: [])
        case CALC_BUTTON_READY :
            calcButton.backgroundColor = UIColor(red:0.3, green:0.3, blue:0.6, alpha: 1)
            calcButton.setTitle("Calc", for: [])
        case CALC_BUTTON_BUSY :
            undoControl2 = undoControl1
            undoControl1 = control
            bulb.newBusy(.calc)
        default : break
        }
    }

    //MARK:-

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
    
    //MARK:-

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

func iClamp(_ v:inout Int32, _ min:Int32,_ max:Int32) {
    if v < min { v = min } else if v > max { v = max }
}

func fClamp(_ v:Float, _ range:float2) -> Float {
    if v < range.x { return range.x }
    if v > range.y { return range.y }
    return v
}


