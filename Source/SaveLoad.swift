import UIKit

var saveLoad = SaveLoad()
let NUM_SAVELOAD:Int = 12

class SaveLoad {
    var store = Array(repeating:String(), count:NUM_SAVELOAD)
    let fileName = "Store"
    var DocumentDirURL:URL! = nil
    var fileURL:URL! = nil
    
    init() {
        DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        fileURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("txt")
        
        loadStore()
    }
    
    //MARK: -
    
    func save(_ index:Int) {
//        var s:String = ""
//        for i in 0 ..< NUM_RULE+1 {
//            s.append(q.rule[i].asString())
//            s.append(";")
//        }
//
//        store[index] = s
        saveStore()
    }
    
    func saveStore() {
        var s:String = ""
        for i in 0 ..< NUM_SAVELOAD {
            s.append(store[i])
            s.append("\n")
        }
        
        do {
            try s.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("Failed writing to URL: \(fileURL), Error: " + error.localizedDescription)
        }
    }
    
    //MARK: -
    
    func load(_ index:Int) {
//        let r:[String] = store[index].components(separatedBy:";")
//        for i in 0 ..< NUM_RULE+1 { q.rule[i].initialize(r[i]) }
    }

    func loadStore() {
        for i in 0 ..< NUM_SAVELOAD { store[i] = "" }
        
        do {
            let content = try String(contentsOfFile: fileURL.path)
            store = content.components(separatedBy:"\n")
        } catch {
            print("Failed loading from URL: \(fileURL), Error: " + error.localizedDescription)
        }
    }
}


