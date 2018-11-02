import Foundation
import TelegramCore
import Postbox
import Display

private struct TableSide: OptionSet {
    var rawValue: Int32 = 0
    
    static let top = TableSide(rawValue: 1 << 0)
    static let left = TableSide(rawValue: 1 << 1)
    static let right = TableSide(rawValue: 1 << 2)
    static let bottom = TableSide(rawValue: 1 << 3)
    
    var uiRectCorner: UIRectCorner {
        var corners: UIRectCorner = []
        if self.contains(.top) && self.contains(.left) {
            corners.insert(.topLeft)
        }
        if self.contains(.top) && self.contains(.right) {
            corners.insert(.topRight)
        }
        if self.contains(.bottom) && self.contains(.left) {
            corners.insert(.bottomLeft)
        }
        if self.contains(.bottom) && self.contains(.right) {
            corners.insert(.bottomRight)
        }
        return corners
    }
}

private extension TableHorizontalAlignment {
    var textAlignment: NSTextAlignment {
        switch self {
            case .left:
                return .left
            case .center:
                return .center
            case .right:
                return .right
        }
    }
}

private struct TableCellPosition {
    let row: Int
    let column: Int
}

private struct InstantPageTableCellItem {
    let position: TableCellPosition
    let cell: InstantPageTableCell
    let frame: CGRect
    let filled: Bool
    let textItem: InstantPageTextItem?
    let additionalItems: [InstantPageItem]
    let adjacentSides: TableSide
    
    func withRowHeight(_ height: CGFloat) -> InstantPageTableCellItem {
        var frame = self.frame
        frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: height)
        return InstantPageTableCellItem(position: position, cell: self.cell, frame: frame, filled: self.filled, textItem: self.textItem, additionalItems: self.additionalItems, adjacentSides: self.adjacentSides)
    }
    
    func withRTL(_ totalWidth: CGFloat) -> InstantPageTableCellItem {
        var frame = self.frame
        frame = CGRect(x: totalWidth - frame.minX - frame.width, y: frame.minY, width: frame.width, height: frame.height)
        var adjacentSides = self.adjacentSides
        if adjacentSides.contains(.left) {
            adjacentSides.remove(.left)
            adjacentSides.insert(.right)
        }
        if adjacentSides.contains(.right) {
            adjacentSides.remove(.right)
            adjacentSides.insert(.left)
        }
        return InstantPageTableCellItem(position: position, cell: self.cell, frame: frame, filled: self.filled, textItem: self.textItem, additionalItems: self.additionalItems, adjacentSides: adjacentSides)
    }
    
    var verticalAlignment: TableVerticalAlignment {
        return self.cell.verticalAlignment
    }
    
    var colspan: Int {
        return self.cell.colspan > 1 ? Int(clamping: self.cell.colspan) : 1
    }
    
    var rowspan: Int {
        return self.cell.rowspan > 1 ? Int(clamping: self.cell.rowspan) : 1
    }
}

private let tableCellInsets = UIEdgeInsetsMake(14.0, 12.0, 14.0, 12.0)
private let tableBorderWidth: CGFloat = 1.0
private let tableCornerRadius: CGFloat = 5.0

final class InstantPageTableItem: InstantPageItem {
    var frame: CGRect
    let totalWidth: CGFloat
    let horizontalInset: CGFloat
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = true
    
    let theme: InstantPageTheme
    
    let rtl: Bool
    fileprivate let cells: [InstantPageTableCellItem]
    private let borderWidth: CGFloat
    
    fileprivate init(frame: CGRect, totalWidth: CGFloat, horizontalInset: CGFloat, borderWidth: CGFloat, theme: InstantPageTheme, cells: [InstantPageTableCellItem], rtl: Bool) {
        self.frame = frame
        self.totalWidth = totalWidth
        self.horizontalInset = horizontalInset
        self.borderWidth = borderWidth
        self.theme = theme
        self.cells = cells
        self.rtl = rtl
    }
    
