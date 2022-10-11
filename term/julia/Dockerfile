FROM julia:1.8.0
WORKDIR /env
ADD ./Project.toml ./Manifest.toml /env/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'
COPY . . 
ENTRYPOINT ["julia", "--threads", "8", "--project=.", "bench.jl"]