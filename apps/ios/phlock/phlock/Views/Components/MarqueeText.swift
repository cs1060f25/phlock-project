import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var leftFade: CGFloat = 16
    var rightFade: CGFloat = 16
    var startDelay: Double = 2.0
    var alignment: Alignment = .leading
    
    @State private var animate = false
    @State private var textSize: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            
            ZStack(alignment: alignment) {
                // 1. Hidden Text for Measurement
                Text(text)
                    .font(font)
                    .fixedSize() // Forces it to be its ideal size
                    .lineLimit(1)
                    .opacity(0)
                    .background(GeometryReader { textGeo in
                        Color.clear
                            .onAppear { textSize = textGeo.size.width }
                            .onChange(of: text) { _ in 
                                textSize = textGeo.size.width 
                                animate = false
                            }
                    })
                
                // 2. Visible Content
                if textSize > containerWidth {
                    // Scrolling Text
                    Text(text)
                        .font(font)
                        .fixedSize()
                        .offset(x: animate ? -textSize + containerWidth : 0)
                        .clipped()
                        .onAppear {
                            // Trigger animation
                            startAnimation()
                        }
                        .onChange(of: text) { _ in
                            animate = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                startAnimation()
                            }
                        }
                        .onChange(of: textSize) { _ in
                             // Restart if size changes (e.g. font load)
                             animate = false
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                 startAnimation()
                             }
                        }
                } else {
                    // Static Text
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: alignment)
                }
            }
        }
        .frame(height: 40)
    }
    
    private func startAnimation() {
        guard textSize > 0 else { return }
        // Ensure we start from 0
        animate = false
        
        // Calculate duration based on width difference to keep speed consistent
        // or just based on text width
        // Increased speed by 2.5x (30.0 * 2.5 = 75.0)
        let duration = Double(textSize) / 75.0 
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.linear(duration: duration).delay(startDelay).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
