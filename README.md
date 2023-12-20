# crossplane-argocd
Example project showing how to use the crossplane together with ArgoCD

> This project is based on the crossplane only repository https://github.com/jonashackt/crossplane-aws-azure, where the basics about crossplane.io are explained in detail - incl. how to provision to AWS and Azure.

__The idea is "simple": Why not treat infrastructure deployments/provisioning the same way as appliaction deployment?!__ An ideal combination would be crossplane as control plane framework, which manages infrastructure through the Kubernetes api together with ArgoCD as [GitOps](https://www.gitops.tech/) framework to have everything in sync with our version control system.


### Prerequisites: a management cluster for ArgoCD and crossplane

First we need a simple management cluster for our ArgoCD and crossplane deployments. [As in the base project](https://github.com/jonashackt/crossplane-aws-azure) we simply use kind here:

Be sure to have kind, the package manager Helm and kubectl installed:

```shell
brew install kind helm kubectl kustomize
```

https://docs.crossplane.io/latest/cli/

Also we should install the crossplane CLI

```shell
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin
```

Now the `kubectl crossplane --help` command should be ready to use.


Now spin up a local kind cluster

```shell
kind create cluster --image kindest/node:v1.29.0 --wait 5m
```


### Configure annotation based resource tracking in ArgoCD

https://docs.crossplane.io/knowledge-base/integrations/argo-cd-crossplane/

> "There are different ways to configure how Argo CD tracks resources. With Crossplane, you need to configure Argo CD to use Annotation based resource tracking."

You may already used ArgoCD with resource tracking via the well-known label `app.kubernetes.io/instance`, which is the default resource tracking mode in Argo. But from ArgoCD 2.2 on [there are additional ways of tracking resources](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_tracking/#additional-tracking-methods-via-an-annotation). One of them is the annotation based resource tracking. This has some advantages:

> "The advantages of using the tracking id annotation is that there are no clashes any more with other Kubernetes tools and Argo CD is never confused about the owner of a resource. The annotation+label can also be used if you want other tools to understand resources managed by Argo CD."

The resource tracking method has to be configured inside the `argocd-cm` ConfigMap using the `application.resourceTrackingMethod` field:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  application.resourceTrackingMethod: annotation
```

But how do we install ArgoCD and change the ConfigMap in a flexible, GitOps-style and renovatebot-enabled way?



### Install ArgoCD into kind

There's a great repo https://github.com/jonashackt/tekton-argocd-eks where also a great way on how to configure and install ArgoCD is described https://stackoverflow.com/a/71692892/4964553 (and [also in the Argo docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#manage-argo-cd-using-argo-cd)).

First we create a directory `argocd/install` and a file [`kustomization.yaml`](argocd/install/kustomization.yaml):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- github.com/argoproj/argo-cd//manifests/cluster-install?ref=v2.9.3

## changes to config maps
patches:
- path: argocd-cm-patch.yml

namespace: argocd
```

We also need to create a file [`argocd-cm-patch.yml`](argocd/install/argocd-cm-patch.yml), where we can implement our needed annotation based resource tracking mode in the Argo ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  server.insecure: "true"
  application.resourceTrackingMethod: annotation
```

Creating the Argo namespace and installing it via `kubectl apply -k` is all we need to do:

```shell
kubectl create namespace argocd
kubectl apply -k argocd/install
```


### Accessing ArgoCD GUI

First we need to obtain the initial password for the `admin` user via:

```shell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Now we have multiple options here - where the simplest might be a `port-forward`:

```shell
kubectl port-forward -n argocd --address='0.0.0.0' service/argocd-server 8080:80
```

Now access the ArgoCD UI inside your Browser at http://localhost:8080 using `admin` user and the obtained password.








# Links

https://docs.crossplane.io/knowledge-base/integrations/argo-cd-crossplane/

https://blog.upbound.io/argo-crossplane-managing-application-stack

https://docs.upbound.io/concepts/mcp/control-plane-connector/

https://blog.upbound.io/2023-09-26-product-updates

https://morningspace.medium.com/using-crossplane-in-gitops-what-to-check-in-git-76c08a5ff0c4

Infrastructure-as-Apps https://codefresh.io/blog/infrastructure-as-apps-the-gitops-future-of-infra-as-code/

https://docs.upbound.io/spaces/git-integration/

https://codefresh.io/blog/using-gitops-infrastructure-applications-crossplane-argo-cd/

Configuration drift in Tf: Terraform horror stories about incomplete/invalid state https://www.youtube.com/watch?v=ix0Tw8uinWs