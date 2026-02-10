import warnings
import math
import cv2
import os
import tensorflow as tf
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe import Image, ImageFormat
from mediapipe.tasks import python
from collections import Counter
from pathlib import Path
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
warnings.filterwarnings('ignore')
def extractRawFeatures(landmarks):
  points = landmarks.reshape(21, 3)
  wrist = points[0].copy()
  centered = points - wrist
  maxDist = np.max(np.linalg.norm(centered[1:, :2], axis=1)) + 1e-6
  centered[:, :2] /= maxDist
  return centered.flatten()
def extractAngleFeatures(landmarks):
  points = [(landmarks[i*3], landmarks[i*3+1]) for i in range(21)]
  wrist = points[0]
  maxDist = max(math.sqrt((p[0]-wrist[0])**2 + (p[1]-wrist[1])**2) for p in points[1:]) + 1e-6
  normPoints = [((p[0]-wrist[0])/maxDist, (p[1]-wrist[1])/maxDist) for p in points]
  def calcAngle(p1, p2, p3):
    v1 = np.array([p1[0]-p2[0], p1[1]-p2[1]])
    v2 = np.array([p3[0]-p2[0], p3[1]-p2[1]])
    cos = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2) + 1e-6)
    return np.arccos(np.clip(cos, -1, 1)) / math.pi
  fingerJoints = [[0,1,2,3,4], [0,5,6,7,8], [0,9,10,11,12], [0,13,14,15,16], [0,17,18,19,20]]
  angles = []
  for finger in fingerJoints:
    for i in range(len(finger)-2):
      angles.append(calcAngle(normPoints[finger[i]], normPoints[finger[i+1]], normPoints[finger[i+2]]))
  for i, finger1 in enumerate(fingerJoints):
    for j, finger2 in enumerate(fingerJoints):
      if i < j:
        tip1, tip2 = normPoints[finger1[-1]], normPoints[finger2[-1]]
        angles.append(math.sqrt((tip1[0]-tip2[0])**2 + (tip1[1]-tip2[1])**2))
  return np.array(angles, dtype=np.float32)
def extractDistanceFeatures(landmarks):
  points = landmarks.reshape(21, 3)[:, :2]
  wrist = points[0]
  maxDist = np.max(np.linalg.norm(points[1:] - wrist, axis=1)) + 1e-6
  normPoints = (points - wrist) / maxDist
  keyPoints = [0, 4, 8, 12, 16, 20]
  distances = []
  for i in range(len(keyPoints)):
    for j in range(i+1, len(keyPoints)):
      p1, p2 = normPoints[keyPoints[i]], normPoints[keyPoints[j]]
      distances.append(np.linalg.norm(p1 - p2))
  fingerBases = [1, 5, 9, 13, 17]
  fingerTips = [4, 8, 12, 16, 20]
  for base, tip in zip(fingerBases, fingerTips):
    distances.append(np.linalg.norm(normPoints[tip] - normPoints[base]))
  for tip in fingerTips:
    distances.append(normPoints[tip][1])
  return np.array(distances, dtype=np.float32)
def extractCombinedFeatures(landmarks):
  raw = extractRawFeatures(landmarks)
  angles = extractAngleFeatures(landmarks)
  distances = extractDistanceFeatures(landmarks)
  return np.concatenate([raw, angles, distances])
