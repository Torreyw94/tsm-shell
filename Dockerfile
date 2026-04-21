FROM node:20-alpine

# Install nginx
RUN apk add --no-cache nginx bash

WORKDIR /app

# Install dependencies first (layer caching)
COPY package*.json ./
RUN npm install --production

# Copy app source
COPY server.js ./
COPY html ./html

# Set up nginx static root
RUN mkdir -p /usr/share/nginx/html/suite && \
    cp -r html/. /usr/share/nginx/html/

# nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Startup script — nginx in background, node in foreground
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo 'nginx' >> /start.sh && \
    echo 'echo "nginx started"' >> /start.sh && \
    echo 'exec node /app/server.js' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 8080

CMD ["/bin/bash", "/start.sh"]
