# Use the PyTorch image with CUDA and cuDNN support
FROM pytorch/pytorch:2.2.2-cuda11.8-cudnn8-runtime

# Set the working directory in the container
WORKDIR /app

RUN python -m pip install \
    pandas \
    openpyxl \
    heavylight==1.0.6

# Copy the rest of the application
COPY . /app/

# Environment variable (optional but might help with CUDA memory management)
ENV PYTORCH_CUDA_ALLOC_CONF="garbage_collection_threshold:0.8"

# Set the entrypoint and provide the script name as default command
ENTRYPOINT ["python", "main.py"]