    func drawInTile(context: CGContext) {
        for cell in self.cells {
            context.saveGState()
            context.translateBy(x: cell.frame.minX, y: cell.frame.minY)
            if cell.filled {
                let bounds = CGRect(origin: CGPoint(), size: cell.frame.size)
                context.setFillColor(self.theme.tableHeaderColor.cgColor)
                if !cell.adjacentSides.isEmpty {
                    let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: cell.adjacentSides.uiRectCorner, cornerRadii: CGSize(width: tableCornerRadius, height: tableCornerRadius))
                    context.addPath(path.cgPath)
                    context.fillPath()
                } else {
                    context.fill(bounds)
                }
            }
            if let textItem = cell.textItem {
                textItem.drawInTile(context: context)
            }
            context.restoreGState()
            if self.borderWidth > 0.0 {
                context.setStrokeColor(self.theme.tableBorderColor.cgColor)
                context.setLineWidth(borderWidth)
                if !cell.adjacentSides.contains(.right) {
                    context.move(to: CGPoint(x: cell.frame.maxX + borderWidth / 2.0, y: cell.frame.minY))
                    context.addLine(to: CGPoint(x: cell.frame.maxX + borderWidth / 2.0, y: cell.frame.maxY + borderWidth))
                    context.strokePath()
                }
                if !cell.adjacentSides.contains(.bottom) {
                    context.move(to: CGPoint(x: cell.frame.minX, y: cell.frame.maxY + borderWidth / 2.0))
                    context.addLine(to: CGPoint(x: cell.frame.maxX, y: cell.frame.maxY + borderWidth / 2.0))
                    context.strokePath()
                }
            }
        }
        
        if self.borderWidth > 0.0 {
            context.setStrokeColor(self.theme.tableBorderColor.cgColor)
            context.setLineWidth(borderWidth)
            let path = UIBezierPath(roundedRect: CGRect(x: borderWidth / 2.0, y: borderWidth / 2.0, width: self.totalWidth - borderWidth, height: self.frame.height - borderWidth), cornerRadius: tableCornerRadius)
            
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageTableNode(item: self, account: account, strings: strings, theme: theme)
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageTableNode {
            return node.item === self
        }
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        for cell in self.cells {
            if let item = cell.textItem, item.selectable, item.frame.insetBy(dx: -tableCellInsets.left, dy: -tableCellInsets.top).contains(point.offsetBy(dx: -cell.frame.minX - self.horizontalInset, dy: -cell.frame.minY)) {
                let rects = item.linkSelectionRects(at: point.offsetBy(dx: -cell.frame.minX - self.horizontalInset - item.frame.minX, dy: -cell.frame.minY - item.frame.minY))
                return rects.map { $0.offsetBy(dx: cell.frame.minX + item.frame.minX + self.horizontalInset, dy: cell.frame.minY + item.frame.minY) }
            }
        }
        return []
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        for cell in self.cells {
            if let item = cell.textItem, item.selectable, item.frame.insetBy(dx: -tableCellInsets.left, dy: -tableCellInsets.top).contains(location.offsetBy(dx: -cell.frame.minX - self.horizontalInset, dy: -cell.frame.minY)) {
                return (item, cell.frame.origin.offsetBy(dx: self.horizontalInset, dy: 0.0))
            }
        }
        return nil
    }
}

private final class InstantPageTableNodeParameters: NSObject {
    let item: InstantPageTableItem
    
    init(item: InstantPageTableItem) {
        self.item = item
        super.init()
    }
}

final class InstantPageTableContentNode: ASDisplayNode {
    private let item: InstantPageTableItem
    
