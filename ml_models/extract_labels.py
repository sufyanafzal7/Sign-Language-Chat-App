import torch
import os

PT_MODEL_PATH = r"D:\Projects\Sign-Language-Chat-App\ml_models\sign_language_lstm.pt"
OUTPUT_PATH = r"D:\Projects\Sign-Language-Chat-App\mobile_app\assets\model\labels.txt"

checkpoint = torch.load(PT_MODEL_PATH, map_location='cpu')
classes = checkpoint['classes']

with open(OUTPUT_PATH, 'w') as f:
    f.write('\n'.join(classes))

print(f"Saved {len(classes)} labels to: {OUTPUT_PATH}")
print(f"Labels: {classes}")