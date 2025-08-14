import logging
logger = logging.getLogger(__name__)
import numpy as np

class DuplicateChecker:

    @staticmethod
    def check(vectors1, vectors2, tolerance):
        if vectors1.shape[0] == 0 or vectors2.shape[0] == 0:
            return {'total_count': vectors1.shape[0], 'duplicate_count': 0, 'duplicate_rate': 0.0}
        duplicate_count = sum(1 for v1 in vectors1 if np.any(np.all(np.isclose(v1, vectors2, atol=tolerance), axis=1)))
        rate = (duplicate_count / vectors1.shape[0]) * 100 if vectors1.shape[0] > 0 else 0.0
        return {'total_count': vectors1.shape[0], 'duplicate_count': duplicate_count, 'duplicate_rate': rate}

    # 신규: inc의 각 라벨/데이터을 basic의 모든 라벨/데이터를 순차적으로 비교하고, 임계치 초과 시 즉시 종료
    def check_incremental_vs_all(self, inc_grouped, base_grouped, threshold, tolerance):
        """
        예)
        D vs A -> (임계 초과면 True 반환, 종료)
        D vs B -> ...
        D vs C -> ...
        다른 inc 라벨이 존재하면 동일 로직 반복
        """
        for inc_label, inc_vectors in inc_grouped.items():
            for basic_label, basic_vectors in base_grouped.items():
                report = self.check(inc_vectors, basic_vectors, tolerance=tolerance)
                logger.info(
                    f"[교차비교] inc '{inc_label}' vs basic '{basic_label}': "
                    f"{report['duplicate_count']}/{report['total_count']} "
                    f"({report['duplicate_rate']:.2f}%)"
                )
                # 요구사항: "임계치를 넘는다면" → '>' 비교 유지
                if report['duplicate_rate'] > threshold:
                    logger.error(
                        f"[중단] inc '{inc_label}'가 basic '{basic_label}'와의 중복률 "
                        f"{report['duplicate_rate']:.2f}%로 임계치 {threshold}% 초과"
                    )
                    return True  # True면 학습 종료
        return False  # False면 통과