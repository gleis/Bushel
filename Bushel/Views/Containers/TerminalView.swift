import SwiftUI
import AppKit

// MARK: - Terminal NSTextView

/// An NSTextView subclass that captures keyboard input and sends it to the PTY,
/// while displaying PTY output as a read-only terminal.
class TerminalNSTextView: NSTextView {
    var onKeyInput: ((Data) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var isEditable: Bool { get { false } set {} }

    override func keyDown(with event: NSEvent) {
        // Handle special keys by keyCode
        switch event.keyCode {
        case 51:  onKeyInput?(Data([0x7F])); return            // Backspace → DEL
        case 117: send("\u{1B}[3~"); return                     // Forward Delete
        case 36, 76: onKeyInput?(Data([0x0D])); return          // Return / Numpad Enter
        case 48:                                                 // Tab
            if event.modifierFlags.contains(.shift) { send("\u{1B}[Z") }
            else { onKeyInput?(Data([0x09])) }
            return
        case 53:  onKeyInput?(Data([0x1B])); return             // Escape
        case 126: send("\u{1B}[A"); return                      // Up
        case 125: send("\u{1B}[B"); return                      // Down
        case 123: send("\u{1B}[D"); return                      // Left
        case 124: send("\u{1B}[C"); return                      // Right
        case 115: send("\u{1B}[H"); return                      // Home
        case 119: send("\u{1B}[F"); return                      // End
        case 116: send("\u{1B}[5~"); return                     // Page Up
        case 121: send("\u{1B}[6~"); return                     // Page Down
        default: break
        }

        // Ctrl+key → control codes
        if event.modifierFlags.contains(.control),
           let chars = event.charactersIgnoringModifiers,
           let scalar = chars.unicodeScalars.first {
            let code = scalar.value
            if code >= UInt32(Character("a").asciiValue!),
               code <= UInt32(Character("z").asciiValue!) {
                onKeyInput?(Data([UInt8(code - UInt32(Character("a").asciiValue!) + 1)]))
                return
            }
        }

        // Regular character input
        if let chars = event.characters, !chars.isEmpty,
           let data = chars.data(using: .utf8) {
            onKeyInput?(data)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        if event.charactersIgnoringModifiers == "v" {
            if let string = NSPasteboard.general.string(forType: .string),
               let data = string.data(using: .utf8) {
                onKeyInput?(data)
            }
            return true
        }
        if event.charactersIgnoringModifiers == "c" {
            // Allow default copy behavior for text selection
            return super.performKeyEquivalent(with: event)
        }
        return false
    }

    private func send(_ string: String) {
        if let data = string.data(using: .utf8) { onKeyInput?(data) }
    }

    // MARK: - Terminal Output

    /// Strip ANSI/VT escape sequences from a string, returning clean text.
    /// Handles CSI (ESC [), OSC (ESC ]), SS3 (ESC O), and two-character sequences.
    private func stripANSI(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var idx = text.startIndex
        while idx < text.endIndex {
            let ch = text[idx]
            guard ch == "\u{1B}" else {
                result.append(ch)
                idx = text.index(after: idx)
                continue
            }

            let next = text.index(after: idx)
            guard next < text.endIndex else { break }

            switch text[next] {
            case "[":
                // CSI: ESC [ ... <letter>
                var j = text.index(after: next)
                while j < text.endIndex, !text[j].isLetter { j = text.index(after: j) }
                idx = j < text.endIndex ? text.index(after: j) : text.endIndex

            case "]":
                // OSC: ESC ] ... BEL  or  ESC ] ... ESC \
                // Used by shells to set window titles — produces garbage if not stripped.
                var j = text.index(after: next)
                while j < text.endIndex {
                    if text[j] == "\u{07}" { j = text.index(after: j); break }   // BEL
                    if text[j] == "\u{1B}" {
                        let k = text.index(after: j)
                        j = (k < text.endIndex && text[k] == "\\") ? text.index(after: k) : k
                        break
                    }
                    j = text.index(after: j)
                }
                idx = j

            case "O":
                // SS3: ESC O <char> — used for F1–F4
                let j = text.index(after: next)
                idx = j < text.endIndex ? text.index(after: j) : text.endIndex

            default:
                // Two-character sequence: ESC + one char (e.g. ESC M = reverse index)
                idx = text.index(after: next)
            }
        }
        return result
    }

    /// Append raw PTY output data to the text view.
    /// The PTY handles echo and line editing. We process backspace (\b) so the
    /// shell's "erase character" sequence (\b space \b) visually removes characters.
    func appendOutput(_ data: Data) {
        guard let storage = textStorage else { return }
        guard let raw = String(data: data, encoding: .utf8) else { return }

        let text = stripANSI(raw)
        if text.isEmpty { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0),
        ]

        // Process text, handling backspace while batching printable runs for performance
        var idx = text.startIndex
        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "\u{08}" {
                // Backspace: delete the last character unless it's a newline
                let len = storage.length
                if len > 0 {
                    let str = storage.string
                    if str.last != "\n" {
                        storage.deleteCharacters(in: NSRange(location: len - 1, length: 1))
                    }
                }
                idx = text.index(after: idx)
            } else if ch.asciiValue != nil && ch.asciiValue! < 32
                        && ch != "\n" && ch != "\r" && ch != "\t" {
                // Skip other control characters
                idx = text.index(after: idx)
            } else {
                // Collect a run of printable characters (plus \n, \r, \t)
                var end = text.index(after: idx)
                while end < text.endIndex {
                    let c = text[end]
                    if c == "\u{08}" ||
                       (c.asciiValue != nil && c.asciiValue! < 32
                        && c != "\n" && c != "\r" && c != "\t") {
                        break
                    }
                    end = text.index(after: end)
                }
                let run = String(text[idx..<end])
                storage.append(NSAttributedString(string: run, attributes: attrs))
                idx = end
            }
        }

        // Trim if buffer gets too large
        if storage.length > 500_000 {
            let excess = storage.length - 400_000
            storage.deleteCharacters(in: NSRange(location: 0, length: excess))
        }

        scrollToEndOfDocument(nil)
    }
}

