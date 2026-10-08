import PatternSpaceSDKCore

extension InputValidator {
    static func patch(_ params: JSONValue?) throws -> PatchParams {
        let obj = params?.object ?? [:]
        guard let bg = obj["background"]?.object,
              let br = bg["r"]?.number, let bg_g = bg["g"]?.number, let bb = bg["b"]?.number,
              let rectValues = obj["rectangles"]?.array,
              let bdInt = obj["bitDepth"]?.int else {
            throw PSDispatchError(.invalidParams, message: "background, rectangles, and bitDepth are required")
        }
        try InputValidator.validateColor(r: br, g: bg_g, b: bb)
        try InputValidator.validateBitDepth(bdInt)
        try InputValidator.validateRectangleCount(rectValues.count)
        guard let bitDepth = BitDepth(rawValue: bdInt) else { throw PSDispatchError(.invalidBitDepth) }

        let rectangles = try rectValues.map { value -> PatchRectangle in
            guard let obj = value.object,
                  let colorObject = obj["color"]?.object,
                  let r = colorObject["r"]?.number,
                  let g = colorObject["g"]?.number,
                  let b = colorObject["b"]?.number,
                  let x = obj["x"]?.number,
                  let y = obj["y"]?.number,
                  let width = obj["width"]?.number,
                  let height = obj["height"]?.number else {
                throw PSDispatchError(.invalidParams, message: "each rectangle requires color, x, y, width, and height")
            }
            try InputValidator.validateColor(r: r, g: g, b: b)
            try InputValidator.validateRectangle(x: x, y: y, width: width, height: height)
            return PatchRectangle(color: PSColor(r: r, g: g, b: b), x: x, y: y, width: width, height: height)
        }

        return PatchParams(background: PSColor(r: br, g: bg_g, b: bb), rectangles: rectangles, bitDepth: bitDepth)
    }
}
