# Baut alles im Image: Der Server braucht nur Docker, kein Node und kein Java.

# Frontend - landet in src/main/resources/static (siehe vite.config.js)
FROM node:22-alpine AS frontend
WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Backend - packt das Frontend mit ins Jar
FROM maven:3.9-eclipse-temurin-21 AS backend
WORKDIR /build
COPY pom.xml ./
COPY src ./src
COPY --from=frontend /build/src/main/resources/static ./src/main/resources/static
RUN mvn -B clean package -DskipTests

# Eclipse Temurin 21 JRE - matches the Java 21 build target.
FROM eclipse-temurin:21-jre-jammy
LABEL authors="johnny"

# Create app directory
WORKDIR /app

# Copy the packaged JAR file into the image
COPY --from=backend /build/target/ssbu-league.jar app.jar

# Expose the port your app runs on
EXPOSE 8080

# Run the JAR with prod profile
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.profiles.active=prod"]