    init(item: InstantPageTableItem, account: Account, strings: PresentationStrings, theme: InstantPageTheme) {
        self.item = item
        super.init()
        
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        
        for cell in self.item.cells {
            for item in cell.additionalItems {
                if item.wantsNode {
                    if let node = item.node(account: account, strings: strings, theme: theme, openMedia: { _ in }, openPeer: { _ in }, openUrl: { _ in}, updateWebEmbedHeight: { _, _ in }) {
                        node.frame = item.frame.offsetBy(dx: cell.frame.minX, dy: cell.frame.minY)
                        self.addSubnode(node)
                    }
                }
            }
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageTableNodeParameters(item: self.item)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageTableNodeParameters {
            parameters.item.drawInTile(context: context)
        }
    }
}

final class InstantPageTableNode: ASScrollNode, InstantPageNode {
    let item: InstantPageTableItem
    let contentNode: InstantPageTableContentNode
    
    var contentOffset: CGPoint {
        return self.view.contentOffset
    }
    
    init(item: InstantPageTableItem, account: Account, strings: PresentationStrings, theme: InstantPageTheme) {
        self.item = item
        self.contentNode = InstantPageTableContentNode(item: item, account: account, strings: strings, theme: theme)
        super.init()
        
        self.isOpaque = false
        self.contentNode.frame = CGRect(x: item.horizontalInset, y: 0.0, width: item.totalWidth, height: item.frame.height)
        self.view.contentSize = CGSize(width: item.totalWidth + item.horizontalInset * 2.0, height: item.frame.height)
        if item.rtl {
            self.view.contentOffset = CGPoint(x: self.view.contentSize.width - item.frame.width, y: 0.0)
        }
        self.view.alwaysBounceVertical = false
        self.view.showsHorizontalScrollIndicator = false
        self.view.showsVerticalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, *) {
            self.view.contentInsetAdjustmentBehavior = .never
        }
        self.addSubnode(self.contentNode)
        
        self.view.interactiveTransitionGestureRecognizerTest = { [weak self] point -> Bool in
            if let strongSelf = self {
                if strongSelf.view.contentOffset.x < 1.0 {
                    return false
                } else {
                    return point.x - strongSelf.view.contentOffset.x > 30.0
                }
            } else {
                return false
            }
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
}

private struct TableRow {
    var minColumnWidths: [Int : CGFloat]
    var maxColumnWidths: [Int : CGFloat]
}

private func offsetForHorizontalAlignment(_ alignment: TableHorizontalAlignment, width: CGFloat, boundingWidth: CGFloat, insets: UIEdgeInsets) -> CGFloat {
    switch alignment {
        case .left:
            return insets.left
        case .center:
            return (boundingWidth - width) / 2.0
        case .right:
            return boundingWidth - width - insets.right
    }
}

private func offestForVerticalAlignment(_ verticalAlignment: TableVerticalAlignment, height: CGFloat, boundingHeight: CGFloat, insets: UIEdgeInsets) -> CGFloat {
    switch verticalAlignment {
        case .top:
            return insets.top
        case .middle:
            return (boundingHeight - height) / 2.0
        case .bottom:
            return boundingHeight - height - insets.bottom
    }
}

func layoutTableItem(rtl: Bool, rows: [InstantPageTableRow], styleStack: InstantPageTextStyleStack, theme: InstantPageTheme, bordered: Bool, striped: Bool, boundingWidth: CGFloat, horizontalInset: CGFloat, media: [MediaId: Media], webpage: TelegramMediaWebpage) -> InstantPageTableItem {
    if rows.count == 0 {
        return InstantPageTableItem(frame: CGRect(), totalWidth: 0.0, horizontalInset: 0.0,  borderWidth: 0.0, theme: theme, cells: [], rtl: rtl)
    }

    let borderWidth = bordered ? tableBorderWidth : 0.0
    let totalCellPadding = tableCellInsets.left + tableCellInsets.right
    let cellWidthLimit = boundingWidth - totalCellPadding
    var tableRows: [TableRow] = []
    var columnCount: Int = 0
    
    var columnSpans: [Range<Int> : (CGFloat, CGFloat)] = [:]
    
    for row in rows {
        var minColumnWidths: [Int : CGFloat] = [:]
        var maxColumnWidths: [Int : CGFloat] = [:]
        var i: Int = 0
        for cell in row.cells {
            var minCellWidth: CGFloat = 1.0
            var maxCellWidth: CGFloat = 1.0
            if let text = cell.text {
                if let shortestTextItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: cellWidthLimit, offset: CGPoint(), media: media, webpage: webpage, minimizeWidth: true).0.first as? InstantPageTextItem {
                    minCellWidth = shortestTextItem.effectiveWidth() + totalCellPadding
                }
                
                if let longestTextItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: cellWidthLimit, offset: CGPoint(), media: media, webpage: webpage).0.first as? InstantPageTextItem {
                    maxCellWidth = longestTextItem.effectiveWidth() + totalCellPadding
                }
            }
            if cell.colspan > 1 {
                minColumnWidths[i] = 1.0
                maxColumnWidths[i] = 1.0
                
                let spanRange = i ..< i + Int(cell.colspan)
                if let (minSpanWidth, maxSpanWidth) = columnSpans[spanRange] {
                    columnSpans[spanRange] = (max(minSpanWidth, minCellWidth), max(maxSpanWidth, maxCellWidth))
                } else {
                    columnSpans[spanRange] = (minCellWidth, maxCellWidth)
                }
            } else {
                minColumnWidths[i] = minCellWidth
                maxColumnWidths[i] = maxCellWidth
            }
            i += cell.colspan > 1 ? Int(clamping: cell.colspan) : 1
        }
        tableRows.append(TableRow(minColumnWidths: minColumnWidths, maxColumnWidths: maxColumnWidths))
        columnCount = max(columnCount, row.cells.count)
    }
    
