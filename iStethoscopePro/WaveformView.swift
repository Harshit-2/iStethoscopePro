//
//  WaveformView.swift
//  iStethoscopePro
//
//  Created by Harshit ‎ on 12/21/24.
//

import UIKit

class WaveformView: UIView {
    private var waveformPath = UIBezierPath()
    private var points: [CGPoint] = []
    private let maxPoints = 100
    private let waveformColor = UIColor.systemBlue
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
//        backgroundColor = UIColor.opaqueSeparator
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 8
    }
    
    override func draw(_ rect: CGRect) {
        waveformColor.setStroke()
        waveformPath.stroke()
    }
    
    func update(withAmplitude amplitude: Float) {
        // Convert amplitude to point
        let centerY = bounds.height / 2
        let scaledAmplitude = CGFloat(amplitude) * bounds.height
        let point = CGPoint(x: bounds.width, y: centerY - scaledAmplitude)
        
        // Add new point and remove old if needed
        points.append(point)
        if points.count > maxPoints {
            points.removeFirst()
        }
        
        // Create new path
        waveformPath = UIBezierPath()
        if points.count > 0 {
            waveformPath.move(to: points[0])
            for i in 1..<points.count {
                let point = points[i]
                let previousPoint = points[i-1]
                
                // Calculate control points for smooth curve
                let controlPoint1 = CGPoint(x: (previousPoint.x + point.x) / 2, y: previousPoint.y)
                let controlPoint2 = CGPoint(x: (previousPoint.x + point.x) / 2, y: point.y)
                
                waveformPath.addCurve(to: point,
                                    controlPoint1: controlPoint1,
                                    controlPoint2: controlPoint2)
            }
        }
        
        // Shift existing points left
        for i in 0..<points.count {
            points[i].x -= bounds.width / CGFloat(maxPoints)
        }
        
        // Trigger redraw
        setNeedsDisplay()
    }
}
