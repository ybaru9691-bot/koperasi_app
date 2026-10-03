FROM ghcr.io/cirruslabs/flutter:latest AS build
WORKDIR /app

# Build args untuk API endpoint
ARG API_BASE_URL=http://localhost:8000/api

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .

# Build Flutter web dengan API_BASE_URL yang bisa dikonfigurasi
RUN flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

