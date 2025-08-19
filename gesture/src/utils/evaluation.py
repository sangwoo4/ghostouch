import json
import os
import logging

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    precision_recall_curve,
    roc_curve,
    auc,
)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import label_binarize

class ModelEvaluator:
    """모델 평가의 전체 과정을 캡슐화하는 클래스"""

    def __init__(self, model_path, data_path, label_map_path, results_dir):
        """
        ModelEvaluator 인스턴스를 초기화

        Args:
            model_path (str): 평가 할 .keras 모델 파일의 경로
            data_path (str): 테스트 데이터가 포함 된 .npy 파일의 경로
            label_map_path (str): 라벨 맵 .json 파일의 경로
            results_dir (str): 평가 결과를 저장 할 디렉토리
        """
        self.model_path = model_path
        self.data_path = data_path
        self.label_map_path = label_map_path
        self.results_dir = results_dir
        os.makedirs(self.results_dir, exist_ok=True)

    def _plot_confusion_matrix(self, y_true, y_pred, class_names, normalize=None):
        """
        혼동 행렬을 계산하고 그림을 저장
        normalize 인자를 'true', 'pred', 'all'로 설정하여 정규화 할 수 있습니다
        """
        cm = confusion_matrix(y_true, y_pred)
        
        if normalize == 'true':
            cm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
            title = 'Normalized Confusion Matrix (Recall)'
            fmt = '.2f'
        else:
            title = 'Confusion Matrix'
            fmt = 'd'

        plt.figure(figsize=(10, 8))
        sns.heatmap(cm, annot=True, fmt=fmt, cmap='Blues', xticklabels=class_names, yticklabels=class_names)
        plt.ylabel('True Label')
        plt.xlabel('Predicted Label')
        plt.title(title)
        
        output_filename = f"confusion_matrix{'_' + normalize if normalize else ''}.png"
        plt.savefig(os.path.join(self.results_dir, output_filename))
        plt.close()

    def _plot_multiclass_roc_pr_curves(self, y_true_bin, y_pred_proba, n_classes, class_names):
        """각 클래스와 마이크로/매크로 평균에 대한 ROC 및 PR 커브 작성"""
        # ROC 커브
        fpr, tpr, roc_auc = dict(), dict(), dict()
        for i in range(n_classes):
            fpr[i], tpr[i], _ = roc_curve(y_true_bin[:, i], y_pred_proba[:, i])
            roc_auc[i] = auc(fpr[i], tpr[i])

        fpr["micro"], tpr["micro"], _ = roc_curve(y_true_bin.ravel(), y_pred_proba.ravel())
        roc_auc["micro"] = auc(fpr["micro"], tpr["micro"])

        all_fpr = np.unique(np.concatenate([fpr[i] for i in range(n_classes)]))
        mean_tpr = np.zeros_like(all_fpr)
        for i in range(n_classes):
            mean_tpr += np.interp(all_fpr, fpr[i], tpr[i])
        mean_tpr /= n_classes
        fpr["macro"] = all_fpr
        tpr["macro"] = mean_tpr
        roc_auc["macro"] = auc(fpr["macro"], tpr["macro"])

        plt.figure(figsize=(10, 8))
        plt.plot(fpr["micro"], tpr["micro"], label=f'Micro-average ROC curve (area = {roc_auc["micro"]:.2f})', color='deeppink', linestyle=':', linewidth=4)
        plt.plot(fpr["macro"], tpr["macro"], label=f'Macro-average ROC curve (area = {roc_auc["macro"]:.2f})', color='navy', linestyle=':', linewidth=4)
        for i in range(n_classes):
            plt.plot(fpr[i], tpr[i], label=f'ROC curve of class {class_names[i]} (area = {roc_auc[i]:.2f})')
        
        plt.plot([0, 1], [0, 1], 'k--')
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title('Multi-class Receiver Operating Characteristic (ROC)')
        plt.legend(loc="lower right")
        plt.savefig(os.path.join(self.results_dir, 'roc_curves.png'))
        plt.close()

        # PR 커브
        precision, recall, pr_auc = dict(), dict(), dict()
        for i in range(n_classes):
            precision[i], recall[i], _ = precision_recall_curve(y_true_bin[:, i], y_pred_proba[:, i])
            pr_auc[i] = auc(recall[i], precision[i])
            
        precision["micro"], recall["micro"], _ = precision_recall_curve(y_true_bin.ravel(), y_pred_proba.ravel())
        pr_auc["micro"] = average_precision_score(y_true_bin, y_pred_proba, average="micro")

        plt.figure(figsize=(10, 8))
        plt.plot(recall["micro"], precision["micro"], label=f'Micro-average PR curve (AUPRC = {pr_auc["micro"]:.2f})', color='deeppink', linestyle=':', linewidth=4)
        for i in range(n_classes):
            plt.plot(recall[i], precision[i], label=f'PR curve of class {class_names[i]} (AUPRC = {pr_auc[i]:.2f})')

        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('Recall')
        plt.ylabel('Precision')
        plt.title('Multi-class Precision-Recall (PR) Curve')
        plt.legend(loc="lower left")
        plt.savefig(os.path.join(self.results_dir, 'pr_curves.png'))
        plt.close()
        
        return roc_auc, pr_auc

    def run(self):
        """전체 평가 파이프라인을 실행하는 메인 함수"""
        logging.info("----- 모델 평가 시작")
        
        report_path = os.path.join(self.results_dir, 'evaluation_report.txt')
        
        # 1. 데이터, 모델, 라벨 로드
        logging.info(f"----- 모델 로딩: {self.model_path}...")
        model = tf.keras.models.load_model(self.model_path)
        
        logging.info(f"----- 데이터 로딩: {self.data_path}...")
        data = np.load(self.data_path, allow_pickle=True)
        X = data[:, :-1].astype(np.float32)
        y_string_labels = data[:, -1].astype(str)

        logging.info(f"----- 라벨 맵 로딩: {self.label_map_path}...")
        with open(self.label_map_path, 'r') as f:
            label_map = json.load(f)
        class_names = list(label_map.keys())
        n_classes = len(class_names)
        
        y_numeric_labels = np.array([label_map[label] for label in y_string_labels], dtype=int)

        # 학습 시와 동일한 테스트셋을 만들기 위해 train_test_split 적용
        _, X_test, _, y_test_numeric = train_test_split(
            X, y_numeric_labels, test_size=0.2, random_state=42, stratify=y_numeric_labels
        )

        # 2. 모델 예측 생성
        logging.info("----- 예측 생성 중")
        input_shape = (X_test.shape[1], 1)
        X_test_reshaped = X_test.reshape(-1, *input_shape)
        y_pred_proba = model.predict(X_test_reshaped)
        y_pred = np.argmax(y_pred_proba, axis=1)
        
        # 3. 평가 실행 및 결과 저장
        logging.info(f"----- 텍스트 보고서 저장: {report_path}")
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("### Final Model Performance Metrics ###\n\n")
            
            acc = accuracy_score(y_test_numeric, y_pred)
            balanced_acc = balanced_accuracy_score(y_test_numeric, y_pred)
            f.write("--- Accuracy & Balanced Accuracy ---\n")
            f.write(f"Accuracy: {acc:.4f}\n")
            f.write(f"Balanced Accuracy (Main Metric): {balanced_acc:.4f}\n\n")
            
            report = classification_report(y_test_numeric, y_pred, target_names=class_names)
            f.write("--- Precision, Recall, F1-Score ---\n")
            f.write(report)
            f.write("\n")
            
            y_test_bin = label_binarize(y_test_numeric, classes=range(n_classes))
            
            roc_auc, pr_auc = self._plot_multiclass_roc_pr_curves(y_test_bin, y_pred_proba, n_classes, class_names)
            f.write("--- ROC AUC & PR AUC (AUPRC) ---\n")
            f.write(f"Micro-average ROC AUC: {roc_auc['micro']:.4f}\n")
            f.write(f"Macro-average ROC AUC: {roc_auc['macro']:.4f}\n")
            f.write(f"Micro-average PR AUC (AUPRC): {pr_auc['micro']:.4f}\n\n")

            f.write("--- Macro F1-Score by Distance (Placeholder) ---\n")
            f.write("NOTE: This metric requires a dataset with distance information (e.g., 'near', 'mid', 'far') for each sample.\n")

        # 4. 예측 결과 CSV로 저장
        logging.info(f"----- 상세 예측 결과 저장: {os.path.join(self.results_dir, 'predictions.csv')}")
        prob_columns = [f'prob_{name}' for name in class_names]
        
        results_data = {
            'actual_label_id': y_test_numeric,
            'predicted_label_id': y_pred,
            'is_correct': y_test_numeric == y_pred
        }
        
        for i, col_name in enumerate(prob_columns):
            results_data[col_name] = y_pred_proba[:, i]
            
        df_results = pd.DataFrame(results_data)
        df_results.to_csv(os.path.join(self.results_dir, 'predictions.csv'), index_label='test_sample_index')

        logging.info("----- 혼동 행렬 그리는 중")
        self._plot_confusion_matrix(y_test_numeric, y_pred, class_names, normalize='true')
        
        logging.info(f"----- 평가 완료, 결과는 {self.results_dir}에 저장되었습니다")