// MARK: - NSViewRepresentable Bridge

struct TerminalTextViewRepresentable: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TerminalNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .black
        textView.insertionPointColor = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black

        context.coordinator.textView = textView

        // Wire keyboard input to PTY
        textView.onKeyInput = { [weak session] data in
            session?.write(data)
        }

        // Wire PTY output to text view.
        // Typed @MainActor so the compiler enforces call-site isolation.
        session.onOutput = { [weak coordinator = context.coordinator] data in
            coordinator?.textView?.appendOutput(data)
        }

        // Flush any output that arrived before view was ready
        session.flushPendingOutput()

        // Make text view first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        weak var textView: TerminalNSTextView?
    }
}

// MARK: - SwiftUI Terminal View

struct TerminalView: View {
    let session: TerminalSession
    let onClose: () -> Void

    private func updatePTYSize(_ size: CGSize) {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let charWidth = font.maximumAdvancement.width
        let lineHeight = font.ascender + abs(font.descender) + font.leading
        // Subtract the 4pt horizontal/vertical insets set in makeNSView.
        let cols = max(1, Int((size.width - 8) / charWidth))
        let rows = max(1, Int((size.height - 8) / lineHeight))
        session.resize(cols: cols, rows: rows)
    }

    var body: some View {
        VStack(spacing: 0) {
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

            GeometryReader { geo in
                TerminalTextViewRepresentable(session: session)
                    .onAppear { updatePTYSize(geo.size) }
                    .onChange(of: geo.size) { _, size in updatePTYSize(size) }
            }
        }
        .background(.black)
    }
}
