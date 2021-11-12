FROM node:current-alpine

# Installing rendertron and the dependency required for rendering. Installing latest versions
RUN npm install -g rendertron puppeteer@11.0.0

# Installing the rendering platform for rendertron; this is required for puppeteer to function
RUN apk add --no-cache chromium=93.0.4577.82-r0

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN addgroup -S rendertron && adduser -S -g rendertron rendertron

USER rendertron

EXPOSE 3000

CMD rendertron