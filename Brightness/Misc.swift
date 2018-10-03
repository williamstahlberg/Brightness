import Cocoa

extension String {
	subscript (i: Int) -> Character {
		return self[self.startIndex.advancedBy(i)]
	}
	
	subscript (i: Int) -> String {
		return String(self[i] as Character)
	}
	
	subscript (r: Range<Int>) -> String {
		let start = startIndex.advancedBy(r.startIndex)
		let end = start.advancedBy(r.endIndex - r.startIndex)
		return self[Range(start ..< end)]
	}
}

extension String {
	func regexMatches(pattern: String) -> Array<String> {
		let re: NSRegularExpression
		do {
			re = try NSRegularExpression(pattern: pattern, options: [])
		} catch {
			return []
		}
		
		let matches = re.matchesInString(self, options: [], range: NSRange(location: 0, length: self.utf16.count))
		var collectMatches: Array<String> = []
		for match in matches {
			// range at index 0: full match
			// range at index 1: first capture group
			let substring = (self as NSString).substringWithRange(match.rangeAtIndex(1))
			collectMatches.append(substring)
		}
		return collectMatches
	}
}

extension String {
	func replace(target: String, withString: String) -> String {
		return self.stringByReplacingOccurrencesOfString(target, withString: withString, options: NSStringCompareOptions.LiteralSearch, range: nil)
	}
}

extension String {
	func truncate(count_:Int) -> String {
		let stringLength = self.characters.count
		let substringIndex = (stringLength < count_) ? 0 : stringLength - count_
		return self.substringToIndex(self.startIndex.advancedBy(substringIndex))
	}
}

func shellWithAdministratorPrivileges(shell:String) -> String {
	let script = "do shell script \"\(shell)\" with administrator privileges"
	let appleScript = NSAppleScript(source: script)
	let eventResult = appleScript!.executeAndReturnError(nil)
	if eventResult.stringValue == nil {
		return "ERROR"
	} else{
		return eventResult.stringValue!
	}
}

func shell(launchPath: String, arguments: [String]) -> String {
	let task = NSTask()
	task.launchPath = launchPath
	task.arguments = arguments
	
	let pipe = NSPipe()
	task.standardOutput = pipe
	task.launch()
	
	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
	
	return output
}