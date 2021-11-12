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

[rendertron-local]: https://github.com/GoogleChrome/rendertron#running-locally
[puppeteer]: https://github.com/puppeteer/puppeteer
