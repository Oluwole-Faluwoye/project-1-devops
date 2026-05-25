FROM node:20-bookworm-slim

WORKDIR /app

# Copy only dependency files first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy rest of the app
COPY . .

EXPOSE 3000

CMD ["node", "index.js"]