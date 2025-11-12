#!/bin/bash

# Load environment variables from .env file
set -a
source .env
set +a

# Set JVM options
JVM_OPTS="-Xms${JVM_MIN_MEMORY} -Xmx${JVM_MAX_MEMORY}"

# Run the Spring Boot application
java ${JVM_OPTS} \
  -Dserver.port=${SERVER_PORT} \
  -Dspring.datasource.url="jdbc:mysql://localhost:3306/pocket5" \
  -Dspring.datasource.username=${DB_USERNAME} \
  -Dspring.datasource.password=${DB_PASSWORD} \
  -Daes.cbc.iv=${AES_CBC_IV} \
  -Dadmin.user=${ADMIN_USER} \
  -Dadmin.passwd=${ADMIN_PASSWD} \
  -Dserver.url=${SERVER_URL} \
  -Dcors.additional.origins=${CORS_ADDITIONAL_ORIGINS} \
  -Dcors.enable.strict=${CORS_ENABLE_STRICT} \
  -Dcors.header.token=${CORS_HEADER_TOKEN} \
  -Dlogging.level.root=${LOG_LEVEL} \
  -jar pocket-backend/target/pocket-backend-*.jar
