I use `run.sh` to publish the container to docker hub and then run it from Google Cloud's Vertex AI platform. If you want to reproduce the results, you should be able to run the following from your terminal.

```
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=mortality-julia \
  --worker-pool-spec=machine-type=c2-standard-8,replica-count=1,container-image-uri=actuarial/mortality-julia
```
