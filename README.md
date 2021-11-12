# Rendertron demo walkthrough

## Dockerization

1. There is no binary for rendertron available from the git repository; however, according to the rendertron repository,
   a [local installation][rendertron-local] is possible via NPM.

2. I want a lightweight image, so I will start with an `node:current-alpine`.

3. Expected (but still unexpected) finding: rendertron requires a browser engine to actually render stuff. It's documentation
   advises to use [`puppeteer`][puppeteer] as an engine, so I will go this way. This also means that I will have to have
   Chromium installed, which will have a severe impact on the image size. I don't like this, but I will investigate if
   there is a way to trim down the size of the docker image later.

4. We are pretty stateless, and `rendertron` binds to port 3000, so I am fairly safe in switching a user to a newly created
   one.

5. There seems to be a strict mapping between Chromium version and `puppeteer` version. I will pin these in the `Dockerfile`.

6. I build and check the rendertron docker image:

```bash
➜ docker build --tag rendertron .                       
➜ docker run -p 3000:3000 rendertron:latest                  
Listening on port 3000
  <-- GET /render/https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
  --> GET /render/https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/ 200 1,485ms 32.41kb
```

## Kubernetes cluster setup

I will create a small kubernetes cluster based on minikube, as my machine already has minikube installed.

```bash
minikube start
```

And we are in business. I will drop in the ingress-nginx right away though, as it's not on by default. Fortunately, `minikube`
will handle that for me.

```bash
minikube addons enable ingress
```

## Kubernetes objects

1. Let's start with the deployment. As this is a small and simple task, I will not bother creating a separate namespace
   for the deployment, and will target the `default` namespace instead. Saves me some keystrokes in the end, and the switch
   is trivial. That deployment is available in [here](./.kube/rendertron-deployment.yaml).

2. I will start with a basic deployment. First off, I will have to push the image to the registry; I'll build y image inside
   the minikube cluster. Switch where my docker CLI points:

   ```bash
   eval $(minikube docker-env)
   ```

   Then just run the build. And restore my env:

   ```bash
   eval $(minikube docker-env -u)
   ```

3. I add the service and an ingress (based on the one that was enabled earlier). The ingress has a whitelist annotation
   that allows my docker network to be able to connect to it. I define a very simple routeless ingress, as I only have one
   service running in the background.

   I check the ingress:

   ```bash
   ➜ kubectl get ingress
   NAME                 CLASS    HOSTS   ADDRESS        PORTS   AGE
   rendertron-ingress   <none>   *       192.168.49.2   80      10m
   ```

   And get a peek at the render:

   ```bash
   [22:31:34] ☸ minikube(default) ../rendertron-test on  main 
   ➜ curl http://192.168.49.2/render/https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ | head
   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                   Dload  Upload   Total   Spent    Left  Speed
   1  347k    1  3882    0     0   3234      0  0:01:50  0:00:01  0:01:49  3235<!DOCTYPE html><html lang="en" class="no-js"><head><base href="https://kubernetes.io/docs/concepts/workloads/controllers">
   ...
   ```

[rendertron-local]: https://github.com/GoogleChrome/rendertron#running-locally
[puppeteer]: https://github.com/puppeteer/puppeteer
