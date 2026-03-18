import SwiftUI
import AppKit

// MARK: - ANSI Parser

struct ANSIParser {
    /// Parse raw terminal output into an NSAttributedString with ANSI colors.
    static func parse(_ data: Data, defaultFont: NSFont, defaultColor: NSColor) -> NSAttributedString {
        guard let text = String(data: data, encoding: .utf8) else {
            return NSAttributedString()
        }
        return parse(text, defaultFont: defaultFont, defaultColor: defaultColor)
    }

    static func parse(_ text: String, defaultFont: NSFont, defaultColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentFG = defaultColor
        var currentBold = false

        var i = text.startIndex

        while i < text.endIndex {
            // Check for ESC character
            if text[i] == "\u{1B}" {
                let next = text.index(after: i)
                if next < text.endIndex, text[next] == "[" {
                    // CSI sequence — find the terminating letter
                    var j = text.index(after: next)
                    while j < text.endIndex, !text[j].isLetter {
                        j = text.index(after: j)
                    }
                    if j < text.endIndex {
                        let command = text[j]
                        if command == "m" {
                            let params = String(text[text.index(after: next)..<j])
                            applySGR(params, fg: &currentFG, bold: &currentBold, defaultColor: defaultColor)
                        }
                        // Skip past the sequence regardless of command type
                        i = text.index(after: j)
                        continue
                    }
                }
                // Unrecognized escape — skip the ESC
                i = text.index(after: i)
                continue
            }

            // Collect plain text until the next ESC
            var end = text.index(after: i)
            while end < text.endIndex, text[end] != "\u{1B}" {
                end = text.index(after: end)
            }

            let chunk = String(text[i..<end])
            let font = currentBold
                ? NSFontManager.shared.convert(defaultFont, toHaveTrait: .boldFontMask)
                : defaultFont
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: currentFG,
            ]
            result.append(NSAttributedString(string: chunk, attributes: attrs))
            i = end
        }

        return result
    }

    private static func applySGR(_ params: String, fg: inout NSColor, bold: inout Bool, defaultColor: NSColor) {
        let codes = params.split(separator: ";").compactMap { Int($0) }
        if codes.isEmpty {
            fg = defaultColor
            bold = false
            return
        }
        for code in codes {
            switch code {
            case 0:
                fg = defaultColor
                bold = false
            case 1:
                bold = true
            case 22:
                bold = false
            case 30...37:
                fg = ansiColor(code - 30)
            case 39:
                fg = defaultColor
            case 90...97:
                fg = ansiBrightColor(code - 90)
            default:
                break
            }
        }
    }

    private static let standardColors: [NSColor] = [
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1),   // 0: black
        NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1),   // 1: red
        NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1),   // 2: green
        NSColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 1),   // 3: yellow
        NSColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 1),   // 4: blue
        NSColor(red: 0.8, green: 0.3, blue: 0.8, alpha: 1),   // 5: magenta
        NSColor(red: 0.3, green: 0.8, blue: 0.8, alpha: 1),   // 6: cyan
        NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1), // 7: white
    ]

    private static let brightColors: [NSColor] = [
        NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),   // 0: bright black (gray)
        NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),   // 1: bright red
        NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1),   // 2: bright green
        NSColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 1),   // 3: bright yellow
        NSColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 1),   // 4: bright blue
        NSColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1),   // 5: bright magenta
        NSColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1),   // 6: bright cyan
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),   // 7: bright white
    ]

    private static func ansiColor(_ index: Int) -> NSColor {
        standardColors[index % standardColors.count]
    }

    private static func ansiBrightColor(_ index: Int) -> NSColor {
        brightColors[index % brightColors.count]
    }
}

// MARK: - Keyboard Input View

