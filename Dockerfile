# Eclipse Temurin 21 JRE - matches the Java 21 build target. A JRE (not JDK) is
# enough since we only run a pre-built jar. The old openjdk:* images are
# deprecated and were Java 17, which cannot run Java 21 bytecode.
FROM eclipse-temurin:21-jre-jammy
LABEL authors="johnny"

# Create app directory
WORKDIR /app

# Copy the packaged JAR file into the image
COPY target/ssbu-league.jar app.jar

# Expose the port your app runs on
EXPOSE 8080

# Run the JAR with prod profile
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.profiles.active=prod"]
