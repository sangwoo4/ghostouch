import Foundation
import UIKit
import MediaPlayer
import AVFoundation

class DeviceControlService {

    private var volumeView: MPVolumeView?

    init() {
        setupVolumeView()
    }

    public func handleAction(_ actionName: String) {
        switch actionName {
        case "action_volume_up":
            print("액션 실행: 볼륨 증가")
            increaseVolume()
        case "action_volume_down":
            print("액션 실행: 볼륨 감소")
            decreaseVolume()
        case "action_brightness_up":
            print("액션 실행: 화면 밝기 증가")
            increaseBrightness()
        case "action_brightness_down":
            print("액션 실행: 화면 밝기 감소")
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