/*
 *  CodeRenderer.swift
 *  Quicklook Anything
 *
 *  Created by Tony Smith on 30/05/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit
import UniformTypeIdentifiers
import Highlighter


/**
 One `Highlighter` (a JavaScriptCore context with Highlight.js loaded) per
 preview-extension process, so previews after the first skip the ~25 ms it
 takes to build one.

 LOCAL. All use of a highlighter happens on its serial queue, because each user
 sets the shared theme before highlighting. Previews use `shared`; a large
 file's full highlight (see `PreviewViewController`) uses `background`, so the
 next preview never waits for it (a 900 KB file takes about 250 ms).
 */
final class SharedHighlighter: @unchecked Sendable {

    static let shared = SharedHighlighter(label: "com.bps.previewcode.highlighter", qos: .userInitiated)
    // Built on first use, ie. when a large file is first previewed
    static let background = SharedHighlighter(label: "com.bps.previewcode.highlighter.background", qos: .utility)

    private let queue: DispatchQueue
    // Only touched on `queue`
    private var highlighter: Highlighter? = nil
    // The last result, only touched on `queue`: Finder asks for two previews of a
    // file at once (Quick Look panel and column view), so a large file's full
    // highlight is wanted twice
    private var lastResult: (key: String, code: String, result: NSAttributedString)? = nil


    private init(label: String, qos: DispatchQoS) {

        self.queue = DispatchQueue(label: label, qos: qos)
    }


    /// The last result for `code` rendered with settings `key`, if any. Call on the queue, ie. from `body`.
    func cachedResult(_ code: String, _ key: String) -> NSAttributedString? {

        guard let last = self.lastResult, last.key == key, last.code == code else { return nil }
        return last.result
    }


    /// Remember a result. Call on the queue, ie. from `body`.
    func cache(_ result: NSAttributedString, _ code: String, _ key: String) {

        self.lastResult = (key, code, result)
    }


    /// Start building the highlighter in the background, eg. while Quick Look sets up the view.
    func warmUp() {

        self.queue.async { _ = self.loaded() }
    }


    /// Run `body` with the highlighter on its queue and wait. Never call from `body`.
    func sync<T>(_ body: (Highlighter) -> T?) -> T? {

        return self.queue.sync {
            guard let hltr = self.loaded() else { return nil }
            return body(hltr)
        }
    }


    /// Run `body` with the highlighter on its queue without waiting.
    func async(_ body: @escaping (Highlighter?) -> Void) {

        self.queue.async { body(self.loaded()) }
    }


    private func loaded() -> Highlighter? {

        if self.highlighter == nil {
            self.highlighter = Highlighter()
        }

        return self.highlighter
    }
}


// FROM 1.1.0
// Implement as a class
final internal class CodeRenderer {

    // MARK: - Public Properties

    var themeBackgroundColour: NSColor          = .white
    var isThemeDark: Bool                       = false
    var settings: AppSettings                    = AppSettings()


    // MARK: - Private Properties

    private  var font: NSFont?                  = nil
    private  var highlighter: Highlighter?      = nil
    // FROM 2.0.0
    private  var isThumbnail: Bool              = false
    // LOCAL: use `SharedHighlighter` rather than an instance-owned highlighter
    private  var usesSharedHighlighter: Bool    = false
    private  var highlightJsThemeName: String   = ""

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = Constants.TEAM_ID + Constants.SUITE_NAME

    
    // MARK: - Lifecycle Functions

