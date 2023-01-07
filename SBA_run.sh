export $(grep -v '^#' .env | xargs)

docker run -d --restart always --name github-runner \
  -e RUNNER_NAME_PREFIX=$RUNNER_NAME_PREFIX \
  -e ACCESS_TOKEN=$ACCESS_TOKEN \
  -e RUNNER_WORKDIR=$RUNNER_WORKDIR \
  -e RUNNER_GROUP=$RUNNER_GROUP \
  -e RUNNER_SCOPE=$RUNNER_SCOPE \
  -e DISABLE_AUTO_UPDATE=$DISABLE_AUTO_UPDATE \
  -e ORG_NAME=$ORG_NAME \
  -e LABELS=$LABELS \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/sansterbioanalytics/docker-github-actions-runner:/tmp/sansterbioanalytics/docker-github-actions-runner \
  myoung34/github-runner:ubuntu-jammy