docker build --platform linux/amd64 -t actuarial/termlife-julia .

docker push actuarial/termlife-julia

gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=termlife-julia \
  --worker-pool-spec=machine-type=c2-standard-8,replica-count=1,container-image-uri=actuarial/termlife-julia