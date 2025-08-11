class TestConfig:
    """
    실시간 제스처 인식 테스트 관련 설정을 관리하는 클래스
    카메라 해상도, 미디어파이프 감지 임계값 등을 정의
    """
    # 실시간 테스트 관련 설정
    CAM_WIDTH = 640
    CAM_HEIGHT = 480
    MIN_DETECTION_CONFIDENCE = 0.5
    MIN_TRACKING_CONFIDENCE = 0.5
    CONFIDENCE_THRESHOLD = 0.8