    init?(forThumbnail: Bool, sharedHighlighter: Bool = false) {

        // Set local values with default properties
        var highlightJsThemeName: String
        self.usesSharedHighlighter = sharedHighlighter && !forThumbnail

        // Read in the user preferences to update the above values
        self.settings.loadSettings(self.appSuiteName)

        if forThumbnail {
            // Thumbnails use fixed, light-on-dark values
            highlightJsThemeName = setTheme(Constants.THUMBNAIL.THEME)
            self.settings.fontSize = CGFloat(Constants.THUMBNAIL.FONT_SIZE)
            self.isThumbnail = true
        } else {
            // Set preview theme details
            // FROM 1.3.0 -- adjust by current state or user setting
            switch self.settings.themeDisplayMode {
                case Constants.DISPLAY_MODE.LIGHT:
                    highlightJsThemeName = setTheme(self.settings.lightThemeName)
                case Constants.DISPLAY_MODE.DARK:
                    highlightJsThemeName = setTheme(self.settings.darkThemeName)
                    self.isThemeDark = true
                default:
                    let isLight = NSApp.inLightMode
                    highlightJsThemeName = isLight ? setTheme(self.settings.lightThemeName) : setTheme(self.settings.darkThemeName)
                    self.isThemeDark = !isLight
            }

            // Just in case the above block reads in zero value for the preview font size
            if !(Constants.FONT_SIZE_MIN...Constants.FONT_SIZE_MAX).contains(self.settings.fontSize) {
                self.settings.fontSize = CGFloat(Constants.DEFAULTS.FONT_SIZE)
            }
        }

        // Generate the font we'll use, at the required size
        if let chosenFont = NSFont(name: self.settings.fontName, size: self.settings.fontSize) {
            self.font = chosenFont
        } else {
            self.font = NSFont.systemFont(ofSize: self.settings.fontSize)
        }

        self.highlightJsThemeName = highlightJsThemeName

        // LOCAL: the preview extension shares one highlighter per process
        if self.usesSharedHighlighter {
            guard let background = withSharedHighlighter({ $0.theme.themeBackgroundColour }) else { return nil }

            self.themeBackgroundColour = background
            return
        }

        // Instantiate the instance's highlighter
        self.highlighter = Highlighter()
        guard let hltr = self.highlighter else { return nil }
        configure(hltr)
        self.themeBackgroundColour = hltr.theme.themeBackgroundColour
    }


    /**
     Run `body` with the shared highlighter, set up for this instance, and wait.

     LOCAL
     */
    private func withSharedHighlighter<T>(_ body: (Highlighter) -> T?) -> T? {

        return SharedHighlighter.shared.sync { (hltr: Highlighter) -> T? in
            self.configure(hltr)
            return body(hltr)
        }
    }


    /**
     Apply this instance's theme, font and line spacing to a highlighter.

     LOCAL: split out so the shared highlighter can be set up for each preview.
     */
    private func configure(_ hltr: Highlighter) {

        hltr.setTheme(self.highlightJsThemeName)
        // We can be sure `self.font` is not nil: `init` always sets it
        hltr.theme.setCodeFont(self.font!)

        // Requires HighligherSwift 1.1.3
        if !self.isThumbnail {
            hltr.theme.lineSpacing = (self.settings.lineSpacing - 1.0) * self.settings.fontSize
        }
    }

    
    // MARK: - The Primary Function

    /**
    Use HightlightSwift to style the source code string.

    - Parameters:
        - codeFileString: The raw source code.
        - language:       The source code language, eg. `swift`.

    - Returns: The rendered source as an NSAttributedString.
    */
    func getAttributedString(_ codeFileString: String, _ language: String) -> NSAttributedString {

        // Run the specified code string through Highlightr/Highlight.js
        var renderedString: NSAttributedString? = nil

        // LOCAL: with the shared highlighter, set it up and render on its queue
        if self.usesSharedHighlighter {
            renderedString = withSharedHighlighter { self.render(codeFileString, language, $0) }
        } else if let hltr = self.highlighter {
            renderedString = render(codeFileString, language, hltr)
        }

        return finish(renderedString, language)
    }


    /**
     Highlight code on the shared highlighter's queue and pass the result to
     `completion` on that queue, without blocking the caller.

     LOCAL: used to finish highlighting large files after the first screen is shown.
     Only for instances created with `sharedHighlighter: true`.

     - Parameters:
        - codeFileString: The raw source code.
        - language:       The source code language, eg. `swift`.
        - completion:     Receives the rendered source.
     */
    func getAttributedStringInBackground(_ codeFileString: String, _ language: String,
                                         completion: @escaping (NSAttributedString) -> Void) {

        let highlighter = SharedHighlighter.background
        let key = [language, self.highlightJsThemeName, self.font!.fontName, "\(self.font!.pointSize)",
                   "\(self.settings.lineSpacing)", "\(self.settings.doShowLineNumbers)", "\(self.isThemeDark)"].joined(separator: "|")
        highlighter.async { hltr in
            if let cached = highlighter.cachedResult(codeFileString, key) {
                completion(cached)
                return
            }

            var renderedString: NSAttributedString? = nil
            if let hltr = hltr {
                self.configure(hltr)
                renderedString = self.render(codeFileString, language, hltr)
            }

            let result = self.finish(renderedString, language)
            if renderedString != nil {
                highlighter.cache(result, codeFileString, key)
            }
            completion(result)
        }
    }


