//
//  ContentView.swift
//  20-20-20
//
//  Created by Tony Hu on 6/16/20.
//  Copyright © 2020 Tony Hu. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var myWindow:NSWindow?
    var setSkipped: ((Bool)->Void)?
    @available(OSX 10.15.0, *)
    var body: some View {
        VStack {
            Text("Look away for 20 seconds.")
            Button("Skip Break", action: {
                self.setSkipped?(true)
                self.myWindow?.close()
            })
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(Color.black)
                    .edgesIgnoringSafeArea(.all)
    }

}


struct ContentView_Previews: PreviewProvider {
    @available(OSX 10.15.0, *)
    static var previews: some View {
        ContentView(myWindow: nil, setSkipped: nil )
            
    }
}
