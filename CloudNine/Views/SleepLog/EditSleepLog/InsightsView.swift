import SwiftUI

struct InsightsView: View {
    
    @Environment(\.dismiss) var dismiss
    var insightText: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Sleep Insight")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    
                    // Parse and display the formatted content
                    ForEach(parseInsight(), id: \.id) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            if let header = section.header {
                                Text(header)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(.top, 8)
                            }
                            
                            ForEach(section.paragraphs, id: \.self) { paragraph in
                                Text(formatAttributedText(paragraph))
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sleep Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Parse the insight into sections
    private func parseInsight() -> [InsightSection] {
        var sections: [InsightSection] = []
        
        // Remove "Sleep Insight:" prefix if present
        let cleanedText = insightText.replacingOccurrences(of: "Sleep Insight:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split by section headers (text between ** and **)
        let components = cleanedText.components(separatedBy: "**")
        
        var currentHeader: String?
        var currentParagraphs: [String] = []
        var introText: String = ""
        var foundFirstHeader = false
        
        for (index, component) in components.enumerated() {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                continue
            }
            
            // Check if this is a header (ends with :)
            if trimmed.hasSuffix(":") && index % 2 == 1 {
                // Save previous section if exists
                if foundFirstHeader {
                    if let header = currentHeader {
                        sections.append(InsightSection(header: header, paragraphs: currentParagraphs))
                    }
                }
                
                currentHeader = trimmed
                currentParagraphs = []
                foundFirstHeader = true
            } else {
                // This is content
                let paragraphs = trimmed.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if !foundFirstHeader {
                    // Intro text before first header
                    introText += trimmed + " "
                } else {
                    currentParagraphs.append(contentsOf: paragraphs)
                }
            }
        }
        
        // Add intro section if exists
        if !introText.isEmpty {
            let introParagraphs = introText.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { $0.hasSuffix(".") ? $0 : $0 + "." }
            
            sections.insert(InsightSection(header: nil, paragraphs: introParagraphs), at: 0)
        }
        
        // Add final section
        if let header = currentHeader, !currentParagraphs.isEmpty {
            sections.append(InsightSection(header: header, paragraphs: currentParagraphs))
        }
        
        return sections
    }
    
    private func formatAttributedText(_ text: String) -> AttributedString {
        // Step 0: Clean up stray single asterisks but preserve bold (**text**) markers
        let cleanedAsterisks = text.replacingOccurrences(of: "(?<!\\*)\\*(?!\\*)", with: "", options: .regularExpression)
        
        // Step 1: Replace 2+ consecutive newlines with a single newline
        let cleanedNewlines = cleanedAsterisks.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        
        var attributedString = AttributedString(cleanedNewlines)
        
        // Step 2: Parse bold (**text**) as before
        let pattern = "\\*\\*(.*?)\\*\\*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributedString
        }
        
        let nsRange = NSRange(cleanedNewlines.startIndex..<cleanedNewlines.endIndex, in: cleanedNewlines)
        let matches = regex.matches(in: cleanedNewlines, options: [], range: nsRange)
        
        var result = AttributedString()
        var lastIndex = cleanedNewlines.startIndex
        
        for match in matches {
            if let range = Range(match.range, in: cleanedNewlines) {
                let beforeText = String(cleanedNewlines[lastIndex..<range.lowerBound])
                result += AttributedString(beforeText)
                
                if let contentRange = Range(match.range(at: 1), in: cleanedNewlines) {
                    var boldText = AttributedString(String(cleanedNewlines[contentRange]))
                    boldText.font = .system(size: 16, weight: .semibold)
                    result += boldText
                }
                
                lastIndex = range.upperBound
            }
        }
        
        if lastIndex < cleanedNewlines.endIndex {
            result += AttributedString(String(cleanedNewlines[lastIndex...]))
        }
        
        return result.characters.isEmpty ? attributedString : result
    }
}

struct InsightSection {
    let id = UUID()
    let header: String?
    let paragraphs: [String]
}

#Preview {
    InsightsView(insightText: "")
}