class SignPredictor:
  def __init__(self, modelPath, scalerParamsPath, labelMapPath):
    try:
      self.interpreter = tf.lite.Interpreter(model_path=str(modelPath))
      self.interpreter.allocate_tensors()
      self.inputDetails = self.interpreter.get_input_details()
      self.outputDetails = self.interpreter.get_output_details()
    except Exception as e:
      print(f"Error Loading TFLite Model: {e}")
      raise
    self.scalerParams = np.load(scalerParamsPath, allow_pickle=True).item()
    self.labelMap = np.load(labelMapPath, allow_pickle=True).item()
    self.labelList = {v: k for k, v in self.labelMap.items()}
    handModelPath = Path(__file__).parent / "data" / "hand_landmarker.task"
    baseOptions = python.BaseOptions(model_asset_path=str(handModelPath))
    options = vision.HandLandmarkerOptions(
      base_options=baseOptions,
      num_hands=1,
      min_hand_detection_confidence=0.7,
      min_tracking_confidence=0.5
    )
    self.detector = vision.HandLandmarker.create_from_options(options)
    self.history = []
    self.historySize = 5
    self.confidenceHistory = []
  def extractLandmarks(self, frame):
    frameRgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mpImage = Image(image_format=ImageFormat.SRGB, data=frameRgb)
    results = self.detector.detect(mpImage)
    if results.hand_landmarks and len(results.hand_landmarks) > 0:
      handLandmarks = results.hand_landmarks[0]
      landmarks = []
      for lm in handLandmarks:
        landmarks.extend([lm.x, lm.y, lm.z])
      return np.array(landmarks, dtype=np.float32), results.hand_landmarks[0]
    return None, None
  def predict(self, landmarks):
    features = extractCombinedFeatures(landmarks).reshape(1, -1)
    featuresScaled = (features - self.scalerParams['mean']) / self.scalerParams['scale']
    featuresScaled = featuresScaled.astype(np.float32)
    self.interpreter.set_tensor(self.inputDetails[0]['index'], featuresScaled)
    self.interpreter.invoke()
    probas = self.interpreter.get_tensor(self.outputDetails[0]['index'])[0]
    predictedIdx = np.argmax(probas)
    confidence = float(probas[predictedIdx])
    self.history.append(predictedIdx)
    self.confidenceHistory.append(confidence)
    if len(self.history) > self.historySize:
      self.history.pop(0)
      self.confidenceHistory.pop(0)
    if len(self.history) >= 3:
      counter = Counter(self.history)
      mostCommon, count = counter.most_common(1)[0]
      if count >= 3:
        predictedIdx = mostCommon
        relevantConf = [c for i, c in zip(self.history, self.confidenceHistory) if i == mostCommon]
        confidence = np.mean(relevantConf)
    predictedLabel = self.labelList.get(predictedIdx, "Unknown")
    return predictedLabel, confidence
  def release(self):
    pass
def drawLandmarks(frame, landmarks):
  h, w, _ = frame.shape
  connections = [
    (0,1),(1,2),(2,3),(3,4),(0,5),(5,6),(6,7),(7,8),
    (0,9),(9,10),(10,11),(11,12),(0,13),(13,14),(14,15),(15,16),
    (0,17),(17,18),(18,19),(19,20),(5,9),(9,13),(13,17)
  ]
  points = []
  for lm in landmarks:
    x, y = int(lm.x * w), int(lm.y * h)
    points.append((x, y))
    cv2.circle(frame, (x, y), 5, (0, 255, 0), -1)
  for start, end in connections:
    cv2.line(frame, points[start], points[end], (0, 255, 0), 2)
def runDemo():
  modelPath = Path(__file__).parent / "savedModels" / "saslModel.tflite"
  scalerParamsPath = Path(__file__).parent / "savedModels" / "scalerParams.npy"
  labelMapPath = Path(__file__).parent / "savedModels" / "labelMap.npy"
  if not modelPath.exists():
    print("Model Not Found! Please Train First!")
    print("1. python data/extractLandmarks.py")
    print("2. python trainEnsemble.py")
    print("3. python trainTflite.py")
    return
  predictor = SignPredictor(modelPath, scalerParamsPath, labelMapPath)
  cap = cv2.VideoCapture(0)
  print("Press 'Q' To Quit!")
  while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
      break
    frame = cv2.flip(frame, 1)
    landmarks, handLandmarks = predictor.extractLandmarks(frame)
    if landmarks is not None:
      label, confidence = predictor.predict(landmarks)
      if confidence > 0.7:
        color = (0, 255, 0)
      elif confidence > 0.5:
        color = (0, 165, 255)
      else:
        color = (0, 0, 255)
      cv2.putText(frame, f"{label}: {confidence:.0%}", (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.5, color, 3)
      drawLandmarks(frame, handLandmarks)
    cv2.imshow("ASL Sign Recognition", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
      break
  cap.release()
  cv2.destroyAllWindows()
  predictor.release()
if __name__ == "__main__":
  runDemo()