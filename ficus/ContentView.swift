//
//  ContentView.swift
//  ficus
//
//  Created by גיא אינהורן on 04/10/2025.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - TimeInterval Extension
private extension TimeInterval {
    var mmssString: String {
        let totalSeconds = Int(self.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Countdown & Count Up Timer Logic
final class CountdownTimer: ObservableObject {
    @Published private(set) var timeLeft: TimeInterval = 30
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var isRunning = false

    private var timer: Timer?
    private var endTime: Date?
    private var durationAtPause: TimeInterval?
    private var initialDuration: TimeInterval = 30
    private var countUp: Bool = false
    
    // For counting up
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    var onFinished: (() -> Void)?

    func start(duration: TimeInterval, countUp: Bool = false) {
        guard !isRunning else { return }
        self.initialDuration = duration
        self.countUp = countUp
        
        if countUp {
            self.elapsedTime = 0
            self.accumulatedTime = 0
            self.startTime = Date()
        } else {
            if let pausedTime = durationAtPause {
                self.timeLeft = pausedTime
                self.endTime = Date().addingTimeInterval(pausedTime)
                durationAtPause = nil
            } else {
                self.timeLeft = duration
                self.endTime = Date().addingTimeInterval(duration)
            }
        }
        self.isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func pause() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        if countUp {
            if let start = startTime {
                accumulatedTime += Date().timeIntervalSince(start)
            }
            startTime = nil
        } else {
            durationAtPause = timeLeft
        }
    }

    func resume() {
        guard !isRunning else { return }
        self.isRunning = true
        
        if countUp {
            self.startTime = Date()
        } else {
            if let pausedTime = durationAtPause {
                self.endTime = Date().addingTimeInterval(pausedTime)
                durationAtPause = nil
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    @discardableResult
    func stop() -> TimeInterval {
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        let elapsed: TimeInterval
        if countUp {
            var total = accumulatedTime
            if let start = startTime {
                total += Date().timeIntervalSince(start)
            }
            elapsed = total
            startTime = nil
            accumulatedTime = 0
            elapsedTime = 0
        } else {
            elapsed = initialDuration - timeLeft
            durationAtPause = nil
            timeLeft = initialDuration
        }
        return elapsed
    }

    func reset(duration: TimeInterval) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        durationAtPause = nil
        timeLeft = duration
        elapsedTime = 0
        accumulatedTime = 0
        startTime = nil
    }

    private func update() {
        if countUp {
            var total = accumulatedTime
            if let start = startTime {
                total += Date().timeIntervalSince(start)
            }
            elapsedTime = total
        } else {
            guard let endTime = endTime else { return }
            let remaining = endTime.timeIntervalSince(Date())
            if remaining <= 0 {
                timeLeft = 0
                timer?.invalidate()
                timer = nil
                isRunning = false
                onFinished?()
            } else {
                timeLeft = remaining
            }
        }
        objectWillChange.send()
    }
}

// MARK: - Tree Counter Storage with Midnight Reset
class TreeCounter: ObservableObject {
    @Published private(set) var treesToday: Int = 0
    
    private let defaults = UserDefaults.standard
    private let treeCountKey = "treeCount"
    private let lastDateKey = "lastCountDate"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadTodayCount()
        setupMidnightObserver()
    }
    
    private func setupMidnightObserver() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self?.loadTodayCount()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadTodayCount() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = defaults.object(forKey: lastDateKey) as? Date {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            
            if Calendar.current.isDate(today, inSameDayAs: lastDay) {
                treesToday = defaults.integer(forKey: treeCountKey)
            } else {
                treesToday = 0
                saveCount()
            }
        } else {
            treesToday = 0
            saveCount()
        }
    }
    
    func incrementTree() {
        treesToday += 1
        saveCount()
    }
    
    private func saveCount() {
        defaults.set(treesToday, forKey: treeCountKey)
        defaults.set(Date(), forKey: lastDateKey)
    }
}

// MARK: - Draggable Tree Container
struct DraggableTreeContainer: View {
    let imageName: String
    let initialOffset: CGSize
    
    @State private var currentOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    @State private var stretchScaleX: CGFloat = 1.0
    @State private var stretchScaleY: CGFloat = 1.0
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 48)
            .scaleEffect(x: stretchScaleX, y: stretchScaleY, anchor: .bottom)
            .offset(
                x: initialOffset.width + currentOffset.width + dragOffset.width,
                y: initialOffset.height + currentOffset.height + dragOffset.height
            )
            .shadow(
                color: .black.opacity(isDragging ? 0.15 : 0.0),
                radius: isDragging ? 12 : 0,
                x: 0,
                y: isDragging ? 15 : 0
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.4)) {
                                isDragging = true
                                stretchScaleY = 1.35
                                stretchScaleX = 0.75
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                if isDragging {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        stretchScaleY = 1.10
                                        stretchScaleX = 0.95
                                    }
                                }
                            }
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            currentOffset.width += value.translation.width
                            currentOffset.height += value.translation.height
                            dragOffset = .zero
                            isDragging = false
                            stretchScaleY = 0.8
                            stretchScaleX = 1.2
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                stretchScaleY = 1.0
                                stretchScaleX = 1.0
                            }
                        }
                    }
            )
    }
}

