# Dockerfile for Mojo Poker
# Optimized for Fly.io deployment with WebSocket support

FROM perl:5.38-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libssl-dev \
    libz-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy dependency file first (for better caching)
COPY cpanfile .

# Install Perl dependencies
RUN cpanm --installdeps --notest .

# Copy application code
COPY . .

# Create directory for SQLite database (if used)
RUN mkdir -p /app/db

# Expose port (Fly.io will set PORT env var)
EXPOSE 8080

# Health check - uses /health endpoint for observability
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD perl -e 'use LWP::Simple; my $r = get("http://localhost:8080/health"); exit($r ? 0 : 1)'

# Run the application
# Fly.io sets PORT env var, but we default to 8080
CMD ["perl", "script/mojopoker", "daemon", "-l", "http://*:8080"]
