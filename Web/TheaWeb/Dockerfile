# TheaWeb Docker Configuration
# For containerized deployment (optional)

# Build stage
FROM swift:5.9-jammy as builder

WORKDIR /app

# Copy package files first for layer caching
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Copy source and build
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built executable
COPY --from=builder /app/.build/release/App ./

# Copy any static assets
COPY Public ./Public

# Create non-root user
RUN useradd -m appuser
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
