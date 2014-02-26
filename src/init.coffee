path = require 'path'

optimist = require 'optimist'

Command = require './command'
fs = require './fs'

module.exports =
class Init extends Command
  @commandNames: ['init']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage:
        apm init -p <package-name>
        apm init -p <package-name> -c ~/Downloads/r.tmbundle
        apm init -p <package-name> -c https://github.com/textmate/r.tmbundle

        apm init -t <theme-name>
        apm init -t <theme-name> -c ~/Downloads/Dawn.tmTheme
        apm init -t <theme-name> -c https://raw.github.com/chriskempson/tomorrow-theme/master/textmate/Tomorrow-Night-Eighties.tmTheme

      Generates code scaffolding for either a theme or package depending
      on option selected.
    """
    options.alias('p', 'package').string('package').describe('package', 'Generates a basic package')
    options.alias('t', 'theme').string('theme').describe('theme', 'Generates a basic theme')
    options.alias('c', 'convert').string('convert').describe('convert', 'Path or URL to TextMate bundle/theme to convert')
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    if options.argv.package?.length > 0
      if options.argv.convert
        @convertPackage(options.argv.convert, options.argv.package, callback)
      else
        packagePath = path.resolve(options.argv.package)
        templatePath = path.resolve(__dirname, '..', 'templates', 'package')
        @generateFromTemplate(packagePath, templatePath)
        callback()
    else if options.argv.theme?.length > 0
      if options.argv.convert
        @convertTheme(options.argv.convert, options.argv.theme, callback)
      else
        themePath = path.resolve(options.argv.theme)
        templatePath = path.resolve(__dirname, '..', 'templates', 'theme')
        @generateFromTemplate(themePath, templatePath)
        callback()
    else if options.argv.package?
      callback('You must specify a path after the --package argument')
    else if options.argv.theme?
      callback('You must specify a path after the --theme argument')
    else
      callback('You must specify either --package or --theme to `apm init`')

  convertPackage: (sourcePath, destinationPath, callback) ->
    unless destinationPath
      callback("Specify directory to create package in using --package")
      return

    PackageConverter = require './package-converter'
    converter = new PackageConverter(sourcePath, destinationPath)
    converter.convert (error) =>
      if error?
        callback(error)
      else
        destinationPath = path.resolve(destinationPath)
        templatePath = path.resolve(__dirname, '..', 'templates', 'bundle')
        @generateFromTemplate(destinationPath, templatePath)
        callback()

  convertTheme: (sourcePath, destinationPath, callback) ->
    unless destinationPath
      callback("Specify directory to create theme in using --theme")
      return

    ThemeConverter = require './theme-converter'
    converter = new ThemeConverter(sourcePath, destinationPath)
    converter.convert (error) =>
      if error?
        callback(error)
      else
        destinationPath = path.resolve(destinationPath)
        templatePath = path.resolve(__dirname, '..', 'templates', 'theme')
        @generateFromTemplate(destinationPath, templatePath)
        fs.removeSync(path.join(destinationPath, 'stylesheets'))
        fs.removeSync(path.join(destinationPath, 'LICENSE.md'))
        callback()

  generateFromTemplate: (packagePath, templatePath) ->
    packageName = path.basename(packagePath)

    fs.makeTreeSync(packagePath)

    for childPath in fs.listRecursive(templatePath)
      templateChildPath = path.resolve(templatePath, childPath)
      relativePath = templateChildPath.replace(templatePath, "")
      relativePath = relativePath.replace(/^\//, '')
      relativePath = relativePath.replace(/\.template$/, '')
      relativePath = @replacePackageNamePlaceholders(relativePath, packageName)

      sourcePath = path.join(packagePath, relativePath)
      continue if fs.existsSync(sourcePath)
      if fs.isDirectorySync(templateChildPath)
        fs.makeTreeSync(sourcePath)
      else if fs.isFileSync(templateChildPath)
        fs.makeTreeSync(path.dirname(sourcePath))
        contents = fs.readFileSync(templateChildPath).toString()
        content = @replacePackageNamePlaceholders(contents, packageName)
        fs.writeFileSync(sourcePath, content)

  replacePackageNamePlaceholders: (string, packageName) ->
    placeholderRegex = /__(?:(package-name)|([pP]ackageName)|(package_name))__/g
    string = string.replace placeholderRegex, (match, dash, camel, underscore) =>
      if dash
        @dasherize(packageName)
      else if camel
        if /[a-z]/.test(camel[0])
          packageName = packageName[0].toLowerCase() + packageName[1...]
        else if /[A-Z]/.test(camel[0])
          packageName = packageName[0].toUpperCase() + packageName[1...]
        @camelize(packageName)

      else if underscore
        @underscore(packageName)

  dasherize: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(_)/g, (m, letter, underscore) ->
      if letter
        "-" + letter.toLowerCase()
      else
        "-"

  camelize: (string) ->
    string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()

  underscore: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(-)/g, (m, letter, dash) ->
      if letter
        "_" + letter.toLowerCase()
      else
        "_"
