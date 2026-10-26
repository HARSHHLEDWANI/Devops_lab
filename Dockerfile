FROM alpine
RUN apk add --no-cache busybox-extras && mkdir -p /www && \
    echo "Payment Settlement Active" > /www/index.html
EXPOSE 80
CMD echo "Payment Settlement Active" && httpd -f -p 80 -h /www
