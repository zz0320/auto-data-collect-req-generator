import Foundation
import ZIPFoundation

public struct XLSXExporter {
    public init() {}

    public func export(validations: [ValidationResult], robots: [RobotProfile], to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .create)
        } catch {
            throw ExportError.cannotCreateArchive
        }
        let accepted = validations.filter { $0.status == .accepted }.map(\.row)
        let resultRows = [ReqConstants.taskHeaders] + accepted.map { row in ReqConstants.taskHeaders.map { row[$0] } }
        let logRows = [["状态", "任务名称", "采集设备", "问题", "提示"]] + validations.map {
            [$0.status.rawValue, $0.row.taskName, $0.row.device, $0.errors.joined(separator: "\n"), $0.warnings.joined(separator: "\n")]
        }
        let robotRows = [["机器人", "末端执行器", "采集模式", "移动能力", "全身能力", "能力摘要"]] + robots.map {
            [$0.name, $0.endEffector, $0.arms.rawValue, $0.mobile ? "是" : "否", $0.wholeBody ? "是" : "否", $0.summary]
        }

        try addText("[Content_Types].xml", contentTypesXML(), to: archive)
        try addText("_rels/.rels", rootRelsXML(), to: archive)
        try addText("xl/workbook.xml", workbookXML(), to: archive)
        try addText("xl/_rels/workbook.xml.rels", workbookRelsXML(), to: archive)
        try addText("xl/styles.xml", stylesXML(), to: archive)
        try addText("xl/worksheets/sheet1.xml", worksheetXML(rows: resultRows, columnWidths: resultColumnWidths), to: archive)
        try addText("xl/worksheets/sheet2.xml", worksheetXML(rows: logRows, columnWidths: logColumnWidths), to: archive)
        try addText("xl/worksheets/sheet3.xml", worksheetXML(rows: robotRows, columnWidths: robotColumnWidths), to: archive)
    }

    private var resultColumnWidths: [Double] {
        [12, 14, 18, 20, 18, 20, 28, 42, 18, 14, 18, 56, 12, 18, 52, 14, 14]
    }

    private var logColumnWidths: [Double] {
        [12, 30, 18, 42, 42]
    }

    private var robotColumnWidths: [Double] {
        [22, 16, 14, 12, 12, 64]
    }

    private func addText(_ path: String, _ text: String, to archive: Archive) throws {
        let data = Data(text.utf8)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
    }

    private func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
    }

    private func rootRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private func workbookXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="生成结果" sheetId="1" r:id="rId1"/>
            <sheet name="校验日志" sheetId="2" r:id="rId2"/>
            <sheet name="机器人配置" sheetId="3" r:id="rId3"/>
          </sheets>
        </workbook>
        """
    }

    private func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
          <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="3">
            <font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Arial"/></font>
            <font><sz val="10"/><color rgb="FF1F2937"/><name val="Arial"/></font>
          </fonts>
          <fills count="3">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
            <fill><patternFill patternType="solid"><fgColor rgb="FF283044"/><bgColor indexed="64"/></patternFill></fill>
          </fills>
          <borders count="2">
            <border><left/><right/><top/><bottom/><diagonal/></border>
            <border>
              <left style="thin"><color rgb="FFD1D5DB"/></left>
              <right style="thin"><color rgb="FFD1D5DB"/></right>
              <top style="thin"><color rgb="FFD1D5DB"/></top>
              <bottom style="thin"><color rgb="FFD1D5DB"/></bottom>
              <diagonal/>
            </border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="3">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
              <alignment horizontal="center" vertical="center" wrapText="1"/>
            </xf>
            <xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">
              <alignment vertical="top" wrapText="1"/>
            </xf>
          </cellXfs>
          <cellStyles count="1">
            <cellStyle name="Normal" xfId="0" builtinId="0"/>
          </cellStyles>
          <dxfs count="0"/>
          <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
        </styleSheet>
        """
    }

    private func worksheetXML(rows: [[String]], columnWidths: [Double]) -> String {
        let columnXML = columnWidths.enumerated().map { index, width in
            #"<col min="\#(index + 1)" max="\#(index + 1)" width="\#(String(format: "%.2f", width))" customWidth="1"/>"#
        }.joined()
        let rowXML = rows.enumerated().map { rowIndex, values in
            let cells = values.enumerated().map { colIndex, value in
                let ref = "\(columnName(colIndex + 1))\(rowIndex + 1)"
                let style = rowIndex == 0 ? 1 : 2
                return #"<c r="\#(ref)" s="\#(style)" t="inlineStr"><is><t>\#(escapeXML(value))</t></is></c>"#
            }.joined()
            return #"<row r="\#(rowIndex + 1)">\#(cells)</row>"#
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetViews>
            <sheetView workbookViewId="0">
              <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
              <selection pane="bottomLeft" activeCell="A2" sqref="A2"/>
            </sheetView>
          </sheetViews>
          <cols>\(columnXML)</cols>
          <sheetData>\(rowXML)</sheetData>
        </worksheet>
        """
    }

    private func columnName(_ index: Int) -> String {
        var index = index
        var result = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            result = String(UnicodeScalar(65 + remainder)!) + result
            index = (index - 1) / 26
        }
        return result
    }

    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

public enum ExportError: Error, LocalizedError {
    case cannotCreateArchive

    public var errorDescription: String? {
        switch self {
        case .cannotCreateArchive: "无法创建 xlsx 文件"
        }
    }
}
