# Use the PyTorch image with CUDA and cuDNN support
FROM pytorch/pytorch:2.2.2-cuda11.8-cudnn8-runtime

# Set the working directory in the container
WORKDIR /app

# Copy only the requirements.txt first to leverage Docker cache
COPY requirements.txt /app/

# Install dependencies using Conda to ensure compatibility with the base environment
RUN conda install --name base --yes --file requirements.txt

# Copy the rest of the application
COPY . /app/

ENV PYTORCH_CUDA_ALLOC_CONF="garbage_collection_threshold:0.8"

# Command to run on container start
CMD ["python", "main.py"]
