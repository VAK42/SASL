import kagglehub
import random
import math
import cv2
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe import Image, ImageFormat
from mediapipe.tasks import python
from pathlib import Path
def downloadDataset():
  datasetPath = kagglehub.dataset_download("grassknoted/asl-alphabet")
  return Path(datasetPath)
def downloadHandModel():
  modelPath = Path(__file__).parent / "hand_landmarker.task"
  if not modelPath.exists():
    import urllib.request
    url = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
    print("Downloading Hand Landmarker Model...")
    urllib.request.urlretrieve(url, modelPath)
  return str(modelPath)
def augmentLandmarks(landmarks, numAugmentations=5):
  augmented = [landmarks.copy()]
  for _ in range(numAugmentations):
    aug = landmarks.copy().reshape(21, 3)
    angle = random.uniform(-15, 15) * math.pi / 180
    cosA, sinA = math.cos(angle), math.sin(angle)
    for i in range(21):
      x, y = aug[i, 0], aug[i, 1]
      aug[i, 0] = x * cosA - y * sinA
      aug[i, 1] = x * sinA + y * cosA
    scale = random.uniform(0.85, 1.15)
    aug[:, :2] *= scale
    aug[:, 0] += random.uniform(-0.1, 0.1)
    aug[:, 1] += random.uniform(-0.1, 0.1)
    aug[:, 0] *= random.choice([1, -1]) if random.random() < 0.3 else 1
    noise = np.random.normal(0, 0.02, aug.shape)
    aug += noise
    augmented.append(aug.flatten())
  return augmented
def extractMultipleFeatureSets(landmarks):
  features = {}
  features['raw'] = extractRawFeatures(landmarks)
  features['angles'] = extractAngleFeatures(landmarks)
  features['distances'] = extractDistanceFeatures(landmarks)
  features['combined'] = np.concatenate([features['raw'], features['angles'], features['distances']])
  return features
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
def extractFromImage(imagePath, detector):
  image = cv2.imread(str(imagePath))
  if image is None:
    return None
  imageRgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
  mpImage = Image(image_format=ImageFormat.SRGB, data=imageRgb)
  results = detector.detect(mpImage)
  if results.hand_landmarks and len(results.hand_landmarks) > 0:
    handLandmarks = results.hand_landmarks[0]
    landmarks = []
    for lm in handLandmarks:
      landmarks.extend([lm.x, lm.y, lm.z])
    return np.array(landmarks, dtype=np.float32)
  return None
def processDataset(datasetPath, outputPath):
  trainPath = datasetPath / "asl_alphabet_train" / "asl_alphabet_train"
  if not trainPath.exists():
    trainPath = datasetPath / "asl_alphabet_train"
  modelPath = downloadHandModel()
  baseOptions = python.BaseOptions(model_asset_path=modelPath)
  options = vision.HandLandmarkerOptions(
    base_options=baseOptions,
    num_hands=1,
    min_hand_detection_confidence=0.5,
    min_tracking_confidence=0.5
  )
  detector = vision.HandLandmarker.create_from_options(options)
  allRaw = []
  allAngles = []
  allDistances = []
  allCombined = []
  allLabels = []
  labelMap = {}
  labelIdx = 0
  for letterFolder in sorted(trainPath.iterdir()):
    if not letterFolder.is_dir():
      continue
    letterName = letterFolder.name.upper()
    if letterName in ["DEL", "NOTHING", "SPACE"]:
      continue
    labelMap[letterName] = labelIdx
    print(f"Processing {letterName}...")
    imageFiles = list(letterFolder.glob("*.jpg")) + list(letterFolder.glob("*.png"))
    random.shuffle(imageFiles)
    startIdx, endIdx = (0, 500)
    for imgPath in imageFiles[startIdx:endIdx]:
      landmarks = extractFromImage(imgPath, detector)
      if landmarks is not None:
        augmentedList = augmentLandmarks(landmarks, numAugmentations=3)
        for augLandmarks in augmentedList:
          features = extractMultipleFeatureSets(augLandmarks)
          allRaw.append(features['raw'])
          allAngles.append(features['angles'])
          allDistances.append(features['distances'])
          allCombined.append(features['combined'])
          allLabels.append(labelIdx)
    labelIdx += 1
  outputPath = Path(outputPath)
  outputPath.mkdir(parents=True, exist_ok=True)
  np.save(outputPath / "rawFeatures.npy", np.array(allRaw))
  np.save(outputPath / "angleFeatures.npy", np.array(allAngles))
  np.save(outputPath / "distanceFeatures.npy", np.array(allDistances))
  np.save(outputPath / "combinedFeatures.npy", np.array(allCombined))
  np.save(outputPath / "labels.npy", np.array(allLabels))
  np.save(outputPath / "labelMap.npy", labelMap)
  print(f"Saved {len(allLabels)} Samples To {outputPath}")
  print(f"  Raw: {allRaw[0].shape[0]} features")
  print(f"  Angles: {allAngles[0].shape[0]} features")
  print(f"  Distances: {allDistances[0].shape[0]} features")
  print(f"  Combined: {allCombined[0].shape[0]} features")
if __name__ == "__main__":
  print("Downloading ASL Alphabet Dataset...")
  datasetPath = downloadDataset()
  print(f"Dataset Downloaded To: {datasetPath}")
  outputPath = Path(__file__).parent / "processed"
  processDataset(datasetPath, outputPath)