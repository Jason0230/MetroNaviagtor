import SwiftUI
import AVFoundation

struct Alert: View {
    
    @State private var soundPlayer: AVAudioPlayer?
    @State private var showAlert: Bool = false
    
    @State private var width: CGFloat = UIScreen.main.bounds.width * 0.9
    @State private var height: CGFloat = 100
    
    @ObservedObject var viewModel = Navigation.shared
    
    var body: some View {
        ZStack{
           if !viewModel.alertTitle.isEmpty && !viewModel.alertBody.isEmpty {
                VStack(spacing: 10){
                    Text(viewModel.alertTitle).font(Font.custom("Avenir", size: 25))
                        .bold()
                    
                    Text(viewModel.alertBody).font(Font.custom("Avenir", size: 15)).multilineTextAlignment(.center)
                }
                .frame(width: width, height: height)
                .foregroundColor(.white).background(.red)
                .cornerRadius(50)
                .transition(.move(edge: .top))
                .shadow(radius: 8)
                .onAppear(){
                    playAlertSound()
                }
                .padding(.top, 10)
               
            }
        }
        .onAppear {
            showNotification()
        }
        .transition(.move(edge: .top))
        .frame(maxWidth: width, maxHeight: height, alignment: .top)
    }
    
    func playAlertSound(){
        guard let soundURL = Bundle.main.url(forResource: "dingSound", withExtension: "mp3") else {
                    print("Sound file not found")
                    return
                }

                do {
                    soundPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    soundPlayer?.volume = 0.5
                    soundPlayer?.play()
                } catch {
                    print("Error playing sound: \(error.localizedDescription)")
                }
    }
    
    // Function to show and auto-dismiss the alert
    func showNotification() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Auto-hide after 3 seconds
            withAnimation(.easeInOut(duration: 0.5)) {
                showAlert = false
            }
        }
    }
}

#Preview {
    Alert()
}
