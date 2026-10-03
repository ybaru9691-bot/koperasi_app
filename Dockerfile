# Stage 1: Build Flutter Web
FROM cirrusci/flutter:latest AS builder

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy all source code
COPY . .

# Build web release
RUN flutter build web --release

# Stage 2: Serve static files
FROM python:3.11-slim

WORKDIR /app

# Copy built web files from builder stage
COPY --from=builder /app/build/web ./build/web

# Expose port 3000
EXPOSE 3000

# Serve the web app using Python's built-in HTTP server
CMD ["python3", "-m", "http.server", "3000", "--directory", "./build/web"]
