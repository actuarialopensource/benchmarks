docker build --platform linux/amd64 -t actuarial/mortality-julia .

docker push actuarial/mortality-julia

gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=mortality-julia \
  --worker-pool-spec=machine-type=c2-standard-8,replica-count=1,container-image-uri=actuarial/mortality-julia