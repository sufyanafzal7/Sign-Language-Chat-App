import subprocess
import os
import sys
import shutil

ONNX_PATH = r"D:\Projects\Sign-Language-Chat-App\mobile_app\assets\model\letter_classifier.onnx"
OUTPUT_DIR = r"D:\Projects\Sign-Language-Chat-App\mobile_app\assets\model\letter_tf_model"
TFLITE_DEST = r"D:\Projects\Sign-Language-Chat-App\mobile_app\assets\model\letter_classifier.tflite"

print("Converting letter_classifier.onnx → TFLite using onnx2tf...")

result = subprocess.run([
    sys.executable, "-m", "onnx2tf",
    "-i", ONNX_PATH,
    "-o", OUTPUT_DIR,
], capture_output=True, text=True)

print("STDOUT:", result.stdout[-3000:] if result.stdout else "(none)")
print("STDERR:", result.stderr[-1000:] if result.stderr else "(none)")

# Find any .tflite file generated
tflite_candidates = []
for root, dirs, files in os.walk(OUTPUT_DIR):
    for f in files:
        if f.endswith('.tflite'):
            tflite_candidates.append(os.path.join(root, f))

print(f"\nFound .tflite files: {tflite_candidates}")

if tflite_candidates:
    chosen = next((f for f in tflite_candidates if 'float32' in f), tflite_candidates[0])
    shutil.copy(chosen, TFLITE_DEST)
    print(f"\nSuccess! Copied:\n  {chosen}\n  → {TFLITE_DEST}")
else:
    print("\nNo .tflite file found. Trying direct Python API conversion instead...")
    try:
        import onnx
        from onnx2tf import convert
        convert(
            input_onnx_file_path=ONNX_PATH,
            output_folder_path=OUTPUT_DIR,
            non_verbose=True,
        )
        # Search again
        for root, dirs, files in os.walk(OUTPUT_DIR):
            for f in files:
                if f.endswith('.tflite'):
                    tflite_candidates.append(os.path.join(root, f))
        if tflite_candidates:
            chosen = tflite_candidates[0]
            shutil.copy(chosen, TFLITE_DEST)
            print(f"Success via Python API: {TFLITE_DEST}")
        else:
            print("Still no .tflite found. Check output above.")
    except Exception as e:
        print(f"Python API also failed: {e}")