//
//  TreasuryCurve4.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 06/05/2025.
//

//
//  Untitled 4.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

extension Notification.Name {
    static let treasuryChartNeedsRefresh = Notification.Name("TreasuryChartNeedsRefresh")
}

struct DGLineChartRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: TresuryLineViewModel
    let entries: [ChartDataEntry]

    @State private var selectedType: String = "Tous"
    
    @State var firstDate: TimeInterval = 0.0
    @State var lastDate: TimeInterval = 0.0
    let hourSeconds = 3600.0 * 24.0 // one day
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.delegate = context.coordinator
        context.coordinator.chartView = chartView
        initGraph(on: chartView)
        return chartView
    }

    func updateNSView(_ nsView: LineChartView, context: Context) {
        DispatchQueue.main.async {
            // When a day is selected on the chart, avoid recomputing lists/graph
            if self.viewModel.isDaySelectionActive { return }
            self.updateAccount()
            let oldGraph = self.viewModel.dataGraph
            self.updateChartData(for: nsView)
            if oldGraph != self.viewModel.dataGraph {
                self.setData(on: nsView, with: self.viewModel.dataGraph)
            }
        }
    }
    
    static func dismantleNSView(_ nsView: LineChartView, coordinator: Coordinator) {
        let parent = coordinator.parent
        DispatchQueue.main.async {
            // Restore full, unfiltered dataset when leaving the Treasury curve screen
            let allTransactions = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
            var didChange = false
            if ListTransactionsManager.shared.listTransactions != allTransactions {
                ListTransactionsManager.shared.listTransactions = allTransactions
                didChange = true
            }
            if parent.viewModel.listTransactions != allTransactions {
                parent.viewModel.listTransactions = allTransactions
                didChange = true
            }
            if didChange {
                NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
            }
            // Clear selection locks and pending tasks
            parent.viewModel.isDaySelectionActive = false
            coordinator.lastSelectedDayStart = nil
            coordinator.selectionUpdateWorkItem?.cancel()
            coordinator.selectionUpdateWorkItem = nil
            coordinator.deselectWorkItem?.cancel()
            coordinator.deselectWorkItem = nil
            coordinator.fullFilteredCache.removeAll()
            coordinator.chartView = nil
            // Force a chart refresh on the next appearance
            parent.viewModel.dataGraph = []
        }
    }
    
    func updateAccount () {
        // If a day selection is active, do not override the current filtered list
        if viewModel.isDaySelectionActive { return }
        // Charger toutes les transactions d'abord
        let allTransactions = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)

        // Si aucune transaction, vider les listes et sortir
        guard !allTransactions.isEmpty else {
            DispatchQueue.main.async {
                ListTransactionsManager.shared.listTransactions = []
                self.viewModel.listTransactions = []
                NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
            }
            return
        }

        // S'assurer d'un ordre chronologique cohérent (par datePointage)
