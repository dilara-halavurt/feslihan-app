import SwiftUI

struct CookingModeView: View {
    let title: String
    let steps: [CookingStep]

    @State private var currentIndex = 0
    @State private var timerSeconds: Int? = nil
    @State private var timerRemaining: Int = 0
    @State private var timerActive = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DS.emberDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("\(currentIndex + 1) / \(steps.count)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    // Invisible spacer to center the counter
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.pine)
                            .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(steps.count), height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Step content
                TabView(selection: $currentIndex) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        VStack(spacing: 24) {
                            Spacer()

                            Text(step.text)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .padding(.horizontal, 24)

                            // Timer button if step has a duration
                            if let duration = step.timerDuration {
                                timerView(duration: duration)
                            }

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentIndex = max(0, currentIndex - 1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 56, height: 56)
                            .foregroundStyle(currentIndex > 0 ? .white : .white.opacity(0.3))
                            .background(.white.opacity(currentIndex > 0 ? 0.15 : 0.05))
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == 0)

                    if currentIndex == steps.count - 1 {
                        Button {
                            dismiss()
                        } label: {
                            Text("Tamamlandı")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(DS.emberDark)
                                .background(DS.pine)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Button {
                            withAnimation { currentIndex += 1 }
                        } label: {
                            Text("Sonraki")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(.white)
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
        .persistentSystemOverlays(.hidden)
        .onChange(of: currentIndex) {
            stopTimer()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            guard timerActive, timerRemaining > 0 else { return }
            timerRemaining -= 1
            if timerRemaining == 0 {
                timerActive = false
            }
        }
    }

    // MARK: - Timer

    @ViewBuilder
    private func timerView(duration: Int) -> some View {
        let isThisStep = steps[currentIndex].timerDuration == duration

        Button {
            if timerActive {
                stopTimer()
            } else {
                timerRemaining = duration
                timerActive = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: timerActive && isThisStep ? "pause.circle.fill" : "timer")
                    .font(.system(size: 22))

                if timerActive && isThisStep && timerRemaining > 0 {
                    Text(formatTimer(timerRemaining))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                } else {
                    Text(formatTimer(duration))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(timerActive && isThisStep ? DS.emberDark : .white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(timerActive && isThisStep ? DS.pine : .white.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    private func stopTimer() {
        timerActive = false
        timerRemaining = 0
    }

    private func formatTimer(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Step Model

struct CookingStep: Identifiable {
    let id = UUID()
    let number: Int
    let text: String
    let timerDuration: Int? // seconds
}

// MARK: - Parser

extension CookingStep {
    /// Parse numbered instructions text into cooking steps.
    /// Detects timer durations from phrases like "30 dakika", "5 dk", "1 saat".
    static func parse(from instructions: String) -> [CookingStep] {
        // Split by numbered prefixes: "1.", "2.", etc.
        let pattern = #"(?:^|\n)\s*(\d+)\.\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // Fallback: split by newlines
            return instructions
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .enumerated()
                .map { CookingStep(number: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces), timerDuration: nil) }
        }

        let nsString = instructions as NSString
        let matches = regex.matches(in: instructions, range: NSRange(location: 0, length: nsString.length))

        guard !matches.isEmpty else {
            return instructions
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .enumerated()
                .map { CookingStep(number: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces), timerDuration: nil) }
        }

        var steps: [CookingStep] = []
        for (i, match) in matches.enumerated() {
            let numberRange = Range(match.range(at: 1), in: instructions)!
            let stepNumber = Int(instructions[numberRange]) ?? (i + 1)

            let contentStart = match.range.location + match.range.length
            let contentEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsString.length
            let content = nsString.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let duration = extractTimer(from: content)
            steps.append(CookingStep(number: stepNumber, text: content, timerDuration: duration))
        }

        return steps
    }

    /// Extract timer duration in seconds from step text.
    private static func extractTimer(from text: String) -> Int? {
        let lower = text.lowercased()

        // Match "X dakika" or "X dk"
        if let match = lower.range(of: #"(\d+)\s*(?:dakika|dk)\b"#, options: .regularExpression) {
            let numStr = lower[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let minutes = Int(numStr), minutes >= 1, minutes <= 480 {
                return minutes * 60
            }
        }

        // Match "X saat"
        if let match = lower.range(of: #"(\d+(?:[.,]\d+)?)\s*saat\b"#, options: .regularExpression) {
            let numStr = lower[match].components(separatedBy: CharacterSet.letters.union(.whitespaces)).joined().replacingOccurrences(of: ",", with: ".")
            if let hours = Double(numStr), hours >= 0.5, hours <= 24 {
                return Int(hours * 3600)
            }
        }

        // Match "X saniye"
        if let match = lower.range(of: #"(\d+)\s*saniye\b"#, options: .regularExpression) {
            let numStr = lower[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let seconds = Int(numStr), seconds >= 5, seconds <= 600 {
                return seconds
            }
        }

        return nil
    }
}
