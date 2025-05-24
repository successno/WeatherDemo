import SwiftUI

struct WindView: View {
    let windDirection: String
    let windPower: String
    @State var textColor: Color = .black
    
    init(windDirection: String, windPower: String, textColor: Color = .black) {
        self.windDirection = windDirection
        self.windPower = windPower
        self._textColor = State(initialValue: textColor)
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .cornerRadius(15)
                .foregroundColor(.white)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "wind")
                                .foregroundColor(.gray)
                            Text("风")
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 5)
                        
                        HStack {
                            Text("风向")
                                .font(.footnote)
                            Spacer()
                            Text("风力")
                                .font(.footnote)
                        }
                        
                        HStack {
                            Text(windDirection)
                                .fontWeight(.bold)
                                .foregroundColor(textColor)
                            Spacer()
                            Text(windPower)
                                .fontWeight(.bold)
                                .foregroundColor(textColor)
                        }
                    }
                    .padding()
                }
        }
        .frame(height: 100)
        .padding(20)
    }
}