    let maxContentWidth = boundingWidth - borderWidth * CGFloat(columnCount - 1)
    var availableWidth = maxContentWidth
    var minColumnWidths: [Int : CGFloat] = [:]
    var maxColumnWidths: [Int : CGFloat] = [:]
    var maxTotalWidth: CGFloat = 0.0
    for i in 0 ..< columnCount {
        var minWidth: CGFloat = 1.0
        var maxWidth: CGFloat = 1.0
        for row in tableRows {
            if let columnWidth = row.minColumnWidths[i] {
                minWidth = max(minWidth, columnWidth)
            }
            if let columnWidth = row.maxColumnWidths[i] {
                maxWidth = max(maxWidth, columnWidth)
            }
        }
        minColumnWidths[i] = minWidth
        maxColumnWidths[i] = maxWidth
        availableWidth -= minWidth
        maxTotalWidth += maxWidth
    }
    
    for (range, span) in columnSpans {
        let (minSpanWidth, maxSpanWidth) = span
        
        var minWidth: CGFloat = 0.0
        var maxWidth: CGFloat = 0.0
        for i in range {
            if let columnWidth = minColumnWidths[i] {
                minWidth += columnWidth
            }
            if let columnWidth = maxColumnWidths[i] {
                maxWidth += columnWidth
            }
        }
        
        if minWidth < minSpanWidth {
            let delta = minSpanWidth - minWidth
            for i in range {
                if let columnWidth = minColumnWidths[i] {
                    let growth = round(delta / CGFloat(range.count))
                    minColumnWidths[i] = columnWidth + growth
                    availableWidth -= growth
                }
            }
        }
        
        if maxWidth < maxSpanWidth {
            let delta = maxSpanWidth - maxWidth
            for i in range {
                if let columnWidth = maxColumnWidths[i] {
                    let growth = round(delta / CGFloat(range.count))
                    maxColumnWidths[i] = columnWidth + growth
                    maxTotalWidth += growth
                }
            }
        }
    }
    
