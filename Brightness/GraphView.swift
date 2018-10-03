import Cocoa

class GraphView: NSView {
	var collections: [(x: [Float], y: [Float], lineWidth: Float, color: NSColor)] = []
	var ticks: (x: [(Float, String)], y: [(Float, String)]) = (x: [], y: [])
	var options = (tickLimits: false, roundLimits: false)
	var x_min: Float = Float.infinity, x_max: Float = 0.0, y_min: Float = Float.infinity, y_max: Float = 0.0
	var tickInt = (x: false, y: false)
	var force_padding: (top: CGFloat?, right: CGFloat?, bottom: CGFloat?, left: CGFloat?)
	
	override func drawRect(dirtyRect: NSRect) {
		let attr = [NSFontAttributeName: NSFont.systemFontOfSize(10)]
		
		/* Padding */
		var x_tick_size = (min: (height:CGFloat(0),width:CGFloat(0)), max: (height:CGFloat(0),width:CGFloat(0)))
		var y_tick_size = (min: (height:CGFloat(0),width:CGFloat(0)), max: (height:CGFloat(0),width:CGFloat(0)))
		var padding = (right: CGFloat(0), bottom: CGFloat(0.5), left: CGFloat(0.5), top: CGFloat(0))
		
		if ticks.x.count > 0 {
			x_tick_size.min.width = (ticks.x.first!.1 as NSString).sizeWithAttributes(attr).width /* Leftmost x tick width */
			x_tick_size.max.width = (ticks.x.last!.1 as NSString).sizeWithAttributes(attr).width /* Rightmost x tick width */
			x_tick_size.min.height = ("A" as NSString).sizeWithAttributes(attr).height /* Leftmost x tick height */
			x_tick_size.max.height = ("A" as NSString).sizeWithAttributes(attr).height /* Rightmost x tick height */
			
			padding.right = round(x_tick_size.max.width/2)
			padding.bottom = 3.5 + round(x_tick_size.min.height)
			padding.left = 0.5 + round(x_tick_size.min.width/2)
		}
		if ticks.y.count > 0 {
			for (_,s) in ticks.y { /* Max width of all y ticks */
				let width_ = (s as NSString).sizeWithAttributes(attr).width
				if width_ > y_tick_size.min.width {
					y_tick_size.min.width = width_
					y_tick_size.max.width = width_
				}
			}
			y_tick_size.min.height = ("A" as NSString).sizeWithAttributes(attr).height /* Bottom y tick height */
			y_tick_size.max.height = ("A" as NSString).sizeWithAttributes(attr).height /* Top y tick height */
			
			padding.bottom = [3.5 + round(x_tick_size.min.height), padding.bottom].maxElement()! /* Is it greater than the current bottom padding? */
			padding.left = [7.5 + round([y_tick_size.min.width, y_tick_size.max.width/2].maxElement()!), padding.left].maxElement()!
			padding.top = round(y_tick_size.max.height/2)
		}
		padding.top = force_padding.top != nil ? force_padding.top! : padding.top
		padding.right = force_padding.right != nil ? force_padding.right! : padding.right
		padding.bottom = force_padding.bottom != nil ? force_padding.bottom! : padding.bottom
		padding.left = force_padding.left != nil ? force_padding.left! : padding.left
		
		let width = -0.5 + dirtyRect.width - padding.left - padding.right
		let height = -0.5 + dirtyRect.height - padding.bottom - padding.top
		
		/* Canvas */
		let canvas = NSBezierPath(rect: NSRect(
			x: padding.left,
			y: padding.bottom,
			width: width,
			height: height
			))
		NSColor.whiteColor().set(); canvas.fill()
		
		/* Graph */
		let scale = (x: width/CGFloat(x_max-x_min), y: height/CGFloat(y_max-y_min))
		var line: NSBezierPath
		for c in collections {
			line = NSBezierPath(); c.color.set()
			let x = c.x, y = c.y;
			for i in 0..<x.count-1 {
				line.moveToPoint(NSPoint(
					x: padding.left + scale.x*CGFloat(x[i]-x_min),
					y: padding.bottom + scale.y*CGFloat(y[i]-y_min)
					))
				line.lineToPoint(NSPoint(
					x: padding.left + scale.x*CGFloat(x[i+1]-x_min),
					y: padding.bottom + scale.y*CGFloat(y[i+1]-y_min)
					))
			}
			line.lineWidth = CGFloat(c.lineWidth); line.stroke()
		}

		/* Ticks */
		line = NSBezierPath(); NSColor.grayColor().set()
		for (x,_) in ticks.x {
			line.moveToPoint(NSPoint(
				x: padding.left + round(scale.x*CGFloat(x-x_min)),
				y: padding.bottom
				))
			line.lineToPoint(NSPoint(
				x: padding.left + round(scale.x*CGFloat(x-x_min)),
				y: padding.bottom - 5
				))
		}
		for (y,_) in ticks.y {
			line.moveToPoint(NSPoint(
				x: padding.left,
				y: padding.bottom + round(scale.y*CGFloat(y-y_min))
				))
			line.lineToPoint(NSPoint(
				x: padding.left - 5,
				y: padding.bottom + round(scale.y*CGFloat(y-y_min))
				))
		}
		line.lineWidth = 1.0; line.stroke()
		for (x,s) in ticks.x {
			drawTextWithAnchor(s, x: padding.left + scale.x*CGFloat(x-x_min), y: padding.bottom-5, anchor: "N", attr: attr)
		}
		for (y,s) in ticks.y {
			drawTextWithAnchor(s, x: padding.left - 8, y: padding.bottom + round(scale.y*CGFloat(y-y_min)), anchor: "E", attr: attr)
		}
		
		/* Border */
		NSColor.grayColor().set(); canvas.lineWidth = 1.0; canvas.stroke()
		
		collections = []
		ticks = (x: [], y: [])
	}
	
