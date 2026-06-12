# LOCATION: ml_models/export_to_tflite.py
import os
import torch
import torch.nn as nn
import numpy as np

# Import the exact model architecture setup we used for training
from train_lstm import SignLanguageLSTM

PT_MODEL_PATH = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\ml_models\sign_language_lstm.pt"
ONNX_OUTPUT_PATH = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\ml_models\sign_language.onnx"

def export_pipeline():
    if not os.path.exists(PT_MODEL_PATH):
        print(f"❌ Target training weights checkpoint file not found at: {PT_MODEL_PATH}")
        return

    print("⏳ Loading PyTorch checkpoint metadata structures...")
    checkpoint = torch.load(PT_MODEL_PATH, map_location='cpu')
    classes = checkpoint['classes']
    config = checkpoint['model_config']
    
    # Reconstruct the network architecture state
    model = SignLanguageLSTM(
        input_size=config['input_size'],
        hidden_size=config['hidden_size'],
        num_layers=config['num_layers'],
        num_classes=len(classes)
    )
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()

    # Create dummy tensor matrix input to trace the internal network layout shape [Batch, TimeSteps, Features]
    dummy_input = torch.randn(1, 30, 51)

    print("⚡ Transpiling PyTorch execution layers into ONNX graph layout format...")
    torch.onnx.export(
        model,
        dummy_input,
        ONNX_OUTPUT_PATH,
        export_params=True,
        opset_version=14, 
        do_constant_folding=True,
        input_names=['input_sequence'],
        output_names=['action_output'],
        dynamic_axes={'input_sequence': {0: 'batch_size'}, 'action_output': {0: 'batch_size'}},
        dynamo=False # FIXED: Forces legacy tracing engine to bypass onnxscript requirements completely!
    )
    print(f"✓ ONNX structural graph compiled successfully:\n -> {ONNX_OUTPUT_PATH}")
    print("\n💡 To compile into .tflite, run this final terminal line command:\n")
    print(f"pip install onnx2tf tensorflow && onnx2tf -i \"{ONNX_OUTPUT_PATH}\"")

if __name__ == "__main__":
    export_pipeline()