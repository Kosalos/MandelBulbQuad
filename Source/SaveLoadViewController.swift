import UIKit

protocol SLCellDelegate: class {
    func didTapButton(_ sender: UIButton)
}

class SaveLoadCell: UITableViewCell {
    weak var delegate: SLCellDelegate?
    @IBOutlet var loadCell: UIButton!
    @IBAction func buttonTapped(_ sender: UIButton) {  delegate?.didTapButton(sender) }
}

let bColors:[UIColor] = [
    UIColor(red:0.1, green:0.1, blue:0.3, alpha:1),
    UIColor(red:0.2, green:0.4, blue:0.3, alpha:1),
    UIColor(red:0.3, green:0.3, blue:0.2, alpha:1),
    UIColor(red:0.4, green:0.2, blue:0.1, alpha:1),
    UIColor(red:0.5, green:0.1, blue:0.0, alpha:1),
    UIColor(red:0.8, green:0.4, blue:0.1, alpha:1),     // julia
    UIColor(red:0.3, green:0.6, blue:0.2, alpha:1)      // box
]

class SaveLoadViewController: UIViewController,UITableViewDataSource, UITableViewDelegate,SLCellDelegate {
    @IBOutlet var tableView: UITableView!
    
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return 30 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SLCell", for: indexPath) as! SaveLoadCell
        cell.delegate = self
        cell.tag = indexPath.row
        
        var cc = Control()
        let dateString = loadData(indexPath.row,&cc)
        var str:String = ""
        
        if dateString == "**" {
            str = "** unused **"
        }
        else {
            switch Int(cc.formula) {
            case JULIA_FORMULA : str = String(format:"Julia %@",dateString)
            case BOX_FORMULA :   str = String(format:"Box %@",dateString)
            default :            str = String(format:"Bulb %d, %@", cc.formula + 1,dateString)
            }
        }
        
        cell.loadCell.setTitle(str, for: UIControlState.normal)
        cell.loadCell.backgroundColor = bColors[Int(cc.formula)]
        
        return cell
    }

    func didTapButton(_ sender: UIButton) {
        func getCurrentCellIndexPath(_ sender: UIButton) -> IndexPath? {
            let buttonPosition = sender.convert(CGPoint.zero, to: tableView)
            if let indexPath: IndexPath = tableView.indexPathForRow(at: buttonPosition) {
                return indexPath
            }
            return nil
        }

        if let indexPath = getCurrentCellIndexPath(sender) {
            //Swift.print("Row ",indexPath.row, "        Tag ", sender.tag)
            
            if sender.tag == 0 { loadAndDismissDialog(indexPath.row,&control) }
            if sender.tag == 1 { saveAndDismissDialog(indexPath.row,control) }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
    }

    // ==============================================================
    
    var fileURL:URL! = nil
    let sz = MemoryLayout<Control>.size
    
    func determineURL(_ index:Int) {
        let name = String(format:"Store%d.dat",index)
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
    }
    
    func saveAndDismissDialog(_ index:Int, _ ctrl:Control) {
        
        let alertController = UIAlertController(title: "Save Settings", message: "Confirm overwrite of Settings storage", preferredStyle: .alert)

        let OKAction = UIAlertAction(title: "Continue", style: .default) { (action:UIAlertAction!) in
            do {
                self.determineURL(index)
                var c = ctrl
                let data = NSData(bytes:&c, length:self.sz)
                
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                print(error)
            }
            
            self.dismiss(animated: false, completion:nil)
            // self.dismiss(animated: false, completion: {()->Void in cvc.dismiss(animated: false, completion: nil) });
        }
        alertController.addAction(OKAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
            return
        }
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion:nil)
    }

    var dateString = String("")
    
    @discardableResult func loadData(_ index:Int, _ c: inout Control) -> String {
        var dStr = String("**")
        
        determineURL(index)
        
        do {
            let key:Set<URLResourceKey> = [.creationDateKey]
            let value = try fileURL.resourceValues(forKeys: key)
            if let date = value.creationDate { dStr = date.toString() }
        } catch {
            // print(error)
        }

        let data = NSData(contentsOf: fileURL)
        data?.getBytes(&c, length:sz)
        
        return dStr
    }
    
    func loadAndDismissDialog(_ index:Int, _ cc: inout Control) {
        loadData(index,&cc)
        self.dismiss(animated: false, completion:nil)
        bulb.newBusy(.controlLoaded)
    }
}

extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy hh:mm"
        return dateFormatter.string(from: self)
    }
}

