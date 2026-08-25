import Foundation

let harness = Harness()

roleTests(harness)
dayRangeTests(harness)
entryLogTests(harness)
fetchWindowTests(harness)

exit(harness.report())
