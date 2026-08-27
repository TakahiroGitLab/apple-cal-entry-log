import SwiftUI

/// Lays subviews out in a row, starting a new one whenever the next
/// will not fit.
///
/// For the calendar filter. A scrolling strip would hide calendars
/// behind an edge, and the point of the filter is to see at a glance
/// which of them are being read.
struct WrapLayout: Layout {

    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = arrange(subviews, within: proposal.width ?? .infinity)

        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +)
            + lineSpacing * CGFloat(max(rows.count - 1, 0))

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY

        for row in arrange(subviews, within: bounds.width) {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)

                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )

                x += size.width + spacing
            }

            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, within limit: CGFloat) -> [Row] {

        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = row.indices.isEmpty ? size.width : row.width + spacing + size.width

            if !row.indices.isEmpty, added > limit {
                rows.append(row)
                row = Row()
            }

            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }

        if !row.indices.isEmpty { rows.append(row) }

        return rows
    }
}
