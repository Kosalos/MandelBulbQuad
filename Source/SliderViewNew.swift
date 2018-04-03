import UIKit

enum ValueType { case int32,float }
enum SliderType { case delta,direct }

class SliderViewNew: UIView {
    var context : CGContext?
    var scenter:Float = 0
    var swidth:Float = 0
    var ident:Int = 0
    var active = true
    
    var valuePointer:UnsafeMutableRawPointer! = nil
    var valuetype:ValueType = .float
    var slidertype:SliderType = .delta
    var deltaValue:Float = 0
    var name:String = "name"

    var mRange = float2(0,256)
    let percentList:[CGFloat] = [ 0.20,0.22,0.25,0.28,0.32,0.37,0.43,0.48,0.52,0.55,0.57 ]
    let legends:[String] = [ "X","Y","Z","Scale","-R","-I","-M","-Z","+R","+I","+M","+Z","Range","Offset","Spread"]
    
    func address<T>(of: UnsafePointer<T>) -> UInt { return UInt(bitPattern: of) }
    
    func initialize() {
        swidth = Float(bounds.width)
        scenter = swidth / 2
    }

    func initializeInt32(_ v: inout Int32, _ sType:SliderType, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        let valueAddress = address(of:&v)
        valuePointer = UnsafeMutableRawPointer(bitPattern:valueAddress)!
        valuetype = .int32
        slidertype = sType
        mRange.x = min
        mRange.y = max
        deltaValue = delta
        name = iname
        swidth = Float(bounds.width)
        scenter = swidth / 2
    }

    func initializeFloat(_ v: inout Float, _ sType:SliderType, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        let valueAddress = address(of:&v)
        valuePointer = UnsafeMutableRawPointer(bitPattern:valueAddress)!
        valuetype = .float
        slidertype = sType
        mRange.x = min
        mRange.y = max
        deltaValue = delta
        name = iname        
        swidth = Float(bounds.width)
        scenter = swidth / 2
    }

    func setActive(_ v:Bool) {
        active = v
        setNeedsDisplay()
    }
    
    func percentX(_ percent:CGFloat) -> CGFloat { return CGFloat(bounds.size.width) * percent }
    
    //MARK: ==================================

    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()
        
        if !active {
            let G:CGFloat = 0.13        // color Lead
            UIColor(red:G, green:G, blue:G, alpha: 1).set()
            UIBezierPath(rect:bounds).fill()
            return
        }
        
        UIColor(red:0.1, green:0.1, blue:0.1, alpha: 1).set()
        UIBezierPath(rect:bounds).fill()
        
        // edge -------------------------------------------------
        let ctx = context!
        let path = UIBezierPath(rect:bounds)
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
        
        // thumb region for X,Y,Z ---------------------------------------
        if tag >= 0 && tag < 3 {
            var rr = bounds
            rr.origin.x = percentX(percentList[0])
            rr.size.width = percentX(percentList[10]) - rr.origin.x
            
            switch(tag) {
            case 0  : UIColor(red:0.4, green:0.2, blue:0.2, alpha: 1).set();  UIBezierPath(rect:rr).fill()
            case 1  : UIColor(red:0.2, green:0.4, blue:0.2, alpha: 1).set();  UIBezierPath(rect:rr).fill()
            case 2  : UIColor(red:0.2, green:0.2, blue:0.4, alpha: 1).set();  UIBezierPath(rect:rr).fill()
            default : break
            }
            
            UIColor.black.set()
            context?.setLineWidth(2)
            for p in percentList { drawVLine(percentX(p),0,bounds.height) }
        }
        
        // value ------------------------------------------

        func formatted(_ v:Float) -> String { return String(format:"%6.4f",v) }
        func formatted2(_ v:Float) -> String { return String(format:"%7.5f",v) }
        func formatted3(_ v:Float) -> String { return String(format:"%d",Int(v)) }
        func formatted4(_ v:Float) -> String { return String(format:"%5.2f",v) }

        let vx = percentX(0.50)
        
        func valueColor(_ v:Float) -> UIColor {
            var c = UIColor.gray
            if v < 0 { c = UIColor.red } else if v > 0 { c = UIColor.green }
            return c
        }
        
        func coloredValue(_ v:Float) { drawText(vx,8,valueColor(v),16, formatted(v)) }
        
