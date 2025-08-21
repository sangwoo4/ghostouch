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
            print("액션 실행: 볼륨 올리기")
            increaseVolume()
        case "action_volume_down":
            print("액션 실행: 볼륨 내리기")
            decreaseVolume()
        case "action_brightness_up":
            print("액션 실행: 화면 밝기 올리기")
            increaseBrightness()
        case "action_brightness_down":
            print("액션 실행: 화면 밝기 내리기")
            decreaseBrightness()
        case "action_open_messages":
            print("액션 실행: 메시지 열기")
            openURL(urlString: "sms:")
        case "action_open_calendar":
            print("액션 실행: 캘린더 열기")
            openURL(urlString: "calshow://")
        case "action_open_settings":
            print("액션 실행: 설정 열기")
            openURL(urlString: UIApplication.openSettingsURLString)
        case "action_volume_mute":
            print("액션 실행: 음소거/해제")
            toggleMute()
        default:
            break
        }
    }

    // MARK: - 앱 열기
    private func openURL(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("에러: 잘못된 URL \(urlString)")
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("에러: URL 열 수 없음 \(urlString)")
        }
    }
    
    // MARK: - 음소거 제어
    private var lastVolume: Float = 0.5

    private func toggleMute() {
        let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
        guard let currentVolume = slider?.value else { return }

        if currentVolume > 0.0 {
            lastVolume = currentVolume
            setVolume(to: 0.0)
        } else {
            setVolume(to: lastVolume)
        }
    }

    // MARK: - 밝기 제어
    private func setBrightness(to level: CGFloat) {
        let clampedLevel = max(0.0, min(1.0, level))
        UIScreen.main.brightness = clampedLevel
    }
    
    private func increaseBrightness() {
        var newBrightness = UIScreen.main.brightness + 0.5
        if newBrightness > 1.0 {
            newBrightness = 0.1
        }
        setBrightness(to: newBrightness)
    }
    
    private func decreaseBrightness() {
        var newBrightness = UIScreen.main.brightness - 0.1
        if newBrightness < 0.0 {
            newBrightness = 0.9
        }
        setBrightness(to: newBrightness)
    }

    // MARK: - 볼륨 제어
    private func setupVolumeView() {
        let volumeView = MPVolumeView(frame: .zero)
        
        if let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first as? UIWindowScene,
           let window = windowScene.windows.filter({ $0.isKeyWindow }).first {
            volumeView.center = CGPoint(x: -1000, y: -1000)
            window.addSubview(volumeView)
            self.volumeView = volumeView
        } else {
            print("에러: MPVolumeView를 찾을 수 없음")
        }
    }

    private func setVolume(to value: Float) {
        let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.setValue(value, animated: false)
        }
    }

    private func increaseVolume() {
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value + 0.1
        if newVolume > 1.0 {
            newVolume = 0.1
        }
        setVolume(to: newVolume)
    }

    private func decreaseVolume() {
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value - 0.1
        if newVolume < 0.0 {
            newVolume = 0.9
        }
        setVolume(to: newVolume)
    }
}
