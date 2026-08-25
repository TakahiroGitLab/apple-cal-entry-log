import Foundation

let harness = Harness()

roleTests(harness)
dayRangeTests(harness)
entryLogTests(harness)
fetchPlanTests(harness)
mailtoAddressTests(harness)

exit(harness.report())
