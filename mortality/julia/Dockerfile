FROM julia:1.8.0
WORKDIR /env
COPY . . 
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'
ENTRYPOINT ["julia", "--project=.", "term.jl"]