import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import uvicorn
from typing import Dict, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Model configurations
MODEL_VARIANTS = {
    "1.5B" : "AI-MO/Kimina-Prover-Preview-Distill-1.5B",
    "7B"   : "AI-MO/Kimina-Prover-Preview-Distill-7B"
}
DEFAULT_PORT = 8000

# Global variables for model and tokenizer
model = None
tokenizer = None
model_name = None

# Load model and tokenizer
def load_model(model_size):
    global model, tokenizer, model_name
    
    if model_size not in MODEL_VARIANTS:
        raise ValueError(f"Invalid model size: {model_size}. Available sizes: {list(MODEL_VARIANTS.keys())}")
    
    model_name = MODEL_VARIANTS[model_size]
    logger.info(f"Loading model: {model_name}")
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=False)
    logger.info(f"Tokenizer loaded: {tokenizer.__class__.__name__}")
    
    # Load the model
    model = AutoModelForCausalLM.from_pretrained(model_name, torch_dtype=torch.float16)
    logger.info(f"Model loaded: {model.__class__.__name__}")
    
    # Set the model to evaluation mode
    model.eval()
    
    # Move model to GPU if available
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info(f"Using device: {device}")
    model.to(device)

# Initialize FastAPI app with lifespan
app = FastAPI(
    title="Kimina Prover Preview Server", 
    description="API for serving Kimina Prover Preview language model",
)

# Pydantic model for request validation
class GenerateRequest(BaseModel):
    prompt: str
    parameters: Optional[Dict[str, Any]] = {
        "max_new_tokens": 8096,
        "do_sample": True,
        "temperature": 0.6,
        "top_p": 0.95
    }

# API endpoints
@app.get("/")
def model_info():
    """Get model information"""
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    return {
        "model_name": model_name,
        "model_type": model.__class__.__name__,
        "tokenizer_type": tokenizer.__class__.__name__,
        "device": str(model.device),
        "vocab_size": len(tokenizer)
    }

@app.post("/generate")
def generate(request: GenerateRequest):
    """Generate text from the model"""
    if model is None or tokenizer is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    try:
        # Use the prompt as-is without any additional formatting
        prompt = request.prompt
        
        # Get parameters or use defaults
        params = request.parameters
        
        logger.info(f"Processing request with {len(prompt)} characters")
        
        # Tokenize the input
        inputs = tokenizer(prompt, return_tensors="pt")
        
        # Get device
        device = next(model.parameters()).device
        
        # Add device-specific parameters
        generate_params = {
            "input_ids": inputs["input_ids"].to(device),
            "attention_mask": inputs["attention_mask"].to(device) if "attention_mask" in inputs else None
        }
        
        # Add all parameters from the params dictionary
        generate_params.update(params)
        
        # Generate output using all parameters
        with torch.no_grad():
            outputs = model.generate(**generate_params)
        
        # Decode the generated text
        generated_text = tokenizer.decode(outputs[0], skip_special_tokens=False)
        
        logger.info(f"Generated {len(generated_text)} characters")
        
        return {
            "generated_text": generated_text,
            # "input_tokens": len(inputs["input_ids"][0]),
            # "output_tokens": len(outputs[0])
        }
        
    except Exception as e:
        logger.error(f"Error in generate: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# Run the server if this file is executed directly
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Start the LLM server")
    parser.add_argument("--model", type=str, default="1.5B", choices=["1.5B", "7B"], 
                        help="Model size to use (1.5B or 7B)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to run the server on")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to run the server on")
    
    args = parser.parse_args()
    
    # Load the model before starting the server
    try:
        load_model(args.model)
        logger.info(f"Starting server on {args.host}:{args.port} with model size {args.model}")
        uvicorn.run(app, host=args.host, port=args.port)
    except Exception as e:
        logger.error(f"Failed to start server: {str(e)}", exc_info=True)