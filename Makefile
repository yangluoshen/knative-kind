
KIND_CLUSTER_KNATIVE=knative
LOCAL_REGISTRY=localhost:5000

knative-serving: kind-create serving-create kourier-create
uninstall-serving: uninstall-kourier uninstall-serving

kind-create:
	@./01-kind.sh
serving-create:
	@./02-serving.sh
uninstall-serving:
	kubectl delete -f serving-core.yaml
	kubectl delete -f serving-crds.yaml
kourier-create:
	@./02-kourier.sh
uninstall-kourier:
	kubectl delete -f kourier.yaml

IMG_SERVING= \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/activator:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/queue:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/webhook:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/controller:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/autoscaler:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/default-domain:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/domain-mapping-webhook:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/serving/cmd/domain-mapping:v1.7.1" \
	 "gcr.io/knative-releases/knative.dev/net-kourier/cmd/kourier:v1.7.0" \
	 "envoyproxy/envoy:v1.20-latest"
docker-pull-image-serving:
	# [docker-pull-image-serving] docker pulling...
	@for img in $(IMG_SERVING); do \
		docker pull $$img; \
	done
	# [docker-pull-image-serving] docker finished.
docker-tag-push-local-registry: docker-pull-image-serving
	# [docker-tag-push-local-registry] tagging...
	@for img in $(IMG_SERVING); do \
		docker tag $$img $(LOCAL_REGISTRY)/$$(echo $$img | awk -F/ '{print $$NF}'); \
		docker push $(LOCAL_REGISTRY)/$$(echo $$img | awk -F/ '{print $$NF}'); \
	done
	# [docker-tag-push-local-registry] finished.
kind-load-image-serving: docker-pull-image-serving
	# [kind-load-image-serving] kind image loading...
	@for img in $(IMG_SERVING); do \
		kind load docker-image $$img --name $(KIND_CLUSTER_KNATIVE); \
	done
	# [kind-load-image-serving] finished.

# utils
kourier-external-ip:
	@kubectl --namespace kourier-system get service kourier
.PHONY: kind-create
