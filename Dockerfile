FROM node:current-alpine

RUN npm install -g rendertron puppeteer

RUN apk add --no-cache chromium

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN addgroup -S rendertron && adduser -S -g rendertron rendertron

EXPOSE 3000

USER rendertron

CMD rendertron