/// A plain NSView that acts as first responder to capture all keyboard input.
/// All keys are handled directly by keyCode — no input method routing.
class TerminalInputView: NSView {
    var onKeyInput: ((Data) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Handle special keys directly by keyCode — never route through input system
        switch event.keyCode {
        case 51:  // Backspace/Delete
            onKeyInput?(Data([0x7F]))
            return
        case 117: // Forward Delete
            send("\u{1B}[3~")
            return
        case 36, 76: // Return, Numpad Enter
            onKeyInput?(Data([0x0D]))
            return
        case 48:  // Tab
            if event.modifierFlags.contains(.shift) {
                send("\u{1B}[Z")
            } else {
                onKeyInput?(Data([0x09]))
            }
            return
        case 53:  // Escape
            onKeyInput?(Data([0x1B]))
            return
        case 126: // Up Arrow
            send("\u{1B}[A")
            return
        case 125: // Down Arrow
            send("\u{1B}[B")
            return
        case 123: // Left Arrow
            send("\u{1B}[D")
            return
        case 124: // Right Arrow
            send("\u{1B}[C")
            return
        case 115: // Home
            send("\u{1B}[H")
            return
        case 119: // End
            send("\u{1B}[F")
            return
        case 116: // Page Up
            send("\u{1B}[5~")
            return
        case 121: // Page Down
            send("\u{1B}[6~")
            return
        default:
            break
        }

        // Ctrl+key combinations → control characters
        if event.modifierFlags.contains(.control),
           let chars = event.charactersIgnoringModifiers,
           let scalar = chars.unicodeScalars.first {
            let code = scalar.value
            if code >= UInt32(Character("a").asciiValue!),
               code <= UInt32(Character("z").asciiValue!) {
                let ctrlChar = UInt8(code - UInt32(Character("a").asciiValue!) + 1)
                onKeyInput?(Data([ctrlChar]))
                return
            }
        }

        // Regular character keys — use event.characters directly
        if let chars = event.characters, !chars.isEmpty,
           let data = chars.data(using: .utf8) {
            onKeyInput?(data)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        switch event.charactersIgnoringModifiers {
        case "v":
            if let string = NSPasteboard.general.string(forType: .string),
               let data = string.data(using: .utf8) {
                onKeyInput?(data)
            }
            return true
        default:
            return false
        }
    }

    private func send(_ string: String) {
        if let data = string.data(using: .utf8) {
            onKeyInput?(data)
        }
    }
}

// MARK: - Terminal Display View (output only)

class TerminalDisplayView: NSTextView {
    override var acceptsFirstResponder: Bool { false }

    func appendOutput(_ attributedString: NSAttributedString) {
        textStorage?.append(attributedString)
        if let storage = textStorage, storage.length > 500_000 {
            let excess = storage.length - 400_000
            storage.deleteCharacters(in: NSRange(location: 0, length: excess))
        }
        scrollToEndOfDocument(nil)
    }
}

// MARK: - Container NSView

/// Composite view: an invisible TerminalInputView on top of a TerminalDisplayView in a scroll view.
class TerminalContainerView: NSView {
    let inputView = TerminalInputView()
    let displayView = TerminalDisplayView()
    let scrollView = NSScrollView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Display text view (read-only, for output)
        displayView.isEditable = false
        displayView.isSelectable = true
        displayView.isRichText = true
        displayView.backgroundColor = .black
        displayView.isVerticallyResizable = true
        displayView.isHorizontallyResizable = false
        displayView.autoresizingMask = [.width]
        displayView.textContainerInset = NSSize(width: 4, height: 4)
        displayView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        displayView.textContainer?.widthTracksTextView = true

        // Scroll view wrapping display
        scrollView.documentView = displayView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Input view sits on top, transparent, same size
        inputView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inputView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            inputView.topAnchor.constraint(equalTo: topAnchor),
            inputView.bottomAnchor.constraint(equalTo: bottomAnchor),
            inputView.leadingAnchor.constraint(equalTo: leadingAnchor),
            inputView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    override func mouseDown(with event: NSEvent) {
        // Clicking anywhere in the terminal gives focus to the input view
        window?.makeFirstResponder(inputView)
    }
}

// MARK: - NSViewRepresentable Bridge

struct TerminalTextViewRepresentable: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> TerminalContainerView {
        let container = TerminalContainerView()

        // Forward keystrokes to PTY
        container.inputView.onKeyInput = { [weak session] data in
            session?.write(data)
        }

        context.coordinator.container = container

        // Wire PTY output to the display view
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let defaultColor = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0)
        session.onOutput = { [weak coordinator = context.coordinator] data in
            MainActor.assumeIsolated {
                let parsed = ANSIParser.parse(data, defaultFont: font, defaultColor: defaultColor)
                coordinator?.container?.displayView.appendOutput(parsed)
            }
        }

        // Flush any output that arrived before the view was mounted
        session.flushPendingOutput()

        // Focus the input view
        DispatchQueue.main.async {
            container.window?.makeFirstResponder(container.inputView)
        }

        return container
    }

    func updateNSView(_ container: TerminalContainerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var container: TerminalContainerView?
    }
}

// MARK: - SwiftUI Terminal View

struct TerminalView: View {
    let session: TerminalSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Circle()
                    .fill(session.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)

                Text(session.isRunning
                     ? "Shell — \(session.containerID.prefix(12))"
                     : "Disconnected")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                if let code = session.exitCode {
                    Text("exit \(code)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: [.command])
                .help("Close terminal (⌘W)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: NSColor(white: 0.1, alpha: 1.0)))

            TerminalTextViewRepresentable(session: session)
        }
        .background(.black)
    }
}
