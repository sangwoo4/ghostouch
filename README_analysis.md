# 📊 Model Evaluation & Analysis

## Preview
- 본 문서의 평가 지표는 증분 학습(combine) 모델을 기준으로 작성 됨
- 최초 학습(basic) 모델의 지표는 **analysis** 폴더를 참고
 
## 1. Enviroment
- **평가 환경**
  - Windows 11
  - Python 3.10.11
  - OpenCV 4.7.0.72
  - Tensorflow 2.19.0
  - Mediapipe 0.10.8
  - Pandas 2.2.2
  - numpy 2.0.2
  - seaborn 0.13.2

## 2. Dataset
- 데이터 구성 요소
  - 클래스 구성: paper, rock, scissors, one
  - 학습 데이터: 클래스 별 80장 (총 320장)
  - 테스트 데이터: 클래스 별 20장 (총 80장)
    
## 3. Training Setting
- 학습 설정
  - Optimizer: Adam(learning rate = 0.001)
  - Batch size: 16
  - Max Epoch: 1000
  - Callbacks: EarlyStopping, ReduceLROnPlateau

## 4. Evaluation Metrics
| Class      | Precision | Recall | F1-score | Support |
|------------|-----------|--------|----------|---------|
| paper      | 1.00      | 1.00   | 1.00     | 20      |
| rock       | 1.00      | 1.00   | 1.00     | 20      |
| scissors   | 1.00      | 1.00   | 1.00     | 20      |
| one        | 1.00      | 1.00   | 1.00     | 20      |
| **Accuracy** |           |        | **1.00** | **80** |
| **Macro Avg** | 1.00 | 1.00 | 1.00 | 80 |
| **Weighted Avg** | 1.00 | 1.00 | 1.00 | 80 |

## 5. Confusion Matrix
<p align="center">
<img src="https://github.com/user-attachments/assets/56c88749-3b31-47b7-a49d-42a05ad9441e" alt="Confusion Matrix" width="700"/>
</p>

## 6. ROC & PR Curves

### ROC Curve
<p align="center">
  <img src="https://github.com/user-attachments/assets/bec7b1c6-45bd-477e-96e3-0954a5d38784" alt="ROC Curve" width="700"/>
</p>

### PR Curve
<p align="center">
  <img src="https://github.com/user-attachments/assets/828f4b6e-bba4-4a3e-8ac6-cb82cd251e27" alt="PR Curve" width="700"/>
</p>

## 7. Incremental Learning Results
- 기존 데이터와 신규 데이터를 결합하여 학습 후 성능을 측정함
- 이번 평가에서는 baseline과 동일하게 모든 클래스에서 **100% 정확도** 달성
- 데이터 크기 확대 및 클래스 불균형 상황에서의 성능 변화는 추후 추가 실험 필요

## 8. Discussion
1. **모든 지표가 1.00 → 오분류 없음**
2. 향후 개선 방향  
   - world_landmark 데이터를 단순 'flatten()' 처리 대신 공간적,구조적 특성을 반영한 기법 적용
   - 증분 학습 시 기존 데이터 재사용 없이 성능을 유지할 수 있는 방식 도입
