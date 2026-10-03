FROM ghcr.io/cirruslabs/flutter:latest AS build
ARG API_BASE_URL=http://localhost:8000/api
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

