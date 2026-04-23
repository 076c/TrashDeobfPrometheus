local script_name = arg[1]
local content = assert(io.open(script_name, "r")):read("*a")

local parsed = require("./prometheus/parser"):new():parse(content)

require("./steps/UnwrapFunction")(parsed)

io.open("out_1.txt", "w"):write(require("./prometheus/unparser"):new({}):unparse(parsed))

require("./steps/DecodeConstantArray")(parsed)
require("./steps/ResolveOffset")(parsed)

io.open("out_2.txt", "w"):write(require("./prometheus/unparser"):new({}):unparse(parsed))

require("./steps/ResolveParameters")(parsed)

io.open("out_3.txt", "w"):write(require("./prometheus/unparser"):new({}):unparse(parsed))

require("./steps/PropagateFenvAccess")(parsed)

io.open("out.txt", "w"):write(require("./prometheus/unparser"):new({}):unparse(parsed))