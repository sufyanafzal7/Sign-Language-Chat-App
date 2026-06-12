# LOCATION: ml_models/train_lstm.py
import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np

# System Engine Hardware Configurations
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
FEATURES_DIR = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\ml_models\processed_features"
MODEL_SAVE_PATH = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\ml_models\sign_language_lstm.pt"

# Parameter Configuration Matrix
SEQUENCE_LENGTH = 30  # Number of tracking frames per clip
INPUT_SIZE = 51       # 17 body keypoints * 3 parameters (x, y, confidence)
HIDDEN_SIZE = 128     # LSTM structural memory capacity channels
NUM_LAYERS = 2        # Stack depth of LSTM layers
BATCH_SIZE = 4        # Batch processing scale for limited memory footprints
EPOCHS = 40           # Training cycles
LEARNING_RATE = 0.001

# 1. Custom Structural Dataset Constructor Wrapper
class SignLanguageDataset(Dataset):
    def __init__(self, features_dir):
        self.data = []
        self.labels = []
        
        # Scrape and index vocabulary sub-folders dynamically
        self.classes = sorted([d for d in os.listdir(features_dir) if os.path.isdir(os.path.join(features_dir, d))])
        self.class_to_idx = {cls_name: i for i, cls_name in enumerate(self.classes)}
        
        print(f"📦 Mapping {len(self.classes)} uniquely verified sign classes to labels...")
        
        for cls_name in self.classes:
            class_folder = os.path.join(features_dir, cls_name)
            for file_name in os.listdir(class_folder):
                if file_name.endswith('.npy'):
                    matrix_path = os.path.join(class_folder, file_name)
                    # Load array configuration securely
                    matrix = np.load(matrix_path)
                    
                    self.data.append(matrix)
                    self.labels.append(self.class_to_idx[cls_name])
                    
        self.data = np.array(self.data, dtype=np.float32)
        self.labels = np.array(self.labels, dtype=np.int64)
        print(f"✓ Total data sequence rows loaded for training array tensor: {len(self.data)}")

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        return torch.tensor(self.data[idx]), torch.tensor(self.labels[idx])

# 2. PyTorch LSTM Deep Sequence Classifier Core Definition
class SignLanguageLSTM(nn.Module):
    def __init__(self, input_size, hidden_size, num_layers, num_classes):
        super(SignLanguageLSTM, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        
        # Long Short-Term Memory Network Base Block
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True, dropout=0.2 if num_layers > 1 else 0.0)
        
        # Fully Connected Output Mapping Dense Layer
        self.fc = nn.Linear(hidden_size, num_classes)

    def forward(self, x):
        # Initialize baseline zero memory structures for time steps evaluation
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(DEVICE)
        c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(DEVICE)
        
        # Run forward temporal propagation loop
        out, _ = self.lstm(x, (h0, c0))
        
        # Decode the feature states from the final sequence frame block
        out = self.fc(out[:, -1, :])
        return out

def train_network_model():
    # Load dataset features matrix pipelines
    dataset = SignLanguageDataset(FEATURES_DIR)
    if len(dataset) == 0:
        print("❌ Error: Processed features dataset is empty. Cannot start training.")
        return
        
    num_classes = len(dataset.classes)
    
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    # Initialize the PyTorch model block structures
    model = SignLanguageLSTM(INPUT_SIZE, HIDDEN_SIZE, NUM_LAYERS, num_classes).to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    print(f"\n🚀 Commencing model training sequence optimization loops on hardware: {str(DEVICE).upper()}...")
    model.train()
    
    for epoch in range(EPOCHS):
        running_loss = 0.0
        correct_predictions = 0
        total_samples = 0
        
        for idx, (sequences, labels) in enumerate(loader):
            sequences = sequences.to(DEVICE)
            labels = labels.to(DEVICE)
            
            # Forward prediction calculation loop pass
            outputs = model(sequences)
            loss = criterion(outputs, labels)
            
            # Optimization backwards backpropagation gradient updates pass
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item() * sequences.size(0)
            _, predicted = torch.max(outputs, 1)
            total_samples += labels.size(0)
            correct_predictions += (predicted == labels).sum().item()
            
        epoch_loss = running_loss / total_samples
        epoch_acc = (correct_predictions / total_samples) * 100
        
        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"  Epoch [{epoch+1}/{EPOCHS}] -> Loss Density: {epoch_loss:.4f} | Accuracy Matrix Score: {epoch_acc:.2f}%")

    # Save structural model architecture checkpoint metadata states to disk
    torch.save({
        'model_state_dict': model.state_dict(),
        'classes': dataset.classes,
        'model_config': {'input_size': INPUT_SIZE, 'hidden_size': HIDDEN_SIZE, 'num_layers': NUM_LAYERS}
    }, MODEL_SAVE_PATH)
    
    print(f"\n🎉 Model checkpoint written successfully to database route folder:\n -> {MODEL_SAVE_PATH}")

if __name__ == "__main__":
    train_network_model()