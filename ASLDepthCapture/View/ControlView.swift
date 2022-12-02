//
//  ControlView.swift
//  ASLDepthCapture
//
//  Created by Ting Yu.

import SwiftUI

struct ControlView: View {
    //  @Binding var comicSelected: Bool
    //  @Binding var monoSelected: Bool
    //  @Binding var crystalSelected: Bool
    @Binding var isRecoding: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            ToggleButton(selected: $isRecoding, label: "Record")
            //      HStack(spacing: 12) {
            //        ToggleButton(selected: $comicSelected, label: "Comic")
            //        ToggleButton(selected: $monoSelected, label: "Mono")
            //        ToggleButton(selected: $crystalSelected, label: "Crystal")
        }
    }
}

struct ControlView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
//        ZStack {
//            Color.black
//                .edgesIgnoringSafeArea(.all)
//            
//            ControlView(
//                comicSelected: .constant(false),
//                monoSelected: .constant(true),
//                crystalSelected: .constant(true))
//        }
    }
}
