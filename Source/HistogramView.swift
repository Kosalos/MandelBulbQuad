import UIKit

class HistogramView: UIView {
    let maxX:Int = 50
    var xScale:CGFloat = 0
    
    var context : CGContext?
    var highest:Int32 = 0

    func percentX(_ percent:CGFloat) -> CGFloat { return CGFloat(bounds.size.width) * percent }
    
    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()
        
        if xScale == 0 { xScale = bounds.size.width / CGFloat(maxX) }
        
        UIColor(red:0.2, green:0.2, blue:0.2, alpha: 1).set()
        UIBezierPath(rect:bounds).fill()
        
        if hBuffer == nil { return }
        let hPtr = hBuffer.contents().bindMemory(to: Int32.self, capacity:HBUFFERSIZE)

        // highest value ----------------------------------------
        highest = 1
        for i in 0 ..< maxX { if hPtr[i] > highest { highest = hPtr[i] }}
        let ratio = bounds.size.height / CGFloat(highest)
        
        // data -------------------------------------------------
        let y2 = bounds.size.height-1
        
        UIColor.gray.set()
        context?.setLineWidth(xScale)
        for i in 0 ..< maxX {
            let fi = CGFloat(i) * xScale
            let ht = CGFloat(hPtr[i]) * ratio
            drawLine(CGPoint(x:fi, y:y2-ht),CGPoint(x:fi, y:y2))
        }
        
        // cursors ----------------------------------------------
        let ccenter = Int(Float(control.center) * Float(xScale))
        let spread = 1 + Int(Float(control.spread) * Float(xScale))
        let low = CGFloat(ccenter - spread)
        let hgh = CGFloat(ccenter + spread)
        let cnt = CGFloat(ccenter)
        UIColor.white.set()
        context?.setLineWidth(2)
        drawLine(CGPoint(x:low, y:0),CGPoint(x:low, y:y2))
        drawLine(CGPoint(x:hgh, y:0),CGPoint(x:hgh, y:y2))
        drawLine(CGPoint(x:cnt, y:0),CGPoint(x:cnt, y:y2))

        // edge -------------------------------------------------
        let ctx = context!
        let path = UIBezierPath(rect:bounds)
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
   }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        bulb.newBusy(.vertices)
        
        for t in touches {
            let pt = t.location(in: self)

            control.center = Int32(pt.x / xScale)
            if control.center < 0 { control.center = 0 } else if control.center > Int32(maxX) { control.center = Int32(maxX) }
            setNeedsDisplay()

            //Swift.print("Touched ",pt.x,pt.y,"  cc = ", control.center.description, "  spread =", control.spread.description)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { touchesBegan(touches, with:event) }
    
    func drawLine(_ p1:CGPoint, _ p2:CGPoint) {
        context?.beginPath()
        context?.move(to:p1)
        context?.addLine(to:p2)
        context?.strokePath()
    }
}
