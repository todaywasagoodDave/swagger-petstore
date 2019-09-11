FROM openjdk:8-jre

WORKDIR /petstore
COPY ./jetty-runner* /petstore/jetty-runner.jar
COPY ./run.sh /petstore/
ADD target/swagger-petstore-v2-1.0.1 /petstore/webapp

RUN apt-get update

EXPOSE 8080
CMD ["bash", "/petstore/run.sh"]