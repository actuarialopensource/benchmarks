FROM python:3.8

# Copy the code
WORKDIR /app
COPY . .

# Install dependencies
RUN pip3 install -r requirements.txt

ENTRYPOINT [ "python3", "bench.py" ]


