import numpy as np
import joblib
import os
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from pathlib import Path
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
def loadData(dataPath):
  landmarks = np.load(dataPath / "landmarks.npy")
  labels = np.load(dataPath / "labels.npy")
  labelMap = np.load(dataPath / "labelMap.npy", allow_pickle=True).item()
  return landmarks, labels, labelMap
def trainRandomForest(dataPath, outputPath):
  features, labels, labelMap = loadData(dataPath)
  numClasses = len(labelMap)
  print(f"Loaded {len(features)} Samples, {features.shape[1]} Features, {numClasses} Classes")
  xTrain, xTest, yTrain, yTest = train_test_split(
    features, labels, test_size=0.2, random_state=42, stratify=labels
  )
  print("Training Random Forest Classifier...")
  clf = RandomForestClassifier(
    n_estimators=200,
    max_depth=30,
    min_samples_split=2,
    min_samples_leaf=1,
    n_jobs=-1,
    random_state=42,
    verbose=1
  )
  clf.fit(xTrain, yTrain)
  yPred = clf.predict(xTest)
  testAcc = accuracy_score(yTest, yPred)
  print(f"Test Accuracy: {testAcc:.4f}")
  outputPath = Path(outputPath)
  outputPath.mkdir(parents=True, exist_ok=True)
  joblib.dump(clf, outputPath / "randomForest.joblib")
  np.save(outputPath / "labelMap.npy", labelMap)
  print(f"Model Saved To {outputPath / 'randomForest.joblib'}")
  return clf, testAcc
if __name__ == "__main__":
  dataPath = Path(__file__).parent / "data" / "processed"
  outputPath = Path(__file__).parent / "savedModels"
  trainRandomForest(dataPath, outputPath)