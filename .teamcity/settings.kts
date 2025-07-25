import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.commitStatusPublisher
import jetbrains.buildServer.configs.kotlin.buildFeatures.investigationsAutoAssigner
import jetbrains.buildServer.configs.kotlin.buildFeatures.perfmon
import jetbrains.buildServer.configs.kotlin.buildFeatures.pullRequests
import jetbrains.buildServer.configs.kotlin.buildSteps.dockerCommand
import jetbrains.buildServer.configs.kotlin.buildSteps.dockerCompose
import jetbrains.buildServer.configs.kotlin.projectFeatures.gitlabIssues
import jetbrains.buildServer.configs.kotlin.triggers.vcs

/*
The settings script is an entry point for defining a TeamCity
project hierarchy. The script should contain a single call to the
project() function with a Project instance or an init function as
an argument.

VcsRoots, BuildTypes, Templates, and subprojects can be
registered inside the project using the vcsRoot(), buildType(),
template(), and subProject() methods respectively.

To debug settings scripts in command-line, run the

    mvnDebug org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate

command and attach your debugger to the port 8000.

To debug in IntelliJ Idea, open the 'Maven Projects' tool window (View
-> Tool Windows -> Maven Projects), find the generate task node
(Plugins -> teamcity-configs -> teamcity-configs:generate), the
'Debug' option is available in the context menu for the task.
*/

version = "2025.07"

project {

    buildType(Build)

    params {
        param("docker.registry.url", "docker.io")
        param("docker.registry.username", "indominus12")
        param("teamcity.internal.pipelines.creation.enabled", "true")
    }

    features {
        gitlabIssues {
            id = "PROJECT_EXT_2"
            displayName = "CNR Issue Tracker"
            repositoryURL = "https://gitlab.axiomrp.dev/the-axiom-collective/cops-and-robbers/"
            authType = accessToken {
                accessToken = "credentialsJSON:d475764b-5ffb-432c-89a4-de48e419f3cd"
            }
        }
    }
}

object Build : BuildType({
    name = "Build"

    publishArtifacts = PublishMode.SUCCESSFUL

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        dockerCommand {
            id = "DockerCommand"
            commandType = build {
                source = file {
                    path = "Dockerfile"
                }
            }
        }
        dockerCompose {
            id = "DockerCompose"
            file = "docker-compose.yml"
        }
    }

    triggers {
        vcs {
        }
    }

    features {
        perfmon {
        }
        commitStatusPublisher {
            publisher = gitlab {
                authType = personalToken {
                    accessToken = "credentialsJSON:d475764b-5ffb-432c-89a4-de48e419f3cd"
                }
            }
        }
        pullRequests {
            vcsRootExtId = "${DslContext.settingsRoot.id}"
            provider = gitlab {
                authType = token {
                    token = "credentialsJSON:d475764b-5ffb-432c-89a4-de48e419f3cd"
                }
            }
        }
        investigationsAutoAssigner {
            defaultAssignee = "indominus"
        }
    }
})
