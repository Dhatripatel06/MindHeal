# model_converter.py
import onnx
import sys
import os

def convert_model_ir_version(input_path, output_path, target_version):
    """
    Converts an ONNX model to a specific IR version.
    This version handles models with external data files (e.g., .onnx.data).
    It will save the new model as a single, self-contained file.
    """
    try:
        # Check if input file exists
        if not os.path.exists(input_path):
            print(f"Error: Input model file not found at: {input_path}")
            return

        # Get the directory of the input model
        input_dir = os.path.dirname(os.path.abspath(input_path))
        
        # --- KEY CHANGE ---
        # Load the model, telling ONNX to look for external data files
        print(f"Loading model from: {input_path} (checking for external data)")
        model = onnx.load(input_path, load_external_data=True)
        print("Model loaded successfully.")
        
        # Check current IR version
        current_version = model.ir_version
        print(f"Current model IR version: {current_version}")
        
        if current_version == target_version:
            print(f"Model is already at target IR version {target_version}.")
        else:
            # Convert (downgrade or upgrade) the model IR version
            print(f"Converting model to IR version: {target_version}...")
            model_converted = onnx.version_converter.convert_version(model, target_version)
            model = model_converted # Use the converted model for saving
            print(f"Model converted to IR version: {model.ir_version}")

        # --- KEY CHANGE ---
        # Save the converted model as a single file (not external data)
        # This makes it much easier to package in a Flutter app.
        print(f"Saving converted model as a single file to: {output_path}")
        
        # Use onnx.save_model to control external data saving
        onnx.save_model(
            model,
            output_path,
            save_as_external_data=False,
            all_tensors_to_one_file=True,
            location=f"{os.path.basename(output_path)}.data" # This is a dummy name, but good practice
        )
        
        print(f"✅ Successfully converted and saved model to: {output_path}")

    except Exception as e:
        print(f"❌ Error during model conversion: {e}")
        print("\n--- TROUBLESHOOTING ---")
        print(f"1. Make sure 'onnx' is installed (`pip install onnx`).")
        print(f"2. This error often means the model's data file is missing.")
        print(f"3. Check that BOTH '{os.path.basename(input_path)}' and '{os.path.basename(input_path)}.data'")
        print(f"   are present in the folder: {input_dir}")
        print("4. If the '.data' file is missing, you must re-download the model.")
        print("--------------------------")

# Main execution
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python model_converter.py <input_model_path> <output_model_path> <target_ir_version>")
        print("Example:")
        print("python model_converter.py assets/models/wav2vec2_superb_er.onnx assets/models/wav2vec2_superb_er_v9.onnx 9")
    else:
        input_model = sys.argv[1]
        output_model = sys.argv[2]
        try:
            version = int(sys.argv[3])
            convert_model_ir_version(input_model, output_model, version)
        except ValueError:
            print(f"Error: Target IR version must be an integer (e.g., 9). You provided: {sys.argv[3]}")