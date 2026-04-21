
FROM node:20-alpine

# Install nginx
RUN apk add --no-cache nginx

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy all app files
COPY . .

# Copy static html files to nginx root
RUN mkdir -p /usr/share/nginx/html && \
    cp -r html/. /usr/share/nginx/html/ && \
    mkdir -p /usr/share/nginx/html/suite

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script that runs both nginx and node
RUN printf '#!/bin/sh\nnginx\nexec node /app/server.js\n' > /start.sh && \
    chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
