//class for the drop down
import SwiftUI

struct DropDownView: View {
    let title: String
    let prompt: String
    let options: [String]
    
    @State private var isExpanded = false
    @Binding var selection: String
    
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        VStack(alignment: .leading){
            Text(title)
                .font(.footnote)
                .foregroundStyle(.gray)
                .opacity(0.8)
            
            VStack{
                HStack{
                    Text(selection)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    
                }
                .frame(minHeight:40)
                .background(scheme == .dark ? .black : .white)
                .padding(.horizontal)
                .onTapGesture {
                    withAnimation(.snappy){ isExpanded.toggle() }
                }
            
                if isExpanded{
                    ScrollView {
                        VStack (spacing:20){
                            ForEach(options, id: \.self){ option in
                                HStack {
                                    Text(option)
                                        .foregroundStyle(selection == option ? Color.primary : .gray)
                                    
                                    Spacer()
                                    
                                    if selection == option {
                                        Image(systemName:"checkmark")
                                            .font(.subheadline)
                                    }
                                }
                                .padding(.horizontal)
                                .onTapGesture {
                                    withAnimation(.snappy) {
                                        selection = option
                                        print(selection)
                                        isExpanded.toggle()
                                        
                                    }
                                }
                            }
                        }
                    }
                    .transition(.move(edge: .bottom))
                    .frame(maxHeight: 200)
                }
            }
            .background(scheme == .dark ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .primary.opacity(0.2), radius: 4)
            .frame(maxWidth: 300)
            
        }
    }
}

#Preview {
    DropDownView(title: "To", prompt: "Select", options: ["Ashburn", "Loudoun Gateway", "Washington Dulles International Airport",
                                                          "Innovation Center", "Herndon", "Reston Town Center", "Wiehle-Reston East",
                                                          "Spring Hill", "Greensboro", "Tysons", "McLean", "East Falls Church",
                                                          "Ballston-MU", "Virginia Sq-GMU", "Clarendon", "Court House", "Rosslyn",
                                                          "Foggy Bottom-GWU", "Farragut West", "McPherson Sq", "Metro Center",
                                                          "Federal Triangle", "Smithsonian", "L'Enfant Plaza", "Federal Center SW",
                                                          "Capitol South", "Eastern Market", "Potomac Ave", "Stadium-Armory",
                                                          "Benning Rd", "Capitol Heights", "Addison Rd", "Morgan Blvd", "Downtown Largo"], selection: .constant("sdf"))
}
