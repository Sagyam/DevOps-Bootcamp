FROM nginx:1.27-alpine
RUN rm -f /usr/share/nginx/html/*
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY src/ /usr/share/nginx/html/
EXPOSE 80
