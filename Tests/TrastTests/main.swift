import Foundation

let runner = TestRunner()

LayoutEngineTests.runAll(runner)
WindowCommandCodableTests.runAll(runner)
URLParsingTests.runAll(runner)
FuzzyMatchTests.runAll(runner)
HotkeyDisplayTests.runAll(runner)
VersionCompareTests.runAll(runner)
AppShortcutCodableTests.runAll(runner)
SnippetCodableTests.runAll(runner)
SnippetTemplateTests.runAll(runner)

print()
print(runner.summary)
exit(runner.exitCode)
