# Rendertron demo walkthrough

## Dockerization

1. There is no binary for rendertron available from the git repository; however, according to the rendertron repository,
   a [local installation][rendertron-local] is possible via NPM.

2. I want a lightweight image, so I will start with an `node:current-alpine`.

3. Expected (but still unexpected) finding: rendertron requires a browser engine to actually render stuff. It's documentation
   advises to use [`puppeteer`][puppeteer] as an engine, so I will go this way. This also means that I will have to have
   Chromium installed, which will have a severe impact on the image size. I don't like this, but I will investigate if
   there is a way to trim down the size of the docker image later.

[rendertron-local]: https://github.com/GoogleChrome/rendertron#running-locally
[puppeteer]: https://github.com/puppeteer/puppeteer