    /**
     The attributes the theme gives plain, unhighlighted code.

     LOCAL. Only for instances created with `sharedHighlighter: true`.
     */
    func plainTextAttributes() -> [NSAttributedString.Key: Any] {

        return withSharedHighlighter { $0.plainTextAttributes() } ?? [.font: self.font!]
    }


    /**
     Run Highlight.js over the code, with line numbers if the user wants them.

     LOCAL: split out of `getAttributedString()`.
     */
    private func render(_ codeFileString: String, _ language: String, _ hltr: Highlighter) -> NSAttributedString? {

        guard !self.isThumbnail && self.settings.doShowLineNumbers else {
            // Render without line numbers
            return hltr.highlight(codeFileString, as: language)
        }

        // FROM 2.2.0
        // Use line numbering from HighlighterSwift
        var lnd = LineNumberData()
        lnd.fontSize = self.settings.fontSize
        lnd.minWidth = 2

        // Use our theme mode to specify the colour of the line numbers
        // LOCAL: `isThemeDark` was worked out in `init` (on the main thread) from
        // the same mode setting and, in auto mode, from NSApp's appearance; this
        // function may run on the shared highlighter's background queue
        lnd.usingDarkTheme = self.isThemeDark

        // Render with line numbers
        return hltr.highlight(codeFileString, as: language, doFastRender: true, lineNumbering: lnd)
    }


    /**
     Return the rendered code, or an error message if rendering failed.

     LOCAL: split out of `getAttributedString()`.
     */
    private func finish(_ renderedString: NSAttributedString?, _ language: String) -> NSAttributedString {

        // If the rendered string is good, return it
        if let ras = renderedString {
            // Trap any incorrectly parsed language names
            if (ras.string != "undefined") {
                // FROM 1.2.0
                // During debugging, add language name to preview
#if DEBUG
                let debugAtts: [NSAttributedString.Key : Any] = [
                    .foregroundColor: NSColor.red,
                    .font: self.font!
                ]

                let hs = NSMutableAttributedString(string: "Language: \(language)\n", attributes: debugAtts)
                hs.append(ras)
                return hs as NSAttributedString
#else
                return ras
#endif
            }
        }

        // Return an error message
        let errorAtts: [NSAttributedString.Key : Any] = [
            .foregroundColor: NSColor.red,
            .font: self.font!
        ]

        return NSAttributedString(string: "Could not render source code in (\(language))",
                                  attributes: errorAtts)
    }


    // MARK: - Utility Functions

    /**
     Set key theme parameters.
     
     We record in prefs a string combinining the theme's Highlight.js name and
     its 'mode' (light or dark), so we need to call this function at some
     point to extract these two data points.
     
     **NOTE** This should now be called only **once**, before the code is rendered
          to avoid threading race conditions. This is called by `setBaseValues()`
          and `AppDelegate` (frequently, once for each theme).
     
     - Parameters:
        - themeData: The PreviewCode theme info string, eg. `dark.an-old-hope`.
     */
    func updateTheme(_ themeData: String) {
        
        let themeName = setTheme(themeData)
        self.highlightJsThemeName = themeName
        if let hltr = self.highlighter {
            hltr.setTheme(themeName)
            self.themeBackgroundColour = hltr.theme.themeBackgroundColour
        }
    }


    /**
     Extract the theme name from the storage string.

     - Parameters:
        - themeString: The base theme record, eg. `light.atom-one-light`.

     - Returns: The name of the theme's filem, eg. `atom-one-light`.
     */
    private func setTheme(_ themeString: String) -> String {

        var themeParts = themeString.components(separatedBy: ".")

        // Just in case...
        if themeParts.count != 2 {
            themeParts = ["dark", "agate"]
        }

        self.isThemeDark = (themeParts[0] == "dark")
        return themeParts[1]
    }


