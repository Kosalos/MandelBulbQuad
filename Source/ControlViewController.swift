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
var cvc:ControlViewController! = nil

class ControlViewController: UIViewController {
    var sList:[SliderViewNew] = []

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
    @IBOutlet var colorRange: SliderViewNew!
    @IBOutlet var colorOffset: SliderViewNew!
    @IBOutlet var colorSpread: SliderViewNew!
    @IBOutlet var histogramView: HistogramView!
    @IBOutlet var powerView: SliderViewNew!

    @IBOutlet var formulaSeg: UISegmentedControl!
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
    
    @IBAction func centerMinusDown(_ sender: Any)   { centerDelta = -0.75; centerValue = Float(control.center) }
    @IBAction func centerPlusDown(_ sender: Any)    { centerDelta = +0.75; centerValue = Float(control.center) }
    @IBAction func centerMinusUp(_ sender: Any)     { centerDelta = 0 }
    @IBAction func centerPlusUp(_ sender: Any)      { centerDelta = 0 }
    
    @IBAction func hideButtonPressed(_ sender: Any) { self.dismiss(animated: false, completion:nil) }
    
    @IBAction func colorButtonPressed(_ sender: Any) {
        bulb.loadNextColorMap()
        bulb.newBusy(.vertices)
    }

    //MARK: ==================================

    override func viewDidLoad() {
        super.viewDidLoad()
        hv = histogramView
        updateCalcButton(CALC_BUTTON_READY)
        paceTimer = Timer.scheduledTimer(timeInterval:0.01, target:self, selector: #selector(paceTimerHandler), userInfo: nil, repeats:true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cvc = self
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

        colorRange.initializeInt32(&control.range, .direct, 0,256,0, "Color Range")
        colorOffset.initializeInt32(&control.offset, .direct, 0,256,0, "Color Offset")
        colorSpread.initializeInt32(&control.spread, .direct, 0,10,0, "Spread")
        nsvX.initializeFloat(&control.basex, .delta, -5,5,0.5, "X")
        nsvY.initializeFloat(&control.basey, .delta, -5,5,0.5, "Y")
        nsvZ.initializeFloat(&control.basez, .delta, -5,5,0.5, "Z")

        controlLoaded()
        bulb.newBusy(.calc)
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

    //MARK: ==================================

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
    
    //MARK: ==================================

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
    
    //MARK: ==================================

    let depthList:[Int32] = [ 8,9,10,15,20,50 ]

    func depthIndex(_ v:Int32) -> Int {
        for i in 0 ..< depthList.count {
            if depthList[i] == v { return i }
        }

        return 0
    }

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

    //MARK: ==================================

    @objc func paceTimerHandler() {
        if sscaledz != 0 { changeScale(control.scale * sscaledz) }

        if deltaRe != 0 {
            control.re1 -= deltaRe
            control.re2 += deltaRe
            sList[4].setNeedsDisplay()
            sList[8].setNeedsDisplay()
            launchFastCalc = true
        }

        if deltaIm != 0 {
            control.im1 -= deltaIm
            control.im2 += deltaIm
            sList[5].setNeedsDisplay()
            sList[9].setNeedsDisplay()
            launchFastCalc = true
        }

        if deltaMult != 0 {
            control.mult1 -= deltaMult
            control.mult2 += deltaMult
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
}

func iClamp(_ v:inout Int32, _ min:Int32,_ max:Int32) {
    if v < min { v = min } else if v > max { v = max }
}


