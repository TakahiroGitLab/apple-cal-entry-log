import Foundation

let harness = Harness()

roleTests(harness)
calendarLabelTests(harness)
dayRangeTests(harness)
entryLogTests(harness)
fetchPlanTests(harness)
mailtoAddressTests(harness)
durationLabelTests(harness)
noteSummaryTests(harness)
locationLabelTests(harness)
linkLabelTests(harness)
dayRangeFromDatesTests(harness)
pinpointTests(harness)
roomLabelTests(harness)

exit(harness.report())