    /**
     Determine the source file's language from its UTI.

     For example, `public.swift-source` -> `swift`.

     If `isForTag` is `true`, it returns the actual name of the language,
     not the naming used by Highlight.js, which it returns if `isForTag`
     is `false`. This is because these are not always the same,
     eg. `c++` vs `cpp`, `pascal` vs `delphi`.

     FROM 2.2.5 -- Remove `isForTag` arg.

    - Parameters:
        - sourceFilePath: The path to the source code file.

    - Returns: The source code's language.
    */
    func getLanguage(_ sourceFilePath: String) -> String {

        // FROM 1.2.2 -- make sure these are lowercase
        let sourceFileUTI = getSourceFileUTI(sourceFilePath).lowercased()
        let sourceFileExtension = (sourceFilePath as NSString).pathExtension.lowercased()
        let sourceFileName = (sourceFilePath as NSString).lastPathComponent.lowercased()

        // LOCAL: `Makefile`, `GNUmakefile` and `Makefile.def`-style names, whatever
        // their extension makes of them (`.def` is typed as TeX)
        if sourceFileName.hasPrefix("makefile") || sourceFileName.hasPrefix("gnumakefile") { return "makefile" }
        // LOCAL: extensionless scripts such as `gitclone` take the language of their `#!` line
        if sourceFileUTI == "public.unix-executable" { return shebangLanguage(sourceFilePath) ?? "plaintext" }
        // LOCAL: IDL `.pro` files
        if sourceFileUTI.hasSuffix(".idl-source") { return "idl" }

        // Trap 'non-standard' UTIs
        if sourceFileUTI.hasPrefix("com.apple.applescript") { return "applescript" }
        if sourceFileUTI.hasSuffix("property-list") { return "xml" }
        // Standard UTIs which contain strings we need to remove on other cases
        if sourceFileUTI == "public.script" { return "bash" }
        if sourceFileUTI == "public.css" { return "css" }
        // FROM 1.2.0 -- Present .env files using the bash renderer
        if sourceFileUTI == "com.bps.env" { return "bash" }
        if sourceFileUTI == "com.bps.conf" { return "makefile" }
        if sourceFileUTI.hasSuffix(".terraform-vars") { return "toml" }
        // FROM 1.2.4
        if sourceFileUTI.hasSuffix(".c-sharp") { return "c#" }
        // FROM 1.2.6 -- Assorted Xcode files
        //if sourceFileUTI.hasSuffix(".entitlements-property-list") { return "xml" }
        if sourceFileUTI.hasSuffix(".interfacebuilder.document.cocoa") { return "xml" }
        if sourceFileUTI.hasSuffix("interfacebuilder.document.storyboard") { return "xml" }
        // FROM 1.3.2 -- Microsoft TypeScript UTI
        if sourceFileUTI.hasSuffix(".typescript") { return "typescript" }
        // FROM 1.3.5
        if sourceFileUTI.contains("asciidoc") { return "makefile" }
        // LOCAL: the system UTI is `org.tug.tex`, which the old `.tug` suffix test missed
        if sourceFileUTI.hasPrefix("org.tug.") || sourceFileUTI.hasSuffix(".tug") { return "tex" }
        // LOCAL: `.m` is both Objective-C and MATLAB; MATLAB's own UTI is plainly MATLAB
        if sourceFileUTI == "com.mathworks.matlab-source" { return "matlab" }
        if sourceFileExtension == "m" { return isObjectiveC(sourceFilePath) ? "objectivec" : "matlab" }
        if sourceFileUTI.hasSuffix(".lua") { return "lua" }
        if sourceFileUTI.hasSuffix(".clojure") { return "clojure" }
        if sourceFileUTI.hasSuffix(".javascript-xml") { return "javascript" }
        // FROM 1.3.6
        if sourceFileUTI.hasSuffix(".xmp") { return "xml" }
        if sourceFileUTI.hasSuffix(".dop") { return "awk" }
        if sourceFileUTI.hasSuffix("xcode.strings-text") { return "awk" }
        // FROM 1.3.7
        if sourceFileUTI == "org.oasis-open.xliff" { return "xml" }
        if sourceFileUTI.hasSuffix(".tmx") { return "xml" }
        // FROM 2.1.0
        if sourceFileUTI.hasSuffix("opl-source") { return "psion" }
        // FROM 2.2.5
        if sourceFileUTI.contains("dita.") { return "xml" }
        if sourceFileUTI.hasSuffix(".toml") { return "toml" }
        if sourceFileUTI.hasSuffix(".ini") { return "makefile" }
        if sourceFileUTI.hasSuffix(".sql") { return "sql" }

        // Remaining UTIs follow a standard structure:
        // eg. `public.objective-c-source`
        // So split by `.`, ignore the first item, and remove the `-xxx-yyy`
        var sourceLanguage = Constants.DEFAULTS.LANGUAGE_UTI
        let parts = sourceFileUTI.components(separatedBy: ".")
        if parts.count > 0 {
            let index = parts.count - 1
            var endIndex: Range<String.Index>? = parts[index].range(of: "-source")
            if endIndex == nil { endIndex = parts[index].range(of: "-header") }
            if endIndex == nil { endIndex = parts[index].range(of: "-script") }

            if let anEndIndex = endIndex {
                sourceLanguage = String(parts[index][..<anEndIndex.lowerBound])
            }
        }

        // Address those languages that are referenced slightly differently
        // in highlight.js, eg. 'objective-c' -> 'objectivec'; are accessed
        // as aliases, eg. 'pascal' -> 'delphi'; or all use the same language,
        // eg. all shells -> 'bash'
        switch(sourceLanguage) {
            case "objective-c":
                sourceLanguage = "objectivec"
            case "objective-c-plus-plus":
                sourceLanguage = "objectivec"
            case "c-plus-plus":
                sourceLanguage = "cpp"
            case "shell", "zsh", "csh", "ksh", "tcsh":
                sourceLanguage = "bash"
            case "pascal":
                sourceLanguage = "delphi"
            case "assembly":
                // FROM 1.4.2 -- Correct 'armasm' -> 'arm'
                if sourceFileExtension == "s" { sourceLanguage = "arm" }
                if sourceFileExtension == "asm" || sourceFileExtension == "nasm" { sourceLanguage = "x86asm" }
            case "nasm-assembly":
                sourceLanguage = "x86asm"
            case "6809-assembly":
                sourceLanguage = "x86asm"
            case "latex":
                sourceLanguage = "tex"
            case "terraform":
                sourceLanguage = "go"
            case "make":
                sourceLanguage = "makefile"
            case "vuejs":
                sourceLanguage = "javascript"
            default:
                // NOP
                break
        }
        
        return sourceLanguage
    }


    /**
     LOCAL: Tell an Objective-C `.m` file from a MATLAB one by its first 8 KB.

     Objective-C files nearly always import a header or declare a class;
     MATLAB never uses `#import`, `#include` or `@interface`-style directives.
     */
    private func isObjectiveC(_ path: String) -> Bool {

        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8192),
              let head = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return false }
        return head.range(of: #"(?m)^\s*(#\s*(import|include)\b|@(interface|implementation|protocol|import)\b)"#,
                          options: .regularExpression) != nil
    }


    /**
     LOCAL: The Highlight.js language named by a script's `#!` line, eg. `perl` for
     `#!/usr/bin/perl -s` or `python` for `#!/usr/bin/env -S python3 -u`.

     - Returns: The language, or `nil` if the file has no `#!` line or names an unknown interpreter.
     */
    private func shebangLanguage(_ path: String) -> String? {

        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256),
              let head = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              head.hasPrefix("#!") else { return nil }

        var words = head.dropFirst(2).prefix { $0 != "\n" && $0 != "\r" }
            .split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // `#!/usr/bin/env [-S] python3`: the interpreter is the first word that is not an option
        if let first = words.first, (first as NSString).lastPathComponent == "env" {
            words = Array(words.dropFirst().drop { $0.hasPrefix("-") || $0.contains("=") })
        }
        guard let interpreter = words.first.map({ ($0 as NSString).lastPathComponent.lowercased() }) else { return nil }

        // Drop a version number: `python3.12` -> `python`, `perl5` -> `perl`
        let name = String(interpreter.prefix { !$0.isNumber && $0 != "." && $0 != "-" })
        switch name {
            case "sh", "bash", "zsh", "ksh", "csh", "tcsh", "dash", "fish": return "bash"
            case "perl": return "perl"
            case "python", "pypy": return "python"
            case "ruby": return "ruby"
            case "node", "deno", "bun": return "javascript"
            case "php": return "php"
            case "lua": return "lua"
            case "tclsh", "wish", "expect": return "tcl"
            case "awk", "gawk", "nawk", "mawk": return "awk"
            case "julia": return "julia"
            case "rscript": return "r"
            case "osascript": return "applescript"
            case "make", "gmake": return "makefile"
            case "swift": return "swift"
            default: return nil
        }
    }


    /**
     LOCAL: Whether a file is a compiled executable rather than a script.

     Scripts without an extension are typed `public.unix-executable`, like compiled
     programs. Only a file that starts with `#!` is shown as code; for anything else
     the extensions report an error, so Quick Look and Finder fall back to their
     own preview and icon.
     */
    static func isBinaryExecutable(_ url: URL) -> Bool {

        guard (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.identifier) == "public.unix-executable" else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return true }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 2)) != Data("#!".utf8)
    }


    /**
    Get the supplied source file's UTI.

    We'll use it to determine the file's programming language.

    - Parameters:
        - sourceFilePath: The path to the source code file.

    - Returns: The source code's UTI.
    */
    private func getSourceFileUTI(_ sourceFilePath: String) -> String {

        // Create a URL reference to the sample file
        var sourceFileUTI = ""
        let sourceFileURL = URL(fileURLWithPath: sourceFilePath)
        // Call below is deprecated but replacement requires macOS 13
        if let uti = try? sourceFileURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
            sourceFileUTI = uti.identifier
        }

        return sourceFileUTI
    }


    /**
     Determine whether a Psion .OPL file contains binary data.

     Compare the first four bytes of the file to three four-byte headers to determine
     whether this the case.

     FROM 2.2.3

     - Parameters:
        - code:     The file-load data.
        - encoding: The string encoding of the loaded file, likely UTF8.

     - Returns Text extracted from the data plus header and footer, reading for highlighting.
     */
    func processPsionFile(_ code: Data, _ encoding: String.Encoding) -> String {

        var hasBinary = false
        var ascii: [UInt8] = Array(code)
        let binaryPrefixes: [[UInt8]] = [
            [0x37,0x00,0x00,0x10],
            [0x6D,0x00,0x00,0x10],
            [0x85,0x00,0x00,0x10]
        ]

        for binaryPrefix in binaryPrefixes {
            var matchCount = 0
            for i in 0..<4 {
                if binaryPrefix[i] != code[i] {
                    break
                }

                matchCount += 1
            }

            if matchCount == 4 {
                hasBinary = true
                break
            }
        }

        if hasBinary {
            // We expect a file with binary data to have bytes
            // 0-37         - binary daya
            // 38-          - text data
            // length-191   - binary data

            // Add header
            var dataString = "REM " +
                             String(repeating: "*", count: 43) +
                             "\nREM BINARY OPL DATA AT START OF FILE (38 BYTES)\nREM " +
                             String(repeating: "*", count: 43) + "\n\n"

            // FROM 2.3.4
            // Check we have the mimimum number of bytes
            guard ascii.count >= 229 else {
                return String(data: code, encoding: encoding) ?? ""
            }

            // Test file used 0x06 as a line break
            for i in 38..<(ascii.count - 191) {
                if code[i] == 06 {
                    ascii[i] = 10
                }
            }

            // Add the Ascii text to the string
            dataString += String(data: Data(ascii[38..<(ascii.count - 191)]), encoding: .utf8) ?? ""
            return dataString + "\nREM " +
                   String(repeating: "*", count: 43) +
                   "\nREM BINARY OPL DATA AT TAIL OF FILE (191 BYTES)\nREM " + 
                   String(repeating: "*", count: 43) + "\n"
        } else {
            // Not a binary string, so return it untouched ready for highlighting
            return String(data: code, encoding: encoding) ?? ""
        }
    }

}
