import numpy as np

class DuplicateChecker:
    # 두 NumPy 벡터 배열 간의 중복을 계산하는 순수 알고리즘 클래스.
    # `np.allclose`를 사용하여 부동소수점 벡터의 유사성을 비교합니다.
    
    def __init__(self, tolerance: float = 1e-7):
        
        self.tolerance = tolerance

    def check(self, source_vectors: np.ndarray, target_vectors: np.ndarray):
        # 입력 데이터가 유효하지 않거나 비어있는 경우, 0% 중복으로 처리
        
        if source_vectors is None or target_vectors is None or source_vectors.ndim < 2 or target_vectors.ndim < 2 or source_vectors.shape[0] == 0:
            return {"total_count": 0, "duplicate_count": 0, "duplicate_rate": 0.0}

        total_count = len(source_vectors)
        duplicate_count = 0
        
        # 효율적인 비교를 위해 target_vectors가 비어있지 않은지 확인
        if target_vectors.shape[0] > 0:
            # source_vectors의 각 벡터에 대해 반복
            for src_vec in source_vectors:
                # target_vectors의 모든 벡터와 비교
                for tgt_vec in target_vectors:
                    if np.allclose(src_vec, tgt_vec, atol=self.tolerance):
                        duplicate_count += 1
                        break  # 중복을 한 번 찾으면 다음 소스 벡터로 넘어감

        rate = (duplicate_count / total_count) * 100 if total_count > 0 else 0
        return {"total_count": total_count, "duplicate_count": duplicate_count, "duplicate_rate": rate}
