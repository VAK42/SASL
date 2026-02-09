from tensorflow.keras import layers
from tensorflow import keras
import tensorflow as tf
def createStaticCnnModel(inputShape=63, numClasses=26):
  model = keras.Sequential([
    layers.Input(shape=(inputShape,)),
    layers.Reshape((inputShape, 1)),
    layers.Conv1D(64, kernel_size=3, activation='relu', padding='same'),
    layers.BatchNormalization(),
    layers.Conv1D(128, kernel_size=3, activation='relu', padding='same'),
    layers.BatchNormalization(),
    layers.MaxPooling1D(pool_size=2),
    layers.Conv1D(256, kernel_size=3, activation='relu', padding='same'),
    layers.BatchNormalization(),
    layers.GlobalAveragePooling1D(),
    layers.Dense(256, activation='relu'),
    layers.Dropout(0.5),
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
  model = createStaticCnnModel()
  model.summary()