//        allTransactions.sort { $0.datePointage < $1.datePointage }

        let calendar = Calendar.current

        // Base temporelle cohérente avec updateChartData (minuit du premier/dernier datePointage)
        let firstPointageStart = calendar.startOfDay(for: allTransactions.first!.datePointage)
        let lastPointageStart  = calendar.startOfDay(for: allTransactions.last!.datePointage)

        self.firstDate = firstPointageStart.timeIntervalSince1970
        self.lastDate  = lastPointageStart.timeIntervalSince1970

        // Nombre maximum de jours couverts par les données
        let maxIndex = calendar.dateComponents([.day], from: firstPointageStart, to: lastPointageStart).day ?? 0

        // Offsets demandés par l'UI, bornés pour rester dans la plage
        let selectedStartOffset = max(0, Int(self.viewModel.selectedStart))
        
        let requestedEnd: Int
        if self.viewModel.selectedEnd.isFinite {
            let clamped = max(0, min(self.viewModel.selectedEnd, Double(maxIndex)))
            requestedEnd = Int(clamped)
        } else {
            requestedEnd = maxIndex
        }
        
        let selectedEndOffset = min(maxIndex, max(selectedStartOffset, requestedEnd))

        // Calcul des bornes de dates (sans force unwrap) — intervalle [début, fin)
        guard let startDate = calendar.date(byAdding: .day, value: selectedStartOffset, to: firstPointageStart),
              let endDateExclusive = calendar.date(byAdding: .day, value: selectedEndOffset + 1, to: firstPointageStart) else {
            return
        }

        // Filtrage sur datePointage (cohérent avec l'axe X) — inclut tout le dernier jour
        let filteredTransactions = allTransactions.filter {
            $0.datePointage >= startDate && $0.datePointage < endDateExclusive
        }

        // Mise à jour des listes (manager + viewModel) sur le main thread
        DispatchQueue.main.async {
            ListTransactionsManager.shared.listTransactions = filteredTransactions
            self.viewModel.listTransactions = filteredTransactions
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        }
    }
    
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: DGLineChartRepresentable
        var isUpdating = false
        weak var chartView: LineChartView?
        var refreshObserver: NSObjectProtocol?
        var fullFilteredCache: [EntityTransaction] = []
        var lastSelectedDayStart: Date? = nil
        var selectionUpdateWorkItem: DispatchWorkItem?
        let selectionDebounceInterval: TimeInterval = 0.35
        var deselectWorkItem: DispatchWorkItem?
        let deselectDebounceInterval: TimeInterval = 0.2
        
        init(parent: DGLineChartRepresentable) {
            self.parent = parent
            super.init()
            refreshObserver = NotificationCenter.default.addObserver(forName: .treasuryChartNeedsRefresh, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Skip automatic refresh when a day is selected
                    guard self.parent.viewModel.isDaySelectionActive == false else { return }
                    guard let chartView = self.chartView else { return }
                    self.parent.updateAccount()
                    self.parent.updateChartData(for: chartView)
                    self.parent.setData(on: chartView, with: self.parent.viewModel.dataGraph)
                    self.fullFilteredCache = self.parent.viewModel.listTransactions
                }
            }
        }
        
        deinit {
            if let token = refreshObserver {
                NotificationCenter.default.removeObserver(token)
            }
        }

        public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            // Cancel any pending deselection if a new selection occurs quickly
            self.deselectWorkItem?.cancel()
            self.deselectWorkItem = nil

            if isUpdating { return }
            isUpdating = true
            defer { isUpdating = false }

            // Lock selection early to prevent updateNSView race
            self.parent.viewModel.isDaySelectionActive = true

            let calendar = Calendar.current

            // Build base list from the full dataset constrained to the current range selection
            let allTransactions = ListTransactionsManager.shared.getAllData()
            guard !allTransactions.isEmpty else { return }

            let firstPointageStartAll = calendar.startOfDay(for: allTransactions.first!.datePointage)
            let lastPointageStartAll  = calendar.startOfDay(for: allTransactions.last!.datePointage)
            let maxIndexAll = calendar.dateComponents([.day], from: firstPointageStartAll, to: lastPointageStartAll).day ?? 0

            let selectedStartOffsetAll = max(0, Int(self.parent.viewModel.selectedStart))
            let requestedEndAll: Int = {
                if self.parent.viewModel.selectedEnd.isFinite {
                    let clamped = max(0, min(self.parent.viewModel.selectedEnd, Double(maxIndexAll)))
                    return Int(clamped)
                } else {
                    return maxIndexAll
                }
            }()
            let selectedEndOffsetAll = min(maxIndexAll, max(selectedStartOffsetAll, requestedEndAll))

            guard let rangeStartDate = calendar.date(byAdding: .day, value: selectedStartOffsetAll, to: firstPointageStartAll),
                  let rangeEndExclusive = calendar.date(byAdding: .day, value: selectedEndOffsetAll + 1, to: firstPointageStartAll) else {
                return
            }

            let baseList = allTransactions.filter { tx in
                tx.datePointage >= rangeStartDate && tx.datePointage < rangeEndExclusive
            }

            // Base time aligned to the beginning of the current range
            let baseTime = rangeStartDate.timeIntervalSince1970

            // Compute selected date (quantize to whole days to avoid jitter between two dates)
            let dayIndex = Int(round(highlight.x))
            let selectedTime = baseTime + (Double(dayIndex) * parent.hourSeconds)
            let selectedDate = Date(timeIntervalSince1970: selectedTime)

            // Day bounds: full civil day [00:00, +1 day)
            let dayStart = calendar.startOfDay(for: selectedDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

            // Ignore repeated callbacks within the same day while dragging
            if let last = self.lastSelectedDayStart, last == dayStart {
                return
            }
            self.lastSelectedDayStart = dayStart

            // Debounce updates to avoid continuous refresh while dragging
            self.selectionUpdateWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let selectTransactions = baseList.filter { tx in
                    tx.datePointage >= dayStart && tx.datePointage < dayEnd
                }
                print("selectTransactions (filtered day): \(selectTransactions.count)")
                Task { @MainActor in
                    var didChange = false
                    if ListTransactionsManager.shared.listTransactions != selectTransactions {
                        ListTransactionsManager.shared.listTransactions = selectTransactions
                        didChange = true
                    }
                    if self.parent.viewModel.listTransactions != selectTransactions {
                        self.parent.viewModel.listTransactions = selectTransactions
                        didChange = true
                    }
                    if didChange {
                        NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
                    }
                }
            }
            self.selectionUpdateWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.selectionDebounceInterval, execute: work)
        }
        
        public func chartValueNothingSelected(_ chartView: ChartViewBase)
        {
            // Debounce deselection to avoid toggling to full list on quick double tap / drag jitter
            self.deselectWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Reset last selected day to allow future updates
                self.lastSelectedDayStart = nil
                // Cancel any pending debounced selection update
                self.selectionUpdateWorkItem?.cancel()
                self.selectionUpdateWorkItem = nil

                // Recompute the range-filtered transactions from the full dataset to avoid restoring all data
                let calendar = Calendar.current
                let allTransactions = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
                var restored: [EntityTransaction] = []
                if let first = allTransactions.first, let last = allTransactions.last {
                    let firstPointageStart = calendar.startOfDay(for: first.datePointage)
                    let lastPointageStart  = calendar.startOfDay(for: last.datePointage)
                    let maxIndex = calendar.dateComponents([.day], from: firstPointageStart, to: lastPointageStart).day ?? 0

                    let selectedStartOffset = max(0, Int(self.parent.viewModel.selectedStart))
                    let requestedEnd: Int = {
                        if self.parent.viewModel.selectedEnd.isFinite {
                            let clamped = max(0, min(self.parent.viewModel.selectedEnd, Double(maxIndex)))
                            return Int(clamped)
                        } else {
                            return maxIndex
                        }
                    }()
                    let selectedEndOffset = min(maxIndex, max(selectedStartOffset, requestedEnd))

                    if let startDate = calendar.date(byAdding: .day, value: selectedStartOffset, to: firstPointageStart),
                       let endDateExclusive = calendar.date(byAdding: .day, value: selectedEndOffset + 1, to: firstPointageStart) {
                        restored = allTransactions.filter { tx in
                            tx.datePointage >= startDate && tx.datePointage < endDateExclusive
                        }
                    }
                }

                Task { @MainActor in
                    // Unlock selection so auto-refresh can resume
                    self.parent.viewModel.isDaySelectionActive = false
                    self.fullFilteredCache.removeAll()
                    var didChange = false
                    if ListTransactionsManager.shared.listTransactions != restored {
                        ListTransactionsManager.shared.listTransactions = restored
                        didChange = true
                    }
                    if self.parent.viewModel.listTransactions != restored {
                        self.parent.viewModel.listTransactions = restored
                        didChange = true
                    }
                    if didChange {
                        NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
                    }
                }
            }
            self.deselectWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.deselectDebounceInterval, execute: work)
        }
    }


    func addLimit( on nsView: LineChartView, index: Double, x: Double) {
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yy"
        
        let date2 = Date(timeIntervalSince1970: x )
        if calendar.day(date2) == 1 {
            let dateStr = dateFormatter.string(from: date2)
            let llXAxis = ChartLimitLine(limit: index, label: dateStr)
            llXAxis.lineColor = .linkColor
            llXAxis.valueTextColor = NSColor.controlAccentColor
            llXAxis.valueFont = NSFont.systemFont(ofSize: CGFloat(12.0))
            llXAxis.labelPosition = .rightBottom
            
            let xAxis = nsView.xAxis
            xAxis.addLimitLine(llXAxis)
        }
    }
        
    func setData(on nsView: LineChartView, with data: [DataTresorerie]) {
        guard !data.isEmpty else {
            nsView.data = nil
            nsView.data?.notifyDataChanged()
            nsView.notifyDataSetChanged()
            return
        }

        let filteredData = data.filter {
            $0.x >= viewModel.selectedStart && $0.x <= viewModel.selectedEnd
        }

        if let minX = filteredData.map(\.x).min(),
           let maxX = filteredData.map(\.x).max() {
            nsView.xAxis.axisMinimum = minX
            nsView.xAxis.axisMaximum = maxX
        }
        
        nsView.xAxis.removeAllLimitLines()
        
        var values0 = [ChartDataEntry]()
        var values1 = [ChartDataEntry]()
        var values2 = [ChartDataEntry]()

        for entry in filteredData {
            values0.append(ChartDataEntry(x: entry.x, y: entry.soldeRealise))
            values1.append(ChartDataEntry(x: entry.x, y: entry.soldeEngage))
            values2.append(ChartDataEntry(x: entry.x, y: entry.soldePrevu))
            addLimit(on: nsView, index: entry.x, x: (entry.x * hourSeconds) + firstDate)
        }

        nsView.xAxis.labelCount = 300
        nsView.xAxis.valueFormatter = DateValueFormatter(miniTime: firstDate, interval: hourSeconds)

        // MARK: Marker
        let marker = RectMarker(
            color: #colorLiteral(red: 0.921431005, green: 0.9214526415, blue: 0.9214410186, alpha: 1),
            font: NSFont.systemFont(ofSize: 12.0),
            insets: NSEdgeInsets(top: 8.0, left: 8.0, bottom: 20.0, right: 8.0)
        )
        marker.minimumSize = CGSize(width: 80.0, height: 40.0)
        marker.chartView = nsView
        nsView.marker = marker
        marker.miniTime = firstDate
        marker.interval = hourSeconds

        // MARK: Datasets
        
        let label = [String(localized:"Planned"),
                     String(localized:"In progress"),
                     String(localized:"Executed")   ]
        let set1 = setDataSet(values: values0, label: label[0], color: #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1))
        let set2 = setDataSet(values: values1, label: label[1], color: #colorLiteral(red: 0.5058823824, green: 0.3372549117, blue: 0.06666667014, alpha: 1))
        let set3 = setDataSet(values: values2, label: label[2], color: #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))

        let dataSet = LineChartData(dataSets: [set1, set2, set3])
        dataSet.setValueTextColor(.black)
        dataSet.setValueFont(NSFont(name: "HelveticaNeue-Light", size: CGFloat(9.0))!)

        nsView.data = dataSet
    }
    
    func setDataSet (values : [ChartDataEntry], label: String, color : NSColor) -> LineChartDataSet
    {
        var dataSet =  LineChartDataSet()
        
        let pFormatter = NumberFormatter()
        pFormatter.numberStyle = .currency
        pFormatter.maximumFractionDigits = 2
        
        dataSet = LineChartDataSet(entries: values, label: label)
        dataSet.axisDependency = .left
        dataSet.mode = .stepped
        dataSet.valueTextColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        dataSet.lineWidth = 2.0
        
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = true
        dataSet.valueFormatter = DefaultValueFormatter(formatter: pFormatter  )
        
        dataSet.drawFilledEnabled = false //true
        dataSet.fillAlpha = 0.26
        dataSet.fillColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
        dataSet.highlightColor = #colorLiteral(red: 0.4513868093, green: 0.9930960536, blue: 1, alpha: 1)
        dataSet.highlightLineWidth = 4.0
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.formSize = 15.0
        dataSet.colors = [color]
        return dataSet
    }
    
    func initGraph(on chartView: LineChartView) {
        
        // MARK: General
        chartView.dragEnabled = true
        chartView.setScaleEnabled(false)
        chartView.doubleTapToZoomEnabled = false
        chartView.pinchZoomEnabled = false
        chartView.drawGridBackgroundEnabled = false
        chartView.highlightPerDragEnabled = true
        chartView.highlightPerTapEnabled = true
        chartView.noDataText = String(localized:"No chart data available.")
        
        chartView.scaleYEnabled = false
        chartView.scaleXEnabled = false
        
        // MARK: xAxis
        let xAxis                             = chartView.xAxis
        xAxis.labelPosition                   = .bottom
        xAxis.labelFont                       = NSFont(name : "HelveticaNeue-Light", size : CGFloat(10.0))!
        xAxis.drawAxisLineEnabled             = true
        xAxis.drawGridLinesEnabled            = true
        xAxis.drawLimitLinesBehindDataEnabled = true
        xAxis.avoidFirstLastClippingEnabled   = false
        xAxis.granularity                     = 1.0
        xAxis.spaceMin                        = xAxis.granularity / 5
        xAxis.spaceMax                        = xAxis.granularity / 5
        xAxis.labelRotationAngle              = -45.0
        xAxis.labelTextColor                  = .labelColor
                
        // MARK: leftAxis
        let leftAxis                  = chartView.leftAxis
        leftAxis.labelPosition        = .outsideChart
        leftAxis.labelFont            = NSFont(name : "HelveticaNeue-Light", size : CGFloat(12.0))!
        leftAxis.drawGridLinesEnabled = true
        leftAxis.granularityEnabled   = true
        leftAxis.yOffset              = -9.0
        leftAxis.labelTextColor       = .labelColor
        
        // MARK: rightAxis
        chartView.rightAxis.enabled = false
        
        // MARK: legend
        let legend                 = chartView.legend
        legend.enabled             = true
        legend.form                = .square
        legend.drawInside          = false
        legend.orientation         = .horizontal
        legend.verticalAlignment   = .bottom
        legend.horizontalAlignment = .left
        
        // MARK: description
        chartView.chartDescription.enabled = false
    }
    
    func updateChartData(for nsView: LineChartView) {
        
        let transactions = viewModel.listTransactions
        
        guard !transactions.isEmpty else {
            // Reset graph when no transactions
            viewModel.dataGraph = []
            return
        }

        var dataTresorerie = DataTresorerie()
        var dataGraph : [DataTresorerie] = []

        let initAccount = InitAccountManager.shared.getAllData()
        var soldeRealise = initAccount?.realise ?? 0
        var soldePrevu   = initAccount?.prevu ?? 0
        var soldeEngage  = initAccount?.engage ?? 0

        var prevu  = 0.0
        var engage = 0.0

        let calendar = Calendar.current
        
        // Normalize firstDate to midnight using Calendar
        firstDate = calendar.startOfDay(for: transactions.first!.datePointage).timeIntervalSince1970
        let minValue = Double(firstDate / hourSeconds)
        let maxValue = Double(calendar.startOfDay(for: transactions.last!.datePointage).timeIntervalSince1970 / hourSeconds)
//        let minIndex = 0
        let maxIndex = Int((maxValue - minValue))
        
        // Clamp selection safely to avoid Int overflow and keep within data bounds
        let selectedStartOffset: Int = {
            let s = viewModel.selectedStart
            guard s.isFinite else { return 0 }
            if s <= 0 { return 0 }
            if s >= Double(maxIndex) { return maxIndex }
            return Int(floor(s))
        }()

        let selectedEndOffset: Int = {
            let e = viewModel.selectedEnd
            if !e.isFinite { return maxIndex }
            if e <= Double(selectedStartOffset) { return selectedStartOffset }
            if e >= Double(maxIndex) { return maxIndex }
            return Int(floor(e))
        }()

        let grouped = Dictionary(grouping: transactions, by: { calendar.startOfDay(for: $0.datePointage) })

        for offset in selectedStartOffset...selectedEndOffset {
            let dayDate = Date(timeIntervalSince1970: firstDate + Double(offset) * hourSeconds)
            let dayTransactions = grouped[dayDate] ?? []

            for tx in dayTransactions {
                switch tx.status?.type {
                case .planned:
                    prevu += tx.amount
                case .inProgress:
                    engage += tx.amount
                case .executed:
                    soldeRealise += tx.amount
                case .none:
                    let _ = 0.0
                }
            }

            soldePrevu  += soldeRealise + engage + prevu
            soldeEngage += soldeRealise + engage
            
            prevu  = 0.0
            engage = 0.0

//            printTag("n°\(offset)    \(soldePrevu)  \(soldeEngage)  \(soldeRealise)", flag: true)
            
            dataTresorerie = DataTresorerie(
                x            : Double(offset),
                soldeRealise : soldeRealise,
                soldeEngage  : soldeEngage,
                soldePrevu   : soldePrevu
            )
            dataGraph.append(dataTresorerie)
        }
        if dataGraph.count != viewModel.dataGraph.count {
            viewModel.dataGraph = dataGraph
        } else {
            var isDifferent = false
            for (a, b) in zip(dataGraph, viewModel.dataGraph) {
                if a != b {
                    isDifferent = true
                    break
                }
            }
            if isDifferent {
                viewModel.dataGraph = dataGraph
            }
        }
    }
    
//    func calcStartEndDate() -> (Date, Date) {
        
//        let calendar = Calendar.current
//
//        var date2 = Date(timeIntervalSince1970: ((mySlider.start * self.oneDay) + self.firstDate))
//        self.startDate = calendar.startOfDay(for: date2)
//
//        date2 = Date(timeIntervalSince1970: ((mySlider.end * self.oneDay) + self.firstDate))
//        self.endDate = calendar.endOfDay(date: date2 )
//        return (startDate, endDate)
//    }

}

