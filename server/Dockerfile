# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:22-alpine AS production
ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist

# Environment-specific config (PROJECT_ID, FIREBASE_PROJECT_ID, etc.) is supplied
# at runtime via environment variables, not baked into the image. This keeps one
# image usable for both dev and prod deployments.
# COPY --from=build /app/.env.production ./.env.production

EXPOSE 3000
CMD ["node", "dist/main.js"]
