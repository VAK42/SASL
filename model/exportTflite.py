from pathlib import Path
import tensorflow as tf
def convertToTflite(modelPath, outputPath, quantize=True):
  model = tf.keras.models.load_model(modelPath)
  converter = tf.lite.TFLiteConverter.from_keras_model(model)
  if quantize:
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
  tfliteModel = converter.convert()
  outputPath = Path(outputPath)
  outputPath.parent.mkdir(parents=True, exist_ok=True)
  with open(outputPath, 'wb') as f:
    f.write(tfliteModel)
  print(f"TFLite Model Saved To {outputPath}")
  print(f"Model Size: {len(tfliteModel) / 1024:.2f} KB")
  return outputPath
if __name__ == "__main__":
  savedModelsPath = Path(__file__).parent / "savedModels"
  staticModelPath = savedModelsPath / "staticCnn.keras"
  if staticModelPath.exists():
    convertToTflite(
      staticModelPath,
      savedModelsPath / "staticCnn.tflite",
      quantize=True
    )
  dynamicModelPath = savedModelsPath / "dynamicLstm.keras"
  if dynamicModelPath.exists():
    convertToTflite(
      dynamicModelPath,
      savedModelsPath / "dynamicLstm.tflite",
      quantize=True
    )