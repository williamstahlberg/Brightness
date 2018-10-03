import Cocoa
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet weak var window: NSWindow!
	@IBOutlet weak var alert: NSWindow!
	
	@IBOutlet weak var text1: NSTextField!
	@IBOutlet weak var display_model: NSTextField!
	@IBOutlet weak var enter_manually: NSButton!
	@IBOutlet weak var display_model_check: NSImageView!
	
	@IBOutlet weak var text2: NSTextField!
	@IBOutlet weak var graphview: GraphView!
	@IBOutlet weak var minimum: NSTextField!
	@IBOutlet weak var curvature: NSTextField!
	@IBOutlet weak var log_y: NSTextField!
	@IBOutlet weak var minimum_check: NSImageView!
	@IBOutlet weak var curvature_check: NSImageView!
	
	@IBOutlet weak var text3: NSTextField!
	@IBOutlet weak var revert_to_original: NSButton!
	@IBOutlet weak var apply_changes: NSButton!
	@IBOutlet weak var warning_label: NSTextField!

	let model = Model()
	var text2_unformatted = ""

	func applicationDidFinishLaunching(aNotification: NSNotification) {
		if model.havePrerequisites() == false {
			window.orderOut(window)
			alert.makeKeyAndOrderFront(alert)
		}
		
		window.makeFirstResponder(nil)
		let italic = NSFontManager.sharedFontManager().convertFont(text1.font!, toHaveTrait: NSFontTraitMask.ItalicFontMask)
		(text1.font, text2.font, text3.font) = (italic, italic, italic)
		enter_manually.state = NSOffState
		model.detectModel()
		display_model.stringValue = model.model
		text2_unformatted = text2.stringValue
		update()
		
	}
	
	@IBAction func quit(sender: AnyObject) {
		NSApplication.sharedApplication().terminate(self)
	}

	@IBAction func revert_to_original(sender: AnyObject) {
		model.revertToOriginal()
		update()
	}

	@IBAction func apply_changes(sender: AnyObject) {
		model.applyChanges()
		update()
	}

	@IBAction func enter_manually(sender: AnyObject) {
		if sender.state == NSOnState {
			display_model.enabled = true
		} else {
			display_model.enabled = false
			model.detectModel()
			display_model.stringValue = model.model
			update()
		}
	}
	
	override func controlTextDidChange(aNotification: NSNotification) {
		let object = aNotification.object!
		if object === display_model {
			model.model = display_model.stringValue
		}
		update()
	}

	func update() {
		model.calculateInfoCurve()
		model.calculateNewCurve(Int(minimum.stringValue) ?? 0, curvature: Float(curvature.stringValue) ?? 0)

		var y_orig_ = [Float](), y_new_ = [Float]()
		if model.y_orig.count > 0 {
			for i in 1..<model.y_orig.count {
				y_orig_.append(model.y_orig[i] != 0 ? log10(Float(model.y_orig[i])) : Float(0))
			}
		}
		if model.y_new.count > 0 {
			for i in 1..<model.y_new.count {
				y_new_.append(model.y_new[i] != 0 ? log10(Float(model.y_new[i])) : Float(0))
			}
		}
		graphview.plot(y_orig_, lineWidth: 2.0, color: NSColor(red: 0.263, green: 0.557, blue: 1.0, alpha: 1.0))
		graphview.plot(y_new_, lineWidth: 2.0)
		graphview.tickX()
		if model.y_new.count > 0 {
			graphview.tickY([(Float(y_new_[1]), String(model.y_new[2]))])
		}
		graphview.forcePadding(top: 5, left: 30)
		graphview.show()
		
		/* Check marks and enable/disable IB elements */
		display_model_check.image = model.modelNotFound ? NSImage(named: "setup-no") : NSImage(named: "setup-check")
		let min_ = Int(minimum.stringValue) ?? 0
		let curv_ = Float(curvature.stringValue) ?? 0
		if model.unsupportedModel || model.modelNotFound {
			(minimum.enabled, curvature.enabled, apply_changes.enabled) = (false, false, false)
			(minimum_check.image, curvature_check.image) = (NSImage(), NSImage())
		} else {
			if model.y_new.count == 0 {
				(minimum.enabled, curvature.enabled, apply_changes.enabled) = (true, true, false)
			} else {
				(minimum.enabled, curvature.enabled, apply_changes.enabled) = (true, true, true)
			}
			if minimum.stringValue != "" {
				minimum_check.image = min_ < 0 || min_ >= model.y_orig.last ? NSImage(named: "setup-no") : NSImage(named: "setup-check")
			} else {
				minimum_check.image = NSImage()
			}
			if curvature.stringValue != "" {
				curvature_check.image = curv_ <= 1.0 || curv_ > 10.0 ? NSImage(named: "setup-no") : NSImage(named: "setup-check")
			} else {
				curvature_check.image = NSImage()
			}
		}

		revert_to_original.enabled = model.haveOriginalPlists() ? false : true
		
		if model.y_orig.count >= 2 {
			let info_min_ = model.yHasZero ? model.y_orig[2] : model.y_orig[1]
			text2.stringValue = text2_unformatted.replace("{}", withString: String(info_min_))
		}
		warning_label.stringValue = model.haveError
		model.haveError = ""
	}
	
}


