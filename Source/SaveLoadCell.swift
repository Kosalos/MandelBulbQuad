import UIKit

protocol YourCellDelegate: class {
    func didTapButton(_ sender: UIButton)
}

class SaveLoadCell: UITableViewCell {

    weak var delegate: YourCellDelegate?
    
    @IBOutlet var loadCell: UIButton!
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        delegate?.didTapButton(sender)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }

}