// MARK: - Isometric Island View
struct IsometricGridView: View {
    let treesCount: Int
    let namespace: Namespace.ID
    
    private let treePositions: [CGSize] = [
        CGSize(width: -40, height: -55),
        CGSize(width: 40, height: -35),
        CGSize(width: -50, height: 10),
        CGSize(width: 30, height: 15),
        CGSize(width: -10, height: -20),
        CGSize(width: 70, height: -10),
        CGSize(width: -70, height: -25),
        CGSize(width: 10, height: -65),
        CGSize(width: -15, height: 35)
    ]
    
    var body: some View {
        ZStack {
            Image("platform")
                .resizable()
                .scaledToFit()
                .frame(width: 320)
            
            // עצים נטועים ונגררים
            ForEach(0..<min(treesCount, treePositions.count), id: \.self) { index in
                DraggableTreeContainer(
                    imageName: "tree",
                    initialOffset: treePositions[index]
                )
                .matchedGeometryEffect(id: index == (treesCount - 1) ? "flying_tree_target" : "tree_static_\(index)", in: namespace)
            }
        }
    }
}

// MARK: - Focus Circular Progress Ring View
struct FocusRingView: View {
    let progress: Double
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // טבעת רקע בהירה עדינה
            Circle()
                .stroke(Color.gray.opacity(0.12), lineWidth: 6)
                .frame(width: 250, height: 250)
            
            // טבעת התקדמות צבעונית
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "0091FF"), Color(hex: "09006D")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(Angle(degrees: -90)) // להתחיל מלמעלה
                .animation(.linear(duration: 0.1), value: progress)
            
            // עץ גדול במרכז המד עם פעימת נשימה חלקה
            Image("tree")
                .resizable()
                .scaledToFit()
                .frame(width: 135, height: 135)
                .scaleEffect(0.25 + (CGFloat(progress) * 0.75)) // צמיחה פיזית מ-25% ל-100% לפי ההתקדמות
                .scaleEffect(pulseScale, anchor: .bottom)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseScale = 1.05
                    }
                }
        }
    }
}

// MARK: - Interactive Bi-Weekly (14-Day) Scrollable Line Chart View
struct FourteenDayChartView: View {
    let todayCount: Int
    @Binding var selectedIndex: Int
    
    // רשימת 14 ימים (היום ו-13 ימי היסטוריה)
    private let dayNames = ["היום", "ד׳", "ג׳", "ב׳", "א׳", "ש׳", "ו׳", "ה׳", "ד׳", "ג׳", "ב׳", "א׳", "ש׳", "ו׳"]
    
    // ערכי עצים קבועים לכל יום (אינדקס 0 הוא דינמי לפי היום)
    private var values: [Int] {
        [todayCount, 5, 3, 6, 2, 4, 1, 4, 5, 2, 6, 3, 0, 2]
    }
    
    // מיקומי X קבועים לרוחב הגרף
    private let xSpacing: CGFloat = 65
    private var xPositions: [CGFloat] {
        (0..<14).map { CGFloat($0) * xSpacing + 40 }
    }
    
