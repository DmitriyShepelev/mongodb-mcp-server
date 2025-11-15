# Build stage
FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./

# Copy source code (needed before npm ci because of prepare script)
COPY src ./src
COPY scripts ./scripts
COPY eslint.config.js ./
COPY .prettierrc.json ./

# Install dependencies (this runs npm run build via prepare script)
RUN npm ci

# Production stage
FROM node:24-alpine

ARG VERSION=latest

# Create non-root user
RUN addgroup -S mcp && adduser -S mcp -G mcp

WORKDIR /home/mcp

# Copy built application from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Install production dependencies only (skip scripts to avoid running prepare/build)
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Set ownership
RUN chown -R mcp:mcp /home/mcp

USER mcp

# Environment variables
ENV MDB_MCP_LOGGERS=stderr,mcp
ENV NODE_ENV=production

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run the application
ENTRYPOINT ["node", "dist/esm/index.js"]

LABEL maintainer="MongoDB Inc <info@mongodb.com>"
LABEL description="MongoDB MCP Server"
LABEL version=${VERSION}
LABEL io.modelcontextprotocol.server.name="io.github.mongodb-js/mongodb-mcp-server"
