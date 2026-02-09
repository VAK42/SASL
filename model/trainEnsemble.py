import warnings
import joblib
import os
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, VotingClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC
from pathlib import Path
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
warnings.filterwarnings('ignore')
def loadData(dataPath):
  rawFeatures = np.load(dataPath / "rawFeatures.npy")
  angleFeatures = np.load(dataPath / "angleFeatures.npy")
  distanceFeatures = np.load(dataPath / "distanceFeatures.npy")
  combinedFeatures = np.load(dataPath / "combinedFeatures.npy")
  labels = np.load(dataPath / "labels.npy")
  labelMap = np.load(dataPath / "labelMap.npy", allow_pickle=True).item()
  return {
    'raw': rawFeatures,
    'angles': angleFeatures,
    'distances': distanceFeatures,
    'combined': combinedFeatures
  }, labels, labelMap
def trainEnsemble(dataPath, outputPath):
  features, labels, labelMap = loadData(dataPath)
  numClasses = len(labelMap)
  print(f"Loaded {len(labels)} Samples, {numClasses} Classes")
  print(f"Raw: {features['raw'].shape[1]} features")
  print(f"Angles: {features['angles'].shape[1]} features")
  print(f"Distances: {features['distances'].shape[1]} features")
  print(f"Combined: {features['combined'].shape[1]} features")
  xTrain, xTest, yTrain, yTest = train_test_split(
    features['combined'], labels, test_size=0.2, random_state=42, stratify=labels
  )
  scaler = StandardScaler()
  xTrainScaled = scaler.fit_transform(xTrain)
  xTestScaled = scaler.transform(xTest)
  print("\nTraining Individual Models...")
  print("1. Random Forest")
  rf = RandomForestClassifier(n_estimators=300, max_depth=40, min_samples_split=2, n_jobs=-1, random_state=42, verbose=0)
  rf.fit(xTrainScaled, yTrain)
  rfAcc = accuracy_score(yTest, rf.predict(xTestScaled))
  print(f"Random Forest Accuracy: {rfAcc:.4f}")
  print("2. Logistic Regression")
  lr = LogisticRegression(max_iter=1000, solver='lbfgs', n_jobs=-1, random_state=42)
  lr.fit(xTrainScaled, yTrain)
  lrAcc = accuracy_score(yTest, lr.predict(xTestScaled))
  print(f"Logistic Regression Accuracy: {lrAcc:.4f}")
  print("3. MLP Neural Network")
  mlp = MLPClassifier(hidden_layer_sizes=(256, 128, 64), max_iter=500, early_stopping=True, random_state=42, verbose=0)
  mlp.fit(xTrainScaled, yTrain)
  mlpAcc = accuracy_score(yTest, mlp.predict(xTestScaled))
  print(f"MLP Accuracy: {mlpAcc:.4f}")
  print("4. SVM (RBF Kernel)")
  svm = SVC(kernel='rbf', probability=True, random_state=42, C=10, gamma='scale')
  svm.fit(xTrainScaled, yTrain)
  svmAcc = accuracy_score(yTest, svm.predict(xTestScaled))
  print(f"SVM Accuracy: {svmAcc:.4f}")
  print("\n5. Creating Voting Ensemble")
  ensemble = VotingClassifier(
    estimators=[('rf', rf), ('lr', lr), ('mlp', mlp), ('svm', svm)],
    voting='soft',
    n_jobs=-1
  )
  ensemble.fit(xTrainScaled, yTrain)
  yPred = ensemble.predict(xTestScaled)
  ensembleAcc = accuracy_score(yTest, yPred)
  print(f"\n=== ENSEMBLE ACCURACY: {ensembleAcc:.4f} ===")
  reverseLabelMap = {v: k for k, v in labelMap.items()}
  for classIdx in sorted(reverseLabelMap.keys()):
    mask = yTest == classIdx
    if mask.sum() > 0:
      classAcc = accuracy_score(yTest[mask], yPred[mask])
      print(f"  {reverseLabelMap[classIdx]}: {classAcc:.2%}")
  outputPath = Path(outputPath)
  outputPath.mkdir(parents=True, exist_ok=True)
  joblib.dump(ensemble, outputPath / "ensemble.joblib")
  joblib.dump(scaler, outputPath / "scaler.joblib")
  np.save(outputPath / "labelMap.npy", labelMap)
  print(f"\nModels Saved To {outputPath}")
  return ensemble, scaler, ensembleAcc
if __name__ == "__main__":
  dataPath = Path(__file__).parent / "data" / "processed"
  outputPath = Path(__file__).parent / "savedModels"
  trainEnsemble(dataPath, outputPath)