    private func yCoordinate(for value: Int) -> CGFloat {
        let clamped = min(max(value, 0), 8)
        return 90.0 - CGFloat(clamped) * 9.5
    }
    
    var body: some View {
        ZStack {
            // קו המילוי הדרגתי מתחת לגרף
            Path { path in
                path.move(to: CGPoint(x: xPositions[0], y: 110))
                path.addLine(to: CGPoint(x: xPositions[0], y: yCoordinate(for: values[0])))
                
                for i in 1..<14 {
                    path.addLine(to: CGPoint(x: xPositions[i], y: yCoordinate(for: values[i])))
                }
                
                path.addLine(to: CGPoint(x: xPositions[13], y: 110))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(hex: "03A9F4").opacity(0.22), Color(hex: "03A9F4").opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // קו הגרף הראשי המחבר
            Path { path in
                path.move(to: CGPoint(x: xPositions[0], y: yCoordinate(for: values[0])))
                for i in 1..<14 {
                    path.addLine(to: CGPoint(x: xPositions[i], y: yCoordinate(for: values[i])))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [Color(hex: "03A9F4"), Color(hex: "4FC3F7")],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3.5
            )
            
            // קווים מקווקווים אנכיים עדינים לכל הימים
            Path { path in
                for i in 0..<14 {
                    path.move(to: CGPoint(x: xPositions[i], y: yCoordinate(for: values[i])))
                    path.addLine(to: CGPoint(x: xPositions[i], y: 105))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3]))
            .foregroundColor(Color.gray.opacity(0.35))
            
            // הצגת הנקודות והטקסטים של הימים
            ForEach(0..<14, id: \.self) { index in
                let isSelected = (index == selectedIndex)
                
                // כפתור שקוף רחב מעל כל נקודה המאפשר לחיצה נוחה וחלקה
                Color.clear
                    .frame(width: 55, height: 130)
                    .contentShape(Rectangle())
                    .position(x: xPositions[index], y: 65)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedIndex = index
                        }
                    }
                
                // עיצוב נקודה נבחרת / רגילה
                VStack(spacing: 4) {
                    Text("\(values[index])")
                        .font(.system(size: isSelected ? 13 : 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? Color(hex: "03A9F4") : .gray)
                    
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                                .shadow(color: Color(hex: "03A9F4").opacity(0.3), radius: 4)
                            Circle()
                                .stroke(Color(hex: "03A9F4"), lineWidth: 4)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .fill(Color(hex: "03A9F4").opacity(0.55))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .position(x: xPositions[index], y: yCoordinate(for: values[index]) - (isSelected ? 14 : 10))
                
                // שמות הימים למטה
                Text(dayNames[index])
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? Color(hex: "03A9F4") : Color(hex: "09006D").opacity(isSelected ? 1.0 : 0.6))
                    .position(x: xPositions[index], y: 122)
            }
        }
        // רוחב מוגדר לפי 14 נקודות עם מרווחים קבועים
        .frame(width: xPositions[13] + 50, height: 140)
        // אפשרות גרירה (Scrubbing) חלקה לרוחב הגרף כולו
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let locationX = value.location.x
                    // מציאת היום הקרוב ביותר למיקום האצבע הנוכחי
                    var closestIndex = selectedIndex
                    var minDistance = CGFloat.infinity
                    for i in 0..<14 {
                        let distance = abs(xPositions[i] - locationX)
                        if distance < minDistance {
                            minDistance = distance
                            closestIndex = i
                        }
                    }
                    if closestIndex != selectedIndex {
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedIndex = closestIndex
                        }
                    }
                }
        )
    }
}

// MARK: - Custom Focus Slider with Snapping Preset Values & Liquid Glass Tooltip Bubble
struct CustomFocusSlider: View {
    @Binding var duration: TimeInterval
    
    @State private var isDragging: Bool = false
    
    private let presetDurations: [TimeInterval] = [
        30,
        5 * 60,
        10 * 60,
        15 * 60,
        20 * 60,
        25 * 60,
        30 * 60,
        35 * 60,
        40 * 60,
        45 * 60,
        50 * 60,
        55 * 60,
        60 * 60,
        65 * 60,
        70 * 60,
        75 * 60,
        80 * 60,
        85 * 60,
        90 * 60,
        95 * 60,
        100 * 60,
        105 * 60,
        110 * 60,
        115 * 60,
        120 * 60
    ]
    
    private var sliderProgress: Double {
        guard let index = presetDurations.firstIndex(of: duration) else { return 0.0 }
        return Double(index) / Double(presetDurations.count - 1)
    }
    
    private var formattedBubbleTime: String {
        let totalSeconds = Int(duration)
        if totalSeconds == 30 {
            return "30 שניות"
        }
        
        let totalMinutes = totalSeconds / 60
        if totalMinutes == 60 {
            return "שעה"
        } else if totalMinutes == 120 {
            return "שעתיים"
        } else if totalMinutes > 60 {
            return "שעה ו-\(totalMinutes - 60) דק׳"
        } else {
            return "\(totalMinutes) דק׳"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 22))
                .foregroundColor(.gray.opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    HStack {
                        Spacer()
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.35))
                                .frame(width: 4, height: 4)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    if isDragging {
                        VStack(spacing: 4) {
                            Text(formattedBubbleTime)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "09006D"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.45))
                                        .background(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.55), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                                .offset(y: -6)
                        }
                        .offset(x: getKnobOffset(width: geometry.size.width) - 24, y: -52)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 42, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .offset(x: getKnobOffset(width: geometry.size.width))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        isDragging = true
                                    }
                                    
                                    let rawValue = gesture.location.x / geometry.size.width
                                    let clampedValue = min(max(Double(rawValue), 0.0), 1.0)
                                    
                                    let index = Int(round(clampedValue * Double(presetDurations.count - 1)))
                                    let snappedDuration = presetDurations[index]
                                    
                                    if self.duration != snappedDuration {
                                        let generator = UISelectionFeedbackGenerator()
                                        generator.selectionChanged()
                                        self.duration = snappedDuration
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        isDragging = false
                                    }
                                }
                        )
                }
                .frame(height: 24)
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 32)
    }
    
    private func getKnobOffset(width: CGFloat) -> CGFloat {
        let maxOffset = width - 42
        return CGFloat(sliderProgress) * maxOffset
    }
}

// MARK: - Completion Screen (Liquid Glass Styled with Circular Animation)
struct CompletionView: View {
    let namespace: Namespace.ID
    let onDismiss: () -> Void
    
    // שליטה באנימציית העיגול שסוגר מהצדדים פנימה
    @State private var circleScale: CGFloat = 6.0
    @State private var contentOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // רקע גרדיאנט בדיוק כמו בצילום המסך - מכחול בהיר/טורקיז עד כחול רויאל עמוק
            LinearGradient(
                colors: [Color(hex: "3FE5F9"), Color(hex: "0E3BC7"), Color(hex: "020B4E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)
                
                // כותרות בסגנון המסך שהעלית
                VStack(spacing: 12) {
                    Text("עץ אלון")
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("צמח יפה מאוד")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // העיגול הלבן עם אפקט הכניסה מהצדדים פנימה, ובתוכו העץ הגדול
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 250, height: 250)
                        .scaleEffect(circleScale)
                    
                    Image("tree")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 145, height: 145)
                        // זיהוי עץ הניצחון לטובת המראת הטיסה והנחיתה על הלוח הראשי
                        .matchedGeometryEffect(id: "flying_tree_target", in: namespace)
                }
                .frame(width: 280, height: 280)
                
                Spacer()
                
                // כפתור תודה שקוף בעיצוב Liquid Glass עדין
                Button(action: onDismiss) {
                    Text("תודה")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "09006D"))
                        .frame(width: 130, height: 48)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.55))
                                .background(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
                .opacity(contentOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // אנימציה לכניסת העיגול הלבן במהירות מהצדדים פנימה
            withAnimation(.spring(response: 0.82, dampingFraction: 0.76)) {
                circleScale = 1.0
            }
            // הופעת שאר האלמנטים בהדרגה קלה
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Native Apple Settings View (הגדרות)
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // שמירת הגדרות ב-UserDefaults
    @AppStorage("showHistoryGraph") var showHistoryGraph = true
    @AppStorage("countdownMode") var countdownMode = false
    @AppStorage("minTreeTime") var minTreeTime = "20 דקות"
    
    // מבנה נתונים לעצי הגלריה הסטנדרטיים להצגה בגריד
    private let regularTrees = [
        (name: "אלון", unlocked: true, price: 0),
        (name: "ארז", unlocked: false, price: 200),
        (name: "קזוארינה", unlocked: false, price: 200),
        (name: "ברוש", unlocked: false, price: 200)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 28) {
                // Header (RTL-friendly layout)
                HStack(alignment: .center) {
                    // כפתור סגירה מעוגל בצד שמאל
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // כותרת בצד ימין
                    Text("הגדרות")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "09006D"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Section 1: פוקוס
                VStack(alignment: .trailing, spacing: 20) {
                    Text("פוקוס")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black.opacity(0.85))
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 20) {
                        // הצגת גרף היסטוריית שעות
                        HStack {
                            Toggle("", isOn: $showHistoryGraph)
                                .labelsHidden()
                                .tint(Color(hex: "34C759")) // ירוק Apple מקורי
                            Spacer()
                            Text("הצגת גרף היסטוריית שעות")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                        }
                        
                        // מצב ספירה לאחור
                        HStack {
                            Toggle("", isOn: $countdownMode)
                                .labelsHidden()
                                .tint(Color(hex: "34C759"))
                            Spacer()
                            Text("מצב ספירה לאחור")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                        }
                        
                        // זמן מינימלי לעץ Menu
                        HStack {
                            Menu {
                                Button("30 שניות") { minTreeTime = "30 שניות" }
                                Button("5 דקות") { minTreeTime = "5 דקות" }
                                Button("10 דקות") { minTreeTime = "10 דקות" }
                                Button("20 דקות") { minTreeTime = "20 דקות" }
                                Button("30 דקות") { minTreeTime = "30 דקות" }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(minTreeTime)
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "007AFF"))
                            }
                            
                            Spacer()
                            
                            Text("זמן מינימלי לעץ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Divider()
                    .padding(.horizontal, 24)
                
                // Section 2: פאנל עצים מעוצב בדיוק לפי התמונה שהעלית
                VStack(alignment: .trailing, spacing: 18) {
                    // Header פנימי של פאנל העצים
                    HStack {
                        // בועה מעוגלת ויוקרתית בצד שמאל
                        HStack(spacing: 5) {
                            Text("🏆")
                                .font(.system(size: 13))
                            Text("11")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.black.opacity(0.85))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1.5)
                        
                        Spacer()
                        
                        // כותרת "עצים" בצד ימין
                        Text("עצים")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    
                    // גריד דו-עמודתי מרהיב
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        
                        // 1. כרטיס אלון (פעיל / Selected)
                        VStack(spacing: 12) {
                            Image("tree")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .padding(.top, 14)
                            
                            Text("אלון")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            // סימון וי פעיל בסגנון Liquid Glass לבן
                            ZStack {
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: 50, height: 28)
                                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
                        
                        // 2. כרטיס עץ אמיתי (קק״ל)
                        ZStack(alignment: .topLeading) {
                            // תמונת הרקע של הילד הנוטעה
                            Image("kkl_planting")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 156)
                                .clipped()
                                .cornerRadius(24)
                            
                            // שכבת כהות עדינה כדי להבליט את הטקסט
                            Color.black.opacity(0.12)
                                .cornerRadius(24)
                            
                            // לוגו קק״ל בפינה השמאלית העליונה (שארנו מקום לתמונה שנקראת kkl_logo)
                            HStack(spacing: 4) {
                                Text("קק״ל")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                Image("kkl_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(hex: "007AFF").opacity(0.92))
                            .cornerRadius(8)
                            .padding(10)
                            
                            // כיתוב וכפתור לפרטים במרכז ובתחתית
                            VStack {
                                Spacer()
                                Text("עץ אמיתי")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                                
                                Button(action: {
                                    // קישור או פרטים
                                }) {
                                    Text("לפרטים")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 80, height: 28)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.65))
                                                .background(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                .padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 156)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                        
                        // 3. כרטיס קזוארינה (נעול)
                        VStack(spacing: 12) {
                            Image("tree")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .opacity(0.8)
                                .padding(.top, 14)
                            
                            Text("קזוארינה")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            // בועת מחיר נעולה
                            HStack(spacing: 4) {
                                Text("🏆")
                                    .font(.system(size: 12))
                                Text("200")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(14)
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
                        
                        // 4. כרטיס ארז (נעול)
                        VStack(spacing: 12) {
                            Image("tree")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .opacity(0.8)
                                .padding(.top, 14)
                            
                            Text("ארז")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            // בועת מחיר נעולה
                            HStack(spacing: 4) {
                                Text("🏆")
                                    .font(.system(size: 12))
                                Text("200")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(14)
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(16)
                .background(Color(hex: "F2F4F7").opacity(0.95))
                .cornerRadius(28)
                .padding(.horizontal, 24)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var stopwatch = CountdownTimer()
    @StateObject private var treeCounter = TreeCounter()
    
    @State private var isRunning = false
    @State private var showCompletion = false
    @State private var showAbandonAlert = false
    @State private var showSettings = false // שליטה בהצגת הגדרות
    
    // ניהול היום הנבחר בגרף ה-14 ימים (אינדקס 0 הוא היום, 1 עד 13 הם הימים ההיסטוריים)
    @State private var selectedGraphIndex: Int = 0
    
    // קריאת הגדרות המשתמש מה-AppStorage
    @AppStorage("showHistoryGraph") var showHistoryGraph = true
    @AppStorage("countdownMode") var countdownMode = false
    @AppStorage("minTreeTime") var minTreeTime = "20 דקות"
    
    // משך פוקוס נבחר (ברירת מחדל: 30 שניות לבדיקה מהירה במצב ספירה לאחור)
    @State private var selectedDuration: TimeInterval = 30
    
    // מרחב שמות משותף לביצוע אנימציית טיסת העץ מהמסך האמצעי אל הלוח הראשי
    @Namespace private var treeAnimationNamespace
    
    // ערכי היסטוריית העצים המקבילים לגרף ה-14 ימים
    private var biWeeklyTreeValues: [Int] {
        [treeCounter.treesToday, 5, 3, 6, 2, 4, 1, 4, 5, 2, 6, 3, 0, 2]
    }
    
    // כמות העצים שיש להציג כרגע על הלוח האיזומטרי
    private var activeDisplayTreesCount: Int {
        biWeeklyTreeValues[selectedGraphIndex]
    }
    
    // המרת ערך הטקסט של "זמן מינימלי לעץ" לשניות
    private var minTreeTimeSeconds: TimeInterval {
        switch minTreeTime {
        case "30 שניות": return 30
        case "5 דקות": return 5 * 60
        case "10 דקות": return 10 * 60
        case "20 דקות": return 20 * 60
        case "30 דקות": return 30 * 60
        default: return 20 * 60
        }
    }
    
    // חישוב אחוזי התקדמות עבור הטבעת המעוגלת
    private var progressFraction: Double {
        if countdownMode {
            return min(1.0, (selectedDuration - stopwatch.timeLeft) / selectedDuration)
        } else {
            return min(1.0, stopwatch.elapsedTime / minTreeTimeSeconds)
        }
    }
    
    // תרגום כמות עצים לעברית טבעית ומשחקית (דינמי בהתאם ליום שנבחר בגרף)
    private var selectedDayHebrewText: String {
        let count = activeDisplayTreesCount
        let dayPrefix: String = {
            if selectedGraphIndex == 0 {
                return "היום"
            } else {
                let dayNames = ["היום", "ד׳", "ג׳", "ב׳", "א׳", "ש׳", "ו׳", "ה׳", "ד׳", "ג׳", "ב׳", "א׳", "ש׳", "ו׳"]
                return "ביום \(dayNames[selectedGraphIndex])"
            }
        }()
        
        switch count {
        case 0:
            return "לא נטעת עצים \(dayPrefix)"
        case 1:
            return "נטעת עץ אחד \(dayPrefix)"
        case 2:
            return "נטעת שני עצים \(dayPrefix)"
        case 3:
            return "נטעת שלושה עצים \(dayPrefix)"
        case 4:
            return "נטעת ארבעה עצים \(dayPrefix)"
        case 5:
            return "נטעת חמישה עצים \(dayPrefix)"
        case 6:
            return "נטעת שישה עצים \(dayPrefix)"
        case 7:
            return "נטעת שבעה עצים \(dayPrefix)"
        case 8:
            return "נטעת שמונה עצים \(dayPrefix)"
        case 9:
            return "נטעת תשעה עצים \(dayPrefix)"
        default:
            return "נטעת \(count) עצים \(dayPrefix)"
        }
    }
    
    var body: some View {
        ZStack {
            // תצוגת מסך הבית וזמן הפוקוס הראשי
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [Color(hex: "FCFDFE"), Color(hex: "F3F6F9")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. חלק עליון: גרף 14 הימים הנגלל לרוחב (מוסתר בזמן ריצה)
                    if !isRunning {
                        if showHistoryGraph {
                            ScrollView(.horizontal, showsIndicators: false) {
                                FourteenDayChartView(
                                    todayCount: treeCounter.treesToday,
                                    selectedIndex: $selectedGraphIndex
                                )
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            Spacer()
                                .frame(height: 30)
                        }
                    } else {
                        Spacer()
                            .frame(height: 40)
                    }
                    
                    Spacer()
                    
                    // 2. כותרת מרכזית / טיימר (לאחור או קדימה)
                    VStack(spacing: 12) {
                        if isRunning {
                            Text(countdownMode ? stopwatch.timeLeft.mmssString : stopwatch.elapsedTime.mmssString)
                                .font(.system(size: 82, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "0091FF"), Color(hex: "09006D")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            VStack(spacing: 6) {
                                Text(selectedDayHebrewText)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Color.gray.opacity(0.85))
                                
                                if !countdownMode {
                                    Text("זמן מינימלי לעץ: \(minTreeTime)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: 100)
                    
                    Spacer(minLength: 20)
                    
                    // 3. מרכז המסך: מד מעגלי ממוקד בזמן פוקוס, או אי המשטח האיזומטרי בשגרה
                    Group {
                        if isRunning {
                            FocusRingView(progress: progressFraction)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            // מציג את כמות העצים הרלוונטית ליום הנבחר בגרף הדו-שבועי!
                            IsometricGridView(
                                treesCount: activeDisplayTreesCount,
                                namespace: treeAnimationNamespace
                            )
                            .shadow(color: Color(hex: "68CDE3").opacity(0.12), radius: 30, x: 0, y: 15)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 250)
                    
                    Spacer()
                    
                    // 4. סליידר הזמן (מוצג רק כשאינו רץ ובמצב ספירה לאחור)
                    if !isRunning && countdownMode {
                        CustomFocusSlider(duration: $selectedDuration)
                            .padding(.bottom, 48)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                            .frame(height: 60)
                    }
                    
                    // 5. כפתור הפעולה הראשי: פוקוס / זהו
                    Button(action: {
                        if isRunning {
                            // אם אנחנו במצב ספירה קדימה ועברנו את הזמן המינימלי - זכינו בעץ!
                            if !countdownMode && stopwatch.elapsedTime >= minTreeTimeSeconds {
                                withAnimation(.spring(response: 0.85, dampingFraction: 0.78, blendDuration: 0.5)) {
                                    _ = stopwatch.stop()
                                    treeCounter.incrementTree()
                                    selectedGraphIndex = 0 // החזרה אוטומטית ליום הנוכחי כדי לראות את העץ החדש
                                    showCompletion = true
                                    isRunning = false
                                }
                            } else {
                                // ספירה לאחור, או ספירה קדימה שטרם הגיעה לזמן המינימלי - הצגת אזהרה
                                withAnimation(.spring()) {
                                    stopwatch.pause()
                                    showAbandonAlert = true
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                stopwatch.start(
                                    duration: countdownMode ? selectedDuration : minTreeTimeSeconds,
                                    countUp: !countdownMode
                                )
                                isRunning = true
                            }
                        }
                    }) {
                        Text(isRunning ? "זהו" : "פוקוס")
                            .font(.system(size: isRunning ? 24 : 32, weight: .bold))
                            .foregroundColor(isRunning ? Color(hex: "007AFF") : .white)
                            .frame(width: 180, height: 80)
                            .background(
                                Group {
                                    if isRunning {
                                        // כפתור "זהו" בעיצוב זכוכית נוזלית מטושטשת
                                        Capsule()
                                            .fill(.white.opacity(0.65))
                                            .background(.ultraThinMaterial)
                                            .overlay(
                                                Capsule()
                                                    .stroke(.white.opacity(0.55), lineWidth: 1.5)
                                            )
                                    } else {
                                        // כפתור "פוקוס" כחול מבריק ועמוק
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "38A1FF"), Color(hex: "007AFF")],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(.white.opacity(0.35), lineWidth: 1)
                                            )
                                    }
                                }
                            )
                            .clipShape(Capsule())
                            .shadow(
                                color: isRunning ? .black.opacity(0.06) : Color(hex: "007AFF").opacity(0.35),
                                radius: 18,
                                x: 0,
                                y: 8
                            )
                    }
                    .padding(.bottom, 20)
                    
                    // 6. כפתור הגדרות בתחתית בעיצוב Liquid Glass (מוסתר בזמן ריצה)
                    if !isRunning {
                        Button(action: {
                            showSettings = true
                        }) {
                            Text("הגדרות")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "09006D").opacity(0.85))
                                .frame(width: 140, height: 50)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.65))
                                        .background(.ultraThinMaterial)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.55), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                        }
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                            .frame(height: 36)
                    }
                }
            }
            .opacity(showCompletion ? 0.0 : 1.0) // השארת מסך הבית ברקע בשקיפות כבויה כדי לבצע את טיסת העץ במדויק
            
            // הצגת מסך הניצחון/הרווחת עץ מעל מסך הבית
            if showCompletion {
                CompletionView(
                    namespace: treeAnimationNamespace,
                    onDismiss: {
                        // העלמת מסך הסיום עם אנימציית קפיץ מותאמת שמניעה את העץ למקומו החדש על האי
                        withAnimation(.spring(response: 0.88, dampingFraction: 0.76, blendDuration: 0.3)) {
                            showCompletion = false
                            stopwatch.reset(duration: selectedDuration)
                        }
                    }
                )
                .transition(.opacity)
            }
            
            // דיאלוג ביטול ווויתור מעוצב (Abandon / Stop Alert)
            if showAbandonAlert {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "FF3B30"))
                        .padding(.top, 8)
                    
                    VStack(spacing: 8) {
                        Text("לוותר על העץ?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "09006D"))
                        
                        Text("אם תצא עכשיו, העץ שאתה מגדל כרגע יינבל ולא יתווסף למשטח שלך.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showAbandonAlert = false
                                stopwatch.resume()
                            }
                        }) {
                            Text("המשך בפוקוס")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "0091FF"), Color(hex: "007AFF")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(26)
                        }
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                _ = stopwatch.stop()
                                stopwatch.reset(duration: selectedDuration)
                                isRunning = false
                                showAbandonAlert = false
                            }
                        }) {
                            Text("וותר על העץ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "FF3B30"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(26)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                .background(Color.white)
                .cornerRadius(32)
                .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
                .padding(.horizontal, 40)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        // הצגת מסך ההגדרות כ-Native Half-Sheet
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.fraction(0.85)]) // גובה נוח בדיוק כמו בעיצוב
                .presentationDragIndicator(.visible)   // פס גרירה בראש הגיליון
        }
        .onAppear {
            stopwatch.onFinished = {
                withAnimation(.spring(response: 0.85, dampingFraction: 0.78, blendDuration: 0.5)) {
                    treeCounter.incrementTree()
                    selectedGraphIndex = 0 // חזרה אוטומטית ליום הנוכחי כדי לראות את העץ שנטענו
                    showCompletion = true
                    isRunning = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(\.layoutDirection, .rightToLeft)
}
