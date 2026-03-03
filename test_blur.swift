import SwiftUI
import CoreImage.CIFilterBuiltins

@main
struct BlurTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    @State private var radius: CGFloat = 80
    var body: some View {
        ZStack {
            BackdropBlurView(radius: radius)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Test Settings")
                    .font(.largeTitle)
                Slider(value: $radius, in: 0...100)
                    .padding()
            }
        }
        .frame(width: 400, height: 300)
        .background(Color.clear)
    }
}

struct BackdropBlurView: NSViewRepresentable {
    var radius: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer else { return }
        if radius > 0 {
            let filter = CIFilter(name: "CIGaussianBlur")!
            filter.setValue(radius / 4.0, forKey: kCIInputRadiusKey) // Scaled
            layer.backgroundFilters = [filter]
        } else {
            layer.backgroundFilters = nil
        }
    }
}
