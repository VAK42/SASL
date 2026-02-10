import numpy as np
import json
from pathlib import Path
outputPath = Path(__file__).parent / "savedModels"
scalerParams = np.load(outputPath / "scalerParams.npy", allow_pickle=True).item()
labelMap = np.load(outputPath / "labelMap.npy", allow_pickle=True).item()
scalerJson = {
  'mean': scalerParams['mean'].tolist(),
  'scale': scalerParams['scale'].tolist()
}
labelMapJson = {str(v): k for k, v in labelMap.items()}
with open(outputPath / "scalerParams.json", "w") as f:
  json.dump(scalerJson, f)
with open(outputPath / "labelMap.json", "w") as f:
  json.dump(labelMapJson, f)
print("Converted NPY Files To JSON")
print(f"Scaler Mean Shape: {len(scalerJson['mean'])}")
print(f"Scaler Scale Shape: {len(scalerJson['scale'])}")
print(f"Label Map: {labelMapJson}")