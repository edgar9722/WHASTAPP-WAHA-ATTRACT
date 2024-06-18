#
# Build Stage
#
ARG NODE_VERSION=20.12.2-bullseye
FROM node:${NODE_VERSION} as build
ENV PUPPETEER_SKIP_DOWNLOAD=True

# Install dependencies
RUN apt-get update \
    && apt-get install -y openssh-client \
    && mkdir -p -m 0700 ~/.ssh \
    && ssh-keyscan github.com >> ~/.ssh/known_hosts

WORKDIR /src
COPY package.json yarn.lock tsconfig.json ./
RUN yarn set version 3.6.3
# Correct cache mount syntax
RUN --mount=type=cache,target=/root/.yarn/cache yarn install

# Copy application source code and build
COPY . .
RUN yarn build && find ./dist -name "*.d.ts" -delete

#
# Final Stage
#
FROM node:${NODE_VERSION} as release
ENV PUPPETEER_SKIP_DOWNLOAD=True
ENV NODE_OPTIONS="--max-old-space-size=16384"
ARG USE_BROWSER=chromium

# Install dependencies for specific browsers
RUN apt-get update \
    && apt-get install -y ffmpeg --no-install-recommends \
    && if [ "$USE_BROWSER" = "chromium" ]; then \
        apt-get install -y chromium --no-install-recommends; \
    elif [ "$USE_BROWSER" = "chrome" ]; then \
        wget --no-verbose -O /tmp/chrome.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
        && apt install -y /tmp/chrome.deb \
        && rm /tmp/chrome.deb; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# Set working directory and copy necessary files
WORKDIR /app
COPY --from=build /src/node_modules ./node_modules
COPY --from=build /src/dist ./dist
COPY package.json ./
COPY tsconfig.json ./

# Expose the application port and run the application
EXPOSE 3000
CMD ["yarn", "start:prod"]
