# model_converter.py
# import tensorflow as tf
# import os

# def convert_to_tflite(model_path, output_path):
#     try:
#         print(f"Loading model from: {model_path}")
        
#         # Check if model file exists
#         if not os.path.exists(model_path):
#             print(f"Error: Model file {model_path} not found!")
#             return False
        
#         # Load your trained model
#         model = tf.keras.models.load_model(model_path)
#         print("Model loaded successfully")
        
#         # Convert to TensorFlow Lite
#         converter = tf.lite.TFLiteConverter.from_keras_model(model)
#         converter.optimizations = [tf.lite.Optimize.DEFAULT]
#         tflite_model = converter.convert()
#         print("Model converted to TensorFlow Lite")
        
#         # Ensure output directory exists
#         os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
#         # Save the model
#         with open(output_path, 'wb') as f:
#             f.write(tflite_model)
        
#         print(f"Model saved to: {output_path}")
#         return True
        
#     except Exception as e:
#         print(f"Error converting {model_path}: {e}")
#         return False

# # Main execution
# if __name__ == "__main__":
#     print("Starting model conversion...")
    
#     # Convert models
#     success1 = convert_to_tflite('emotion_detection_model.h5', 'assets/models/emotion_model.tflite')
#     success2 = convert_to_tflite('stress_prediction_model.h5', 'assets/models/stress_model.tflite')
    
#     if success1 and success2:
#         print("✅ All models converted successfully!")
#     else:
#         print("❌ Some models failed to convert. Check the error messages above.")
