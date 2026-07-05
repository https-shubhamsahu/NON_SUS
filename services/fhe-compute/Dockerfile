# Stage 1: Build dependencies & cache Rust cargo index
FROM rust:1.75-slim-bookworm AS planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Stage 2: Cache compiler layers
FROM rust:1.75-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y clang pkg-config libssl-dev
RUN cargo install cargo-chef
COPY --from-planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

# Stage 3: Build application
COPY . .
# Compile with CPU optimizations (required for high-performance TFHE operations)
ENV RUSTFLAGS="-C target-cpu=native"
RUN cargo build --release --bin fhe-compute

# Stage 4: Hardened Run-time Minimal Image
FROM debian:bookworm-slim
WORKDIR /app

# Install runtime dependencies and clean package cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends libssl3 ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Create secure system user and group (UID/GID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -r -u 10001 -g appgroup -d /app -s /sbin/nologin appuser

# Copy binary with explicit ownership
COPY --from=builder --chown=appuser:appgroup /app/target/release/fhe-compute /app/fhe-compute

# Restrict permissions to read-only for application code
RUN chmod 0555 /app/fhe-compute && \
    chown -R root:root /app && \
    chown appuser:appgroup /app

# Switch to non-privileged user context
USER appuser

# Expose port
EXPOSE 8080

# Production Health Check
HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/fhe-compute"]

