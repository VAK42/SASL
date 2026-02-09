import numpy as np
import sys
import os
from sklearn.model_selection import train_test_split
from pathlib import Path
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
sys.path.append(str(Path(__file__).parent))
from models.staticCnn import createStaticCnnModel
def loadData(dataPath):
  landmarks = np.load(dataPath / "landmarks.npy")
  labels = np.load(dataPath / "labels.npy")
  labelMap = np.load(dataPath / "labelMap.npy", allow_pickle=True).item()
  return landmarks, labels, labelMap
def trainModel(dataPath, outputPath, epochs=100, batchSize=64):
  landmarks, labels, labelMap = loadData(dataPath)
  numClasses = len(labelMap)
  print(f"Loaded {len(landmarks)} Samples, {numClasses} Classes")
  xTrain, xTest, yTrain, yTest = train_test_split(
    landmarks, labels, test_size=0.2, random_state=42, stratify=labels
  )
  model = createStaticCnnModel(inputShape=63, numClasses=numClasses)
  model.fit(
    xTrain, yTrain,
    validation_data=(xTest, yTest),
    epochs=epochs,
    batch_size=batchSize,
    verbose=1
  )
  testLoss, testAcc = model.evaluate(xTest, yTest, verbose=0)
  print(f"Test Accuracy: {testAcc:.4f}")
  outputPath = Path(outputPath)
  outputPath.mkdir(parents=True, exist_ok=True)
  model.save(outputPath / "staticCnn.keras")
  np.save(outputPath / "labelMap.npy", labelMap)
  print(f"Model Saved To {outputPath / 'staticCnn.keras'}")
  return model, testAcc
if __name__ == "__main__":
  dataPath = Path(__file__).parent / "data" / "processed"
  outputPath = Path(__file__).parent / "savedModels"
  trainModel(dataPath, outputPath)