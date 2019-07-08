# Package

version       = "0.2.0"
author        = "Alexander Ivanov"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["http"]
skipExt       = @[]


# Dependencies

requires "nim >= 0.20.2", "karax", "norm", "chronicles", "confutils"
