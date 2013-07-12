path = require 'path'
fs = require './fs'
CSON = require 'season'
config = require './config'
mkdir = require('mkdirp').sync

module.exports =
class Linker
  run: (options) ->
    linkPath = path.resolve(process.cwd(), options.commandArgs.shift() ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    targetPath = path.join(config.getAtomDirectory(), 'packages', packageName)
    try
      fs.unlinkSync(targetPath) if fs.isLink(targetPath)
      mkdir path.dirname(targetPath)
      fs.symlinkSync(linkPath, targetPath)
      console.log "#{targetPath} -> #{linkPath}"
    catch error
      console.error("Linking #{targetPath} to #{linkPath} failed")
      options.callback(error)