	func drawTextWithAnchor(string: String, x: CGFloat, y: CGFloat, anchor: String = "C", attr: [String: NSFont]) {
		let size = (string as NSString).sizeWithAttributes(attr)
		switch(anchor) {
		case "N":
			(String(string) as NSString).drawAtPoint(NSPoint(x: x-size.width/2, y: y-size.height), withAttributes: attr)
		case "E":
			(String(string) as NSString).drawAtPoint(NSPoint(x: x-size.width,   y: y-size.height/2), withAttributes: attr)
		case "S":
			(String(string) as NSString).drawAtPoint(NSPoint(x: x-size.width/2, y: y-size.height), withAttributes: attr)
		case "W":
			(String(string) as NSString).drawAtPoint(NSPoint(x: x,              y: y-size.height/2), withAttributes: attr)
		default:
			(String(string) as NSString).drawAtPoint(NSPoint(x: x-size.width/2, y: y-size.height/2), withAttributes: attr)
		}
	}
	
	@nonobjc
	func plot(var x: [Float], var y: [Float] = [], lineWidth: Float = 1.0, color: NSColor = NSColor.blackColor()) {
		if x.count == 0 && y.count == 0 {
			return
		}
		if y.count == 0 {
			y = x
			x = []
			for i in 0..<y.count {
				x.append(Float(i))
			}
			tickInt.x = true
		}
		if x.count != y.count {
			fatalError("plot: x and y have mismatching lengths.")
		}
		x_min = x.minElement()! < x_min ? x.minElement()! : x_min
		x_max = x.maxElement()! > x_max ? x.maxElement()! : x_max
		y_min = y.minElement()! < y_min ? y.minElement()! : y_min
		y_max = y.maxElement()! > y_max ? y.maxElement()! : y_max
		
		collections.append((x: x, y: y, lineWidth: lineWidth, color: color))
	}
	
	@nonobjc
	func plot(x: [Int], y: [Int] = [], lineWidth: Float = 1.0, color: NSColor = NSColor.blackColor()) {
		var x_float = [Float](), y_float = [Float]()
		for x_ in x {
			x_float.append(Float(x_))
		}
		for y_ in y {
			y_float.append(Float(y_))
		}
		tickInt = (true, true)
		
		plot(x_float, y: y_float, lineWidth: lineWidth, color: color)
	}
	
	@nonobjc
	func plot(x: [Int], y: [Float], lineWidth: Float = 1.0, color: NSColor = NSColor.blackColor()) {
		var x_float = [Float]()
		for x_ in x {
			x_float.append(Float(x_))
		}
		tickInt.x = true
		
		plot(x_float, y: y, lineWidth: lineWidth, color: color)
	}
	
	@nonobjc
	func plot(x: [Float], y: [Int], lineWidth: Float = 1.0, color: NSColor = NSColor.blackColor()) {
		var y_float = [Float]()
		for y_ in y {
			y_float.append(Float(y_))
		}
		tickInt.y = true
		
		return plot(x, y: y_float, lineWidth: lineWidth, color: color)
	}
	
	@nonobjc
	func tickX(x: [Float] = []) {
		let x_ = x.count > 0 ? x : collections.last!.x
		ticks.x = []
		for x__ in x_ {
			ticks.x.append(tickInt.x ? (x__, String(Int(x__))) : (x__, String(x__)))
		}
	}
	
	func tickX(x: [(Float, String)]) {
		ticks.x = x
	}
	
	func tickY(y: [Float] = []) {
		let y_ = y.count > 0 ? y : collections.last!.y
		ticks.y = []
		for y__ in y_ {
			ticks.y.append(tickInt.y ? (y__, String(Int(y__))) : (y__, String(y__)))
		}
	}
	
	func tickY(y: [(Float, String)]) {
		ticks.y = y
	}
	
	func forcePadding(top top: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil, left: CGFloat? = nil) {
		force_padding.top = top != nil ? top : force_padding.top
		force_padding.right = right != nil ? right : force_padding.right
		force_padding.bottom = bottom != nil ? 0.5+round(bottom!) : force_padding.bottom
		force_padding.left = left != nil ? 0.5+round(left!) : force_padding.left
	}
	
	func show() {
		needsDisplay = true
	}
}