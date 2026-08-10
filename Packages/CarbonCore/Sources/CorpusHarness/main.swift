import CorpusScoring
import Foundation

// Runs the whole extraction pipeline over a corpus directory and prints the accuracy table
// that goes into the README.
//
//     swift run CorpusHarness ../../corpus
//     swift run CorpusHarness ../../corpus --markdown > accuracy.md
//
// The corpus itself is never committed — see docs/07-build-plan.md §5. Even with invented
// data, a public folder of photographed forms is a liability.

let arguments = CommandLine.arguments.dropFirst()
let flags = Set(arguments.filter { $0.hasPrefix("--") })
let paths = arguments.filter { !$0.hasPrefix("--") }

guard let path = paths.first else {
    FileHandle.standardError.write(
        Data(
            """
            usage: CorpusHarness <corpus-directory> [--markdown] [--quiet]

              --markdown  print the README table instead of the summary
              --quiet     do not print per-page progress

            """.utf8
        )
    )
    exit(2)
}

let directory = URL(fileURLWithPath: path, isDirectory: true)
let wantsMarkdown = flags.contains("--markdown")
let isQuiet = flags.contains("--quiet") || wantsMarkdown

do {
    let report = try await CorpusRunner().run(directory: directory) { message in
        // Progress goes to stderr so `--markdown > accuracy.md` produces a clean file.
        if !isQuiet { FileHandle.standardError.write(Data((message + "\n").utf8)) }
    }

    guard !report.pages.isEmpty else {
        FileHandle.standardError.write(Data("No pages could be scored.\n".utf8))
        exit(1)
    }

    print(
        wantsMarkdown
            ? CorpusReportFormatter.markdown(report)
            : CorpusReportFormatter.summary(report)
    )
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
