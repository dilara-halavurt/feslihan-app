import SwiftUI
import ClerkKit

struct CookingModeView: View {
    let title: String
    let steps: [CookingStep]
    var recipeId: String? = nil
    var sourceURL: String? = nil

    @State private var currentIndex = 0
    @State private var timerSeconds: Int? = nil
    @State private var timerRemaining: Int = 0
    @State private var timerActive = false
    @State private var showReview = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DS.emberDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ADIM \(currentIndex + 1) / \(steps.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.55))
                        if let section = steps[currentIndex].section {
                            Text(section)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.honey.opacity(0.7))
                        }
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.15))
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.emberLight)
                            .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(steps.count), height: 5)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(height: 5)
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                // Step content
                TabView(selection: $currentIndex) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        VStack(spacing: 24) {
                            Spacer()

                            // Section name (if sectioned recipe)
                            if let section = step.section,
                               index == 0 || steps[index - 1].section != section {
                                Text(section)
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(DS.emberLight.opacity(0.7))
                                    .textCase(.uppercase)
                            }

                            // Recipe name
                            Text(title)
                                .font(.system(size: 15, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(DS.honey)

                            Text(step.text)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .padding(.horizontal, 34)

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
                HStack(spacing: 12) {
                    Button {
                        withAnimation { currentIndex = max(0, currentIndex - 1) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Önceki")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(currentIndex > 0 ? .white.opacity(0.9) : .white.opacity(0.3))
                        .background(.white.opacity(currentIndex > 0 ? 0.12 : 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(currentIndex == 0)

                    if currentIndex == steps.count - 1 {
                        Button {
                            showReview = true
                        } label: {
                            Text("Tamamlandı")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DS.emberDark)
                                .background(DS.emberLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button {
                            withAnimation { currentIndex += 1 }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Sonraki")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(DS.emberDark)
                            .background(DS.emberLight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $showReview, onDismiss: { dismiss() }) {
            RecipeReviewSheet(recipeTitle: title, recipeId: recipeId, sourceURL: sourceURL, onDone: {
                showReview = false
            })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
                    .font(.system(size: 20))

                if timerActive && isThisStep && timerRemaining > 0 {
                    Text(formatTimer(timerRemaining))
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .contentTransition(.numericText())
                } else {
                    Text(formatTimer(duration))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(DS.terracotta)
            .clipShape(Capsule())
            .shadow(color: DS.terracotta.opacity(0.35), radius: 8, y: 4)
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

// MARK: - Recipe Review Sheet

struct RecipeReviewSheet: View {
    let recipeTitle: String
    let recipeId: String?
    var sourceURL: String? = nil
    var existingReview: UserReviewDTO? = nil
    let onDone: () -> Void

    @State private var rating: Int
    @State private var comment: String
    @State private var isSaving = false
    @State private var resolvedRecipeId: String?

    init(recipeTitle: String, recipeId: String?, sourceURL: String? = nil, existingReview: UserReviewDTO? = nil, onDone: @escaping () -> Void) {
        self.recipeTitle = recipeTitle
        self.recipeId = recipeId
        self.sourceURL = sourceURL
        self.existingReview = existingReview
        self.onDone = onDone
        _rating = State(initialValue: existingReview?.rating ?? 0)
        _comment = State(initialValue: existingReview?.comment ?? "")
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Afiyet olsun!")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(DS.ink)

                Text(recipeTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.smoke)
            }
            .padding(.top, 20)

            // Star rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            rating = star
                        }
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundStyle(star <= rating ? DS.honey : DS.stone)
                    }
                }
            }

            // Comment
            TextField("Bir notun var mı? (opsiyonel)", text: $comment, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(2...4)
                .padding(14)
                .background(DS.sand)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Gönder")
                                .font(.buttonFont())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(DS.flour)
                    .background(rating > 0 ? DS.ember : DS.stone)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(rating == 0 || isSaving)

                if existingReview != nil {
                    Button(action: deleteReview) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                            Text("Denediklerimden Kaldır")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(DS.tomato)
                    }
                    .disabled(isSaving)
                } else {
                    Button("Atla") {
                        onDone()
                    }
                    .font(.label())
                    .foregroundStyle(DS.dust)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(DS.cream)
        .task {
            // If no recipeId, try to resolve from sourceURL
            if recipeId == nil, let url = sourceURL {
                if let dto = await APIService.lookup(url: url) {
                    resolvedRecipeId = dto.id
                    print("[Review] Resolved recipeId: \(dto.id ?? "nil") from URL")
                }
            }
        }
    }

    private var effectiveRecipeId: String? {
        recipeId ?? resolvedRecipeId
    }

    private func submit() {
        guard rating > 0 else { return }
        isSaving = true
        Task {
            if let rid = effectiveRecipeId,
               let userId = Clerk.shared.user?.id {
                let success = await APIService.submitReview(
                    recipeId: rid,
                    userId: userId,
                    rating: rating,
                    comment: comment.isEmpty ? nil : comment
                )
                print("[Review] Submit \(success ? "OK" : "FAILED") for recipe \(rid)")
            } else {
                print("[Review] No recipeId or userId, skipping save")
            }
            onDone()
        }
    }

    private func deleteReview() {
        guard let review = existingReview,
              let userId = Clerk.shared.user?.id else { return }
        isSaving = true
        Task {
            let success = await APIService.deleteReview(reviewId: review.id, userId: userId)
            print("[Review] Delete \(success ? "OK" : "FAILED") for review \(review.id)")
            onDone()
        }
    }
}

// MARK: - Step Model

struct CookingStep: Identifiable {
    let id = UUID()
    let number: Int
    let text: String
    let timerDuration: Int? // seconds
    let section: String? // e.g. "KARAMEL", "KEK HAMURU"
}

// MARK: - Parser

extension CookingStep {
    /// Parse numbered instructions text into cooking steps.
    /// Detects section headers (ALL CAPS + ":") and timer durations.
    static func parse(from instructions: String) -> [CookingStep] {
        // First, build a map of line positions to section names
        let lines = instructions.components(separatedBy: "\n")
        var sectionAtLine: [Int: String] = [:]
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isSectionHeader(trimmed) {
                sectionAtLine[i] = trimmed.replacingOccurrences(of: ":$", with: "", options: .regularExpression)
            }
        }

        // Split by numbered prefixes: "1.", "2.", etc.
        let pattern = #"(?:^|\n)\s*(\d+)\.\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return lines
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !isSectionHeader($0.trimmingCharacters(in: .whitespaces)) }
                .enumerated()
                .map { CookingStep(number: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces), timerDuration: nil, section: nil) }
        }

        let nsString = instructions as NSString
        let matches = regex.matches(in: instructions, range: NSRange(location: 0, length: nsString.length))

        guard !matches.isEmpty else {
            return lines
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !isSectionHeader($0.trimmingCharacters(in: .whitespaces)) }
                .enumerated()
                .map { CookingStep(number: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces), timerDuration: nil, section: nil) }
        }

        // Build line offset map to find which section each match belongs to
        var lineOffsets: [Int] = []
        var offset = 0
        for line in lines {
            lineOffsets.append(offset)
            offset += line.count + 1 // +1 for \n
        }

        var currentSection: String? = nil
        var steps: [CookingStep] = []
        for (i, match) in matches.enumerated() {
            // Determine section: find the latest section header before this match
            let matchPos = match.range.location
            for (lineIdx, lineOffset) in lineOffsets.enumerated() {
                if lineOffset > matchPos { break }
                if let sec = sectionAtLine[lineIdx] {
                    currentSection = sec
                }
            }

            let numberRange = Range(match.range(at: 1), in: instructions)!
            let stepNumber = Int(instructions[numberRange]) ?? (i + 1)

            let contentStart = match.range.location + match.range.length
            let contentEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsString.length
            let content = nsString.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let duration = extractTimer(from: content)
            steps.append(CookingStep(number: stepNumber, text: content, timerDuration: duration, section: currentSection))
        }

        return steps
    }

    /// Check if a line is a section header (ALL CAPS text ending with ":")
    private static func isSectionHeader(_ line: String) -> Bool {
        guard line.hasSuffix(":") else { return false }
        let content = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        guard content.count >= 2, content.count <= 40 else { return false }
        let uppercased = content.uppercased(with: Locale(identifier: "tr_TR"))
        return content == uppercased && !content.contains(where: { $0.isNumber })
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
