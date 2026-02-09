from tensorflow.keras import layers
from tensorflow import keras
import tensorflow as tf
def createDynamicLstmModel(sequenceLength=30, featuresPerFrame=63, numClasses=10):
  model = keras.Sequential([
    layers.Input(shape=(sequenceLength, featuresPerFrame)),
    layers.LSTM(128, return_sequences=True),
    layers.Dropout(0.3),
    layers.LSTM(64, return_sequences=False),
    layers.Dropout(0.3),
    layers.Dense(128, activation='relu'),
    layers.Dropout(0.3),
    layers.Dense(numClasses, activation='softmax')
  ])
  model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
  )
  return model
def loadModel(modelPath):
  return keras.models.load_model(modelPath)
if __name__ == "__main__":
  model = createDynamicLstmModel()
  model.summary()