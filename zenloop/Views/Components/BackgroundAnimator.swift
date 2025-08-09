//
//  BackgroundAnimator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 08/08/2025.
//

import SwiftUI

class BackgroundAnimator: ObservableObject {
    @Published var offset: CGFloat = 0
    private var displayLink: CADisplayLink?
    
    func startAnimation() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateAnimation() {
        offset += 0.5
    }
    
    deinit {
        stopAnimation()
    }
}