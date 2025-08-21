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
        case "action_open_messages":
            print("액션 실행: 메시지 앱 열기")
            openURL(urlString: "sms:")
        case "action_open_calendar":
            print("액션 실행: 캘린더 앱 열기")
            openURL(urlString: "calshow://")
        case "action_open_settings":
            print("액션 실행: 설정 앱 열기")
            openURL(urlString: UIApplication.openSettingsURLString)
        case "action_volume_mute":
            print("액션 실행: 볼륨 음소거/해제")
            toggleMute()
        default:
            break
        }
    }

    // MARK: - Private App Control
    private func openURL(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL string \(urlString)")
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("Error: Cannot open URL \(urlString)")
        }
    }
    
    // MARK: - Private Mute Control
    private var lastVolume: Float = 0.5 // Store last non-zero volume

    private func toggleMute() {
        let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
        guard let currentVolume = slider?.value else { return }

        if currentVolume > 0.0 {
            lastVolume = currentVolume // Save current volume before muting
            setVolume(to: 0.0)
        } else {
            setVolume(to: lastVolume) // Restore last volume
        }
    }

    // MARK: - Private Brightness Control

    private func setBrightness(to level: CGFloat) {
        let clampedLevel = max(0.0, min(1.0, level))
        UIScreen.main.brightness = clampedLevel
    }
    
    private func increaseBrightness() {
        // 순환 로직
        var newBrightness = UIScreen.main.brightness + 0.5
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
        
        // 활성 창 장면과 해당 키 창 찾기
        if let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first as? UIWindowScene,
           let window = windowScene.windows.filter({ $0.isKeyWindow }).first {
            volumeView.center = CGPoint(x: -1000, y: -1000)
            window.addSubview(volumeView)
            self.volumeView = volumeView
        } else {
            print("Error: MPVolumeView를 찾을 수 없음")
        }
    }

    private func setVolume(to value: Float) {
        let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.setValue(value, animated: false)
        }
    }

    private func increaseVolume() {
        // << [수정] 슬라이더에서 직접 값 읽어와서 버그 해결 + 순환 로직 추가
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value + 0.1
        if newVolume > 1.0 {
            newVolume = 0.1
        }
        setVolume(to: newVolume)
    }

    private func decreaseVolume() {
        // << [수정] 슬라이더에서 직접 값 읽어와서 버그 해결 + 순환 로직 추가
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        var newVolume = slider.value - 0.1
        if newVolume < 0.0 {
            newVolume = 0.9
        }
        setVolume(to: newVolume)
    }
}
