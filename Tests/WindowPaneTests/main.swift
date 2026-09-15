import Foundation

let runner = TestRunner()

LayoutEngineTests.runAll(runner)
WindowCommandCodableTests.runAll(runner)
URLParsingTests.runAll(runner)
FuzzyMatchTests.runAll(runner)
VersionCompareTests.runAll(runner)
AppShortcutCodableTests.runAll(runner)
SnippetCodableTests.runAll(runner)

print()
print(runner.summary)
exit(runner.exitCode)
