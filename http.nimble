# Package

version       = "0.2.0"
author        = "Alexander Ivanov"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
binDir           = "bin"
bin           = @["http"]
# skipExt       = @[]
# installDirs   = @["."]
installExt    = @["nim"]


# Dependencies

requires "nim >= 0.20.2", "karax", "norm", "chronicles", "confutils"