    var totalWidth = maxTotalWidth
    var finalColumnWidths: [Int : CGFloat] = [:]
    let widthToDistribute: CGFloat
    if availableWidth > 0 {
        widthToDistribute = availableWidth
        finalColumnWidths = minColumnWidths
    } else {
        widthToDistribute = maxContentWidth - maxTotalWidth
        finalColumnWidths = maxColumnWidths
    }
    
    if widthToDistribute > 0.0 {
        for i in 0 ..< finalColumnWidths.count {
            var width = finalColumnWidths[i]!
            let maxWidth = maxColumnWidths[i]!
            let growth = round(widthToDistribute * maxWidth / maxTotalWidth)
            width += growth
            availableWidth -= growth
            finalColumnWidths[i] = width
        }
        totalWidth = boundingWidth
    }
    
    var finalizedCells: [InstantPageTableCellItem] = []
    var origin: CGPoint = CGPoint()
    var totalHeight: CGFloat = 0.0
    var rowHeights: [Int : CGFloat] = [:]
    
    var deferredCells: [Int : [(Int, InstantPageTableCellItem)]] = [:]
    
    for i in 0 ..< rows.count {
        let row = rows[i]
        var maxCellHeight: CGFloat = 1.0
        origin.x = 0.0
        
        var k: Int = 0
        var rowCells: [InstantPageTableCellItem] = []
        
        if let cells = deferredCells[i] {
            for colAndCell in cells {
                let cell = colAndCell.1
                if cell.position.column == k {
                    for j in 0 ..< cell.colspan {
                        if let width = finalColumnWidths[k + j] {
                            origin.x += width
                        }
                    }
                    origin.x += borderWidth * CGFloat(cell.colspan)
                    k += cell.colspan
                } else {
                    break
                }
            }
        }
        
        for cell in row.cells {
            var cellWidth: CGFloat = 0.0
            let colspan: Int = cell.colspan > 1 ? Int(clamping: cell.colspan) : 1
            let rowspan: Int = cell.rowspan > 1 ? Int(clamping: cell.rowspan) : 1
            for j in 0 ..< colspan {
                if let width = finalColumnWidths[k + j] {
                    cellWidth += width
                }
            }
            cellWidth += borderWidth * CGFloat(colspan - 1)
            
            var item: InstantPageTextItem?
            var additionalItems: [InstantPageItem] = []
            var cellHeight: CGFloat?
            if let text = cell.text {
                let (items, _) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: cellWidth - totalCellPadding, offset: CGPoint(), media: media, webpage: webpage)
                if let textItem = items.first as? InstantPageTextItem {
                    textItem.alignment = cell.alignment.textAlignment
                    textItem.frame = textItem.frame.offsetBy(dx: tableCellInsets.left, dy: 0.0)
                    cellHeight = ceil(textItem.frame.height) + tableCellInsets.top + tableCellInsets.bottom
                    
                    item = textItem
                }
                for var item in items where !(item is InstantPageTextItem) {
                    let offset = offsetForHorizontalAlignment(cell.alignment, width: item.frame.width, boundingWidth: cellWidth, insets: tableCellInsets)
                    item.frame = item.frame.offsetBy(dx: offset, dy: 0.0)
                    
                    let height = ceil(item.frame.height) + tableCellInsets.top + tableCellInsets.bottom - 10.0
                    if let currentCellHeight = cellHeight {
                        cellHeight = max(currentCellHeight, height)
                    } else {
                        cellHeight = height
                    }
                    
                    additionalItems.append(item)
                }
            }
            var filled = cell.header
            if !filled && striped {
                filled = i % 2 == 0
            }
            var adjacentSides: TableSide = []
            if i == 0 {
                adjacentSides.insert(.top)
            }
            if i == rows.count - 1 {
                adjacentSides.insert(.bottom)
            }
            if k == 0 {
                adjacentSides.insert(.left)
            }
            if k + colspan == columnCount {
                adjacentSides.insert(.right)
            }
            let rowCell = InstantPageTableCellItem(position: TableCellPosition(row: i, column: k), cell: cell, frame: CGRect(x: origin.x, y: origin.y, width: cellWidth, height: 10.0), filled: filled, textItem: item, additionalItems: additionalItems, adjacentSides: adjacentSides)
            if rowspan == 1 {
                rowCells.append(rowCell)
                if let cellHeight = cellHeight {
                    maxCellHeight = max(maxCellHeight, cellHeight)
                }
            } else {
                for j in i ..< i + rowspan {
                    if deferredCells[j] == nil {
                        deferredCells[j] = [(k, rowCell)]
                    } else {
                        deferredCells[j]!.append((k, rowCell))
                    }
                }
            }

            k += colspan
            origin.x += cellWidth + borderWidth
        }
        
