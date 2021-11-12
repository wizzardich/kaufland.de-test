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

## Analysis and autoscaling

1. I use [`ali`][ali-github] to benchmark the performance of the rendertron. Initially I started it with the rate of 100
   requests per minute, but that start choking on the default resouce allocation almost right away.

    ```bash
    ali --duration 2m --rate 100 "http://192.168.49.2/render/https://kubernetes.io/docs/concepts/workloads/controllers/deployment/"
    ```

    I decided to test it on a low-frequency render; 1 req/sec it can keep up with. In this case with the allocation of
    1 CPU unit it is capable to preserve around 1.6 sec latency, while not overusing the RAM.

    ```bash
    ali --duration 2m --rate 1 "http://192.168.49.2/render/https://kubernetes.io/docs/concepts/workloads/controllers/deployment/"
    ```

    I started a slightly more difficult benchmark with 2 requests per minute.

    ```bash
    ali --duration 2m --rate 2 "http://192.168.49.2/render/https://kubernetes.io/docs/concepts/workloads/controllers/deployment/"
    ```

    I'm treated to a glorious picture of rendertron choking. First CPU hits the roof, and RAM shortly follows. I guess
    that RAM is actually being filled in with a queue of requests of some kind. This means that picking CPU as our primary
    scaling metrics. If we are fine on CPU usage, we will not need more RAM. (I still put in the RAM limits, just in case)

2. Let's add autoscaling!

   ```bash
   ➜ kubectl autoscale deployment rendertron-deployment --cpu-percent=70 --min=1 --max=10
   horizontalpodautoscaler.autoscaling/rendertron-deployment autoscaled
   ➜ kubectl get hpa
   NAME                    REFERENCE                          TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
   rendertron-deployment   Deployment/rendertron-deployment   0%/70%    1         10        1          51s
   ```

   With this rendertron is capable of surviving this no problem:

   ```bash
   ali --duration 2m --rate 4 "http://192.168.49.2/render/https://kubernetes.io/docs/concepts/workloads/controllers/deployment/"

   ➜ kubectl get hpa                                    
   NAME                    REFERENCE                          TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
   rendertron-deployment   Deployment/rendertron-deployment   270%/70%   1         10        10         8m11s
   ```

   Though it starts choking on 7 requests per second, with the current allowance of CPU usage and pod maximum, anyway.

   It would be much nicer to be able to scale on latency, and for HPA to generally be application-aware, I think.

[rendertron-local]: https://github.com/GoogleChrome/rendertron#running-locally
[puppeteer]: https://github.com/puppeteer/puppeteer
[ali-github]: https://github.com/nakabonne/ali
