import Cocoa

class Model {
	let info_paths = [
		"/System/Library/Extensions/AppleGraphicsControl.kext/Contents/PlugIns/AppleMuxControl.kext/Contents/Info.plist",
		"/System/Library/Extensions/AppleBacklight.kext/Contents/Info.plist"
	]
	var info_i: Int?
	var info = [String]()
	var model = ""
	var haveError = ""

	var yHasZero = true
	var unsupportedModel = false
	var modelNotFound = false
	var y_orig = [Int]()
	var y_new = [Int]()

	var applicationSupport: String
	
	init() {
		let applicationSupport_ = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory , .UserDomainMask, true)[0]
		let appName_ = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as! String
		applicationSupport = applicationSupport_+"/"+appName_
	}
	
	func detectModel() {
		let ioreg = shell("/usr/sbin/ioreg", arguments: ["-l"])
		model = ioreg.regexMatches("\"ApplePanel\" = \\{\"([^\"]+)\"")[0]
	}

	func calculateInfoCurve() {
		if info.count == 0 {
			do {
				info.append(try String(contentsOfFile: info_paths[0], encoding: NSUTF8StringEncoding))
				info.append(try String(contentsOfFile: info_paths[1], encoding: NSUTF8StringEncoding))
			} catch {
				haveError = "Unable to open Info.plist file"
				y_orig = []
				return
			}
		}
		info_i = info[0].containsString(model) ? 0 : 1
		
		var data_list = info[info_i!].regexMatches(model+"</key>\n\\s+<data>\n\t\t\t\t([\n\ta-zA-z0-9\\+/=]+)\n\t\t\t\t</data>")
		if data_list.count == 0 {
			modelNotFound = true
			return
		} else {
			modelNotFound = false
		}
		var data = data_list[0]
		data = data.componentsSeparatedByString("\n\t\t\t\t").joinWithSeparator("")
		let decoded = NSData(base64EncodedString: data, options: NSDataBase64DecodingOptions.IgnoreUnknownCharacters)!
		
		var y = [Int]()
		for i in 0..<decoded.length/2 {
			var num: UInt16 = 0
			decoded.getBytes(&num, range: NSRange(location: 2*i, length: 2))
			y.append(Int(CFSwapInt16BigToHost(num)))
		}
		
		if y.count < 5 {
			unsupportedModel = true
			haveError = "Display model is not supported"
		} else {
			unsupportedModel = false
		}
		
		yHasZero = y[1] == 0 ? true : false
		y_orig = y
	}
	
	func calculateNewCurve(minimum: Int, curvature: Float) {
		if y_orig.count == 0 || curvature <= 1.0 || curvature > 10.0 || minimum < 0 || minimum >= y_orig.last {
			y_new = []
			return
		}
		let x0 = yHasZero ? 2 : 1
		let y_ = y_orig[x0..<y_orig.count]
		let x1 = y_.count-1
		let y0 = 0
		let y1 = y_.last! - minimum
		let B = curvature
		let A = Float(y1-y0)/(pow(B,Float(x1))-1)
		let C = Float(y0)-A
		let x = 0...x1
		var y = yHasZero ? [y_orig[0], y_orig[1]] : [y_orig[0]]
		for x_ in x {
			y.append(Int(round(C + A*pow(B,Float(x_))) + Float(minimum)))
		}
		
		y_new = y
	}

	func backUpInfoPlists() {
		let fm = NSFileManager.defaultManager()
		for i in [0, 1] {
			if fm.fileExistsAtPath("\(applicationSupport)/\(i)/Info.plist") == false {
				do {
					try fm.createDirectoryAtPath("\(applicationSupport)/\(i)", withIntermediateDirectories: true, attributes: nil)
					try fm.copyItemAtPath(info_paths[i], toPath: "\(applicationSupport)/\(i)/Info.plist")
				} catch {}
			}
		}
	}

	func applyChanges() {
		backUpInfoPlists()
		
		/* Convert to u16 list -> convert to NSData bytes -> encode to base64 */
		var y_u16 = [UInt16]()
		for y_ in y_new {
			y_u16.append(CFSwapInt16(UInt16(y_)))
		}
		let y_bytes = NSData(bytes: y_u16, length: y_u16.count*sizeof(UInt16))
		let data = y_bytes.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
		let data_formatted = data.characters.count <= 31 ? data : data[0...31] + "\n\t\t\t\t" + data[32..<data.characters.count]
		
		let old = info[info_i!].regexMatches("("+model+"</key>\n\\s+<data>\n\\s+[\n\ta-zA-z0-9\\+/]+)\n\t\t\t\t</data>")[0]
		let new = model+"</key>\n\t\t\t\t<data>\n\t\t\t\t"+data_formatted
		let new_info = info[info_i!].stringByReplacingOccurrencesOfString(old, withString: new)
		do {
			let path = NSURL(fileURLWithPath: NSString(string:"/tmp/Info.plist").stringByExpandingTildeInPath)
			try new_info.writeToURL(path, atomically: false, encoding: NSUTF8StringEncoding)
		} catch {
			haveError = "Error occurred writing new Info.plist file"
			return
		}
		
		/* The -n option makes sure we don't overwrite the first Info.plist backup */
		let script = "chown root:wheel '/tmp/Info.plist'; "
			+ "mv '/tmp/Info.plist' '\(info_paths[info_i!])'; "
			+ "nvram boot-args=kext-dev-mode=1; " /* Enable allowing unsigned kexts */
			+ "kextcache -system-caches" /* Redo kext caches */
		if shellWithAdministratorPrivileges(script) == "ERROR" {
			haveError = "Failed to apply changes."
		}
		info = []
	}

	func revertToOriginal() {
		let script = "cp '\(applicationSupport)/0/Info.plist' '\(info_paths[0])'; "
			+ "chown root:wheel '\(info_paths[0])'; "
			+ "cp '\(applicationSupport)/1/Info.plist' '\(info_paths[1])'; "
			+ "chown root:wheel '\(info_paths[1])'; "
			+ "nvram boot-args=kext-dev-mode=1; "
			+ "kextcache -system-caches"
		if shellWithAdministratorPrivileges(script) == "ERROR" {
			haveError = "Failed to revert to original. Install the OS X Combo Update."
		}
		info = []
	}
	
	func havePrerequisites() -> Bool {
		var have = true
		if NSFileManager.defaultManager().fileExistsAtPath("/usr/bin/csrutil") {
			let ioreg = shell("/usr/bin/csrutil", arguments: ["status"])
			if ioreg.containsString("enabled") {
				have = false
			}
		}
		return have
	}
	
	func haveOriginalPlists() -> Bool {
		let fm = NSFileManager.defaultManager()
		for i in [0, 1] {
			if fm.fileExistsAtPath("\(applicationSupport)/\(i)/Info.plist") {
				let a = shell("/sbin/md5", arguments: ["-q", info_paths[i]])
				let b = shell("/sbin/md5", arguments: ["-q", "\(applicationSupport)/\(i)/Info.plist"])
				if a != b {
					return false
				}
			}
		}
		return true
	}
}