        let finalizeCell: (InstantPageTableCellItem, inout [InstantPageTableCellItem], CGFloat) -> Void = { cell, cells, height in
            let updatedCell = cell.withRowHeight(height)
            if let textItem = updatedCell.textItem {
                let offset = offestForVerticalAlignment(cell.verticalAlignment, height: textItem.frame.height, boundingHeight: height, insets: tableCellInsets)
                updatedCell.textItem!.frame = textItem.frame.offsetBy(dx: 0.0, dy: offset)
                
                for var item in updatedCell.additionalItems {
                    item.frame = item.frame.offsetBy(dx: 0.0, dy: offset)
                }
            } else {
                for var item in updatedCell.additionalItems {
                    let offset = offestForVerticalAlignment(cell.verticalAlignment, height: item.frame.height, boundingHeight: height, insets: tableCellInsets)
                    item.frame = item.frame.offsetBy(dx: 0.0, dy: offset)
                }
            }
            cells.append(updatedCell)
        }
        
        for cell in rowCells {
            finalizeCell(cell, &finalizedCells, maxCellHeight)
        }

        rowHeights[i] = maxCellHeight
        
        var completedSpans = [Int : Set<Int>]()
        if let cells = deferredCells[i] {
            for colAndCell in cells {
                let cell = colAndCell.1
                let utmostRow = cell.position.row + cell.rowspan - 1
                if rowHeights[utmostRow] == nil {
                    continue
                }
                
                var cellHeight: CGFloat = 0.0
                for k in cell.position.row ..< utmostRow + 1 {
                    if let height = rowHeights[k] {
                        cellHeight += height
                    }
                    
                    if completedSpans[k] == nil {
                        var set = Set<Int>()
                        set.insert(colAndCell.0)
                        completedSpans[k] = set
                    } else {
                        completedSpans[k]!.insert(colAndCell.0)
                    }
                }
                cellHeight += borderWidth * CGFloat(cell.rowspan - 1)
                
                finalizeCell(cell, &finalizedCells, cellHeight)
            }
        }
        
        if !completedSpans.isEmpty {
            deferredCells = deferredCells.reduce([Int : [(Int, InstantPageTableCellItem)]]()) { (current, rowAndValue) in
                var result = current
                let cells = rowAndValue.value.filter({ column, cell in
                    if let completedSpansInRow = completedSpans[rowAndValue.key] {
                        return !completedSpansInRow.contains(column)
                    } else {
                        return true
                    }
                })
                if !cells.isEmpty {
                    result[rowAndValue.key] = cells
                }
                return result
            }
        }
        
        totalHeight += maxCellHeight
        origin.y += maxCellHeight + borderWidth
    }
    totalHeight += borderWidth * CGFloat(rows.count - 1)
    
    if rtl {
        finalizedCells = finalizedCells.map { $0.withRTL(totalWidth) }
    }
    
    return InstantPageTableItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth + horizontalInset * 2.0, height: totalHeight), totalWidth: totalWidth, horizontalInset: horizontalInset, borderWidth: borderWidth, theme: theme, cells: finalizedCells, rtl: rtl)
}
