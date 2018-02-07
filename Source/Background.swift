import UIKit

class Background: UIView {
    override func draw(_ rect: CGRect) {
        UIColor(red:0.135, green:0.13, blue:0.13, alpha: 1).setFill()
        UIBezierPath(rect:rect).fill()
        
//        // development of layout for different size iPads
//        let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
//        let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y
//        UIBezierPath(rect:CGRect(x:0, y:0, width:xs, height:ys)).fill()
    }
}