        if valuePointer != nil {
            drawText(10,8,.white,16,name)
            
            switch valuetype {
            case .int32 :
                let v:Int32 = valuePointer.load(as: Int32.self)
                drawText(percentX(0.75),8,.gray,16, v.description)
            case .float :
                let v:Float = valuePointer.load(as: Float.self)
                
                if v > 100 {
                    drawText(vx,8,.gray,16, formatted3(v))
                }
                else {
                    coloredValue(v)
                }
            }
            
            return
        }
        
        // legend -----------------------------------------------
        switch tag {
        case 3 :
            drawText(10,8,.white,16,"Scale")
            drawText(vx,8,.gray,16, formatted2(control.scale))
        case POWER_SLIDER_TAG:
            drawText(10,8,.white,16,"Power")
            drawText(vx,8,.gray,16, formatted4(control.power))
        default: break
        }
    }
    
    func isJuliaSlider() -> Bool { return tag >= 4 && tag <= 11 }
    
    var delta:Float = 0
    var touched = false
    
    //MARK: ==================================
    
    let pRange = float2(2,12)
    
    func update() {
        if !active || !touched { return }
        
        if tag == POWER_SLIDER_TAG {
            if bulb.busyCode == .idle {
                control.power = fClamp(control.power + delta * 10,pRange)
                bulb.newBusy(.calc2)
                setNeedsDisplay()
            }
            return
        }
        
        if valuePointer != nil {
            var value:Float = 0
            
            switch valuetype {
            case .int32 : value = Float(valuePointer.load(as: Int32.self))
            case .float : value = valuePointer.load(as: Float.self)
            }

            value = fClamp(value + delta * deltaValue, mRange)
            
            switch valuetype {
            case .int32 : valuePointer.storeBytes(of:Int32(value), as:Int32.self)
            case .float : valuePointer.storeBytes(of:value, as:Float.self)
            }
        }
        
        if tag == 3 {   // Scale
            let scl = 1.0 + delta / 4
            vc.changeScale(control.scale * scl)
        }
        
        setNeedsDisplay()
        
        if isJuliaSlider() {
            launchFastCalc = true
        }
        else {
            if tag < 12 { paceRotate.reset() }
            
            bulb.calcCages()
            showAxesFlag = true
        }
    }
    
    //MARK: ==================================

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !active { return }
        
        for t in touches {
            let pt = t.location(in: self)
            
            if valuePointer != nil {
                if slidertype == .direct {
                    let value = fClamp(mRange.x + (mRange.y - mRange.x) * Float(pt.x) / swidth, mRange)

                    switch valuetype {
                    case .int32 : valuePointer.storeBytes(of:Int32(value), as:Int32.self)
                    case .float : valuePointer.storeBytes(of:value, as:Float.self)
                    }
                
                    setNeedsDisplay()
                    bulb.newBusy(.vertices)
                    return
                }
            }
            
            delta = (Float(pt.x) - scenter) / swidth / 10
            
            if !touched {
                touched = true
                //Swift.print("Touched ",touches.count)
            }

            setNeedsDisplay()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with:event)
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Swift.print("Ended ",touches.count)
        touched = false
        delta = 0
        
        if isJuliaSlider() {    // julia, box
            control.hop = 1
            bulb.newBusy(.calc2)
        }
        else {
            vc.updateCalcButton(CALC_BUTTON_READY)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Swift.print("Can ",touches.count)
        if touches.count == 1 {
            touchesEnded(touches, with:event)
        }
    }
    
    func drawLine(_ p1:CGPoint, _ p2:CGPoint) {
        context?.beginPath()
        context?.move(to:p1)
        context?.addLine(to:p2)
        context?.strokePath()
    }
    
    func drawVLine(_ x:CGFloat, _ y1:CGFloat, _ y2:CGFloat) { drawLine(CGPoint(x:x,y:y1),CGPoint(x:x,y:y2)) }
    func drawHLine(_ x1:CGFloat, _ x2:CGFloat, _ y:CGFloat) { drawLine(CGPoint(x:x1, y:y),CGPoint(x: x2, y:y)) }
    
    func drawText(_ x:CGFloat, _ y:CGFloat, _ color:UIColor, _ sz:CGFloat, _ str:String) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.left
        
        let font = UIFont.init(name: "Helvetica", size:sz)!
        
        let textFontAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: color,
            NSAttributedStringKey.paragraphStyle: paraStyle,
            ]
        
        str.draw(in: CGRect(x:x, y:y, width:800, height:100), withAttributes: textFontAttributes)
    }
    
    func drawText(_ pt:CGPoint, _ color:UIColor, _ sz:CGFloat, _ str:String) { drawText(pt.x,pt.y,color,sz,str) }
}
