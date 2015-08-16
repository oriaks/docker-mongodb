FROM oriaks/debian:latest
MAINTAINER Michael Richard <michael.richard@oriaks.com>

VOLUME ["/var/lib/mongodb"]
EXPOSE 27017/tcp

COPY entrypoint.sh /entrypoint.sh
RUN ["/entrypoint.sh","install"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["init"]
