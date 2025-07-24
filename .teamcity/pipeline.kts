// .teamcity/pipeline.kts
// Defines a Docker-based CI/CD pipeline using TeamCity's Kotlin DSL.
// NOTE: The TeamCity agent running this pipeline must have Docker installed and running.

import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.script

// The 'project' block is the root of your configuration.
project {
    // Defines the pipeline itself.
    pipeline {
        // The 'sequence' block defines a series of stages that run one after another.
        sequence {
            // STAGE 1: Build the Docker image from your Dockerfile.
            stage("Build") {
                job("BuildDockerImage", "Build") {
                    steps {
                        script {
                            name = "Build Docker Image"
                            scriptContent = """
                                echo "--- Building Docker image ---"
                                
                                # Build the image using the Dockerfile in the repo root.
                                # We tag it with the TeamCity build number for easy tracking.
                                # Replace 'axiom-collective/cops-and-robbers' with your desired image name.
                                docker build -t axiom-collective/cops-and-robbers:%build.number% .
                                
                                echo "--- Docker image built successfully ---"
                            """.trimIndent()
                        }
                    }
                }
            }

            // STAGE 2: Push the image to a Docker Registry (e.g., Docker Hub, GitLab Registry)
            // This stage is set for manual approval to prevent pushing every single build.
            stage("Push") {
                options {
                    manualApproval()
                }
                job("PushToRegistry", "Push") {
                    steps {
                        script {
                            name = "Push Docker Image to Registry"
                            scriptContent = """
                                echo "--- Logging in to Docker Registry ---"
                                
                                # Login to your container registry.
                                # You must create 'docker.registry.url', 'docker.registry.username', and 'docker.registry.password'
                                # as Parameters in your TeamCity project settings. The password should be of type 'password'.
                                # For Docker Hub, the URL is typically 'docker.io'.
                                docker login %docker.registry.url% -u %docker.registry.username% -p %docker.registry.password%
                                
                                echo "--- Tagging image for registry ---"
                                # Tag the image with the full registry path. For Docker Hub, this would be your username.
                                # e.g., docker.io/yourusername/cops-and-robbers:%build.number%
                                docker tag axiom-collective/cops-and-robbers:%build.number% %docker.registry.url%/%docker.registry.username%/cops-and-robbers:%build.number%
                                
                                echo "--- Pushing image ---"
                                # Push the image.
                                docker push %docker.registry.url%/%docker.registry.username%/cops-and-robbers:%build.number%
                                
                                echo "--- Push Complete ---"
                            """.trimIndent()
                        }
                    }
                }
            }
        }
    }
}
