FROM nginx:1.23.3-alpine as runtime
COPY ./build/web /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
