FROM nginx:alpine

# Hapus file default nginx
RUN rm -rf /usr/share/nginx/html/*

# Salin hasil build Flutter Web ke direktori web root Nginx
COPY build/web /usr/share/nginx/html

# Salin konfigurasi template Nginx
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]