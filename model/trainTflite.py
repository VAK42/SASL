import warnings
import joblib
import os
import tensorflow as tf
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from tensorflow.keras import layers
from tensorflow import keras
from pathlib import Path
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
warnings.filterwarnings('ignore')
def loadData(dataPath):
  combinedFeatures = np.load(dataPath / "combinedFeatures.npy")
  labels = np.load(dataPath / "labels.npy")
  labelMap = np.load(dataPath / "labelMap.npy", allow_pickle=True).item()
  return combinedFeatures, labels, labelMap
def createMlpModel(inputShape, numClasses):
  model = keras.Sequential([
    layers.Input(shape=(inputShape,)),
    layers.Dense(256, activation='relu'),
    layers.BatchNormalization(),
    layers.Dropout(0.3),
    layers.Dense(128, activation='relu'),
    layers.BatchNormalization(),
    layers.Dropout(0.3),
    layers.Dense(64, activation='relu'),
    layers.BatchNormalization(),
    layers.Dense(numClasses, activation='softmax')
  ])
  model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
  )
  return model
def trainTfliteModel(dataPath, outputPath, epochs=100, batchSize=64):
  features, labels, labelMap = loadData(dataPath)
  numClasses = len(labelMap)
  inputShape = features.shape[1]
  print(f"Loaded {len(features)} Samples, {inputShape} Features, {numClasses} Classes")
  xTrain, xTest, yTrain, yTest = train_test_split(
    features, labels, test_size=0.2, random_state=42, stratify=labels
  )
  scaler = StandardScaler()
  xTrainScaled = scaler.fit_transform(xTrain)
  xTestScaled = scaler.transform(xTest)
  scalerParams = {
    'mean': scaler.mean_,
    'scale': scaler.scale_
  }
  np.save(outputPath / "scalerParams.npy", scalerParams)
  model = createMlpModel(inputShape, numClasses)
  checkpoint = keras.callbacks.ModelCheckpoint(
    str(outputPath / "bestModel.keras"),
    monitor='val_accuracy',
    save_best_only=True,
    mode='max',
    verbose=1
  )
  history = model.fit(
    xTrainScaled, yTrain,
    validation_data=(xTestScaled, yTest),
    epochs=epochs,
    batch_size=batchSize,
    callbacks=[checkpoint],
    verbose=1
  )
  model = keras.models.load_model(str(outputPath / "bestModel.keras"))
  testLoss, testAcc = model.evaluate(xTestScaled, yTest, verbose=0)
  print(f"Test Accuracy: {testAcc:.4f}")
  converter = tf.lite.TFLiteConverter.from_keras_model(model)
  converter.optimizations = [tf.lite.Optimize.DEFAULT]
  tfliteModel = converter.convert()
  with open(outputPath / "saslModel.tflite", "wb") as f:
    f.write(tfliteModel)
  np.save(outputPath / "labelMap.npy", labelMap)
  print(f"TFLite Model Saved To {outputPath / 'saslModel.tflite'}")
  return model, testAcc
if __name__ == "__main__":
  dataPath = Path(__file__).parent / "data" / "processed"
  outputPath = Path(__file__).parent / "savedModels"
  trainTfliteModel(dataPath, outputPath)