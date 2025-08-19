import Foundation
import UIKit
import MediaPlayer
import AVFoundation

class DeviceControlService {

    private var volumeView: MPVolumeView?

    init() {
        setupVolumeView()
    }

    public func handleGesture(_ gestureName: String) {
        switch gestureName {
        case "paper":
            print("제스처 인식: paper. 볼륨을 높입니다.")
            increaseVolume()
        case "rock":
            print("제스처 인식: rock. 밝기를 높입니다.")
            increaseBrightness()
        case "thumbs_down":
            print("제스처 인식: thumbs_down. 볼륨을 낮춥니다.")
            decreaseVolume()
        case "fist":
            print("제스처 인식: fist. 밝기를 낮춥니다.")
            decreaseBrightness()
        default:
            break
        }
    }

    // MARK: - Private Brightness Control

    private func setBrightness(to level: CGFloat) {
        let clampedLevel = max(0.0, min(1.0, level))
        UIScreen.main.brightness = clampedLevel
    }
    
    private func increaseBrightness() {
        // << [수정] 순환 로직 추가
        var newBrightness = UIScreen.main.brightness + 0.1
        // 1.0을 초과하면 0.1로 (10%)
        if newBrightness > 1.0 {
            newBrightness = 0.1
        }
        setBrightness(to: newBrightness)
    }
    
    private func decreaseBrightness() {
        // << [수정] 순환 로직 추가
        var newBrightness = UIScreen.main.brightness - 0.1
        // 0.0 미만이 되면 0.9로 (90%)
        if newBrightness < 0.0 {
            newBrightness = 0.9
        }
        setBrightness(to: newBrightness)
    }

    // MARK: - Private Volume Control

    private func setupVolumeView() {
        let volumeView = MPVolumeView(frame: .zero)
        guard let window = UIApplication.shared.windows.filter({$0.isKeyWindow}).first else { return }
        volumeView.center = CGPoint(x: -1000, y: -1000)
        window.addSubview(volumeView)
        self.volumeView = volumeView
    }

    private func setVolume(to value: Float) {
        let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.setValue(value, animated: false)
        }
    }

    private func increaseVolume() {
        // << [수정] 슬라이더에서 직접 값을 읽어와서 버그 해결 + 순환 로직 추가
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value + 0.1
        if newVolume > 1.0 {
            newVolume = 0.1
        }
        setVolume(to: newVolume)
    }

    private func decreaseVolume() {
        // << [수정] 슬라이더에서 직접 값을 읽어와서 버그 해결 + 순환 로직 추가
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value - 0.1
        if newVolume < 0.0 {
            newVolume = 0.9
        }
        setVolume(to: newVolume)
    }
}