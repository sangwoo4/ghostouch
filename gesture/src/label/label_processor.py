import json
import os
import logging
from typing import Dict

logger = logging.getLogger(__name__)

class LabelProcessor:
    """
    라벨 맵을 처리하고 관리하는 클래스.
    기존 및 증분 라벨 맵을 결합하여 새로운 통합 라벨 맵을 생성하는 기능을 제공합니다.
    """

    @staticmethod
    def combine_label_maps(basic_map: Dict[str, int], incremental_map: Dict[str, int], combined_map_save_path: str) -> Dict[str, int]:
        """
        기존 라벨 맵과 증분 라벨 맵을 결합하여 새로운 통합 라벨 맵을 생성합니다.
        새로운 라벨에는 순차적인 인덱스를 부여합니다.

        Args:
            basic_map (Dict[str, int]): 기본 라벨 맵 딕셔너리.
            incremental_map (Dict[str, int]): 증분 라벨 맵 딕셔너리.
            combined_map_save_path (str): 통합 라벨 맵을 저장할 JSON 파일의 경로.

        Returns:
            Dict[str, int]: 생성된 통합 라벨 맵 딕셔너리.
        """
        combined_map: Dict[str, int] = {}
        current_idx = 0

        # 기본 라벨 맵 로드 및 결합
        for label_str in sorted(basic_map.keys()):
            if label_str not in combined_map:
                combined_map[label_str] = current_idx
                current_idx += 1

        # 증분 라벨 맵 로드 및 결합 (기존 라벨과 중복되지 않는 경우에만 추가)
        for label_str in sorted(incremental_map.keys()):
            if label_str not in combined_map:
                combined_map[label_str] = current_idx
                current_idx += 1

        # 통합 라벨 맵 저장
        os.makedirs(os.path.dirname(combined_map_save_path), exist_ok=True) # Ensure directory exists
        with open(combined_map_save_path, 'w') as f:
            json.dump(combined_map, f, indent=4)
        logger.info(f"----- 통합 라벨이 저장되었습니다.: {combined_map_save_path}")
        return combined_map
