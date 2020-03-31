#!/usr/bin/groovy

@Library(['github.com/indigo-dc/jenkins-pipeline-library@1.2.3']) _

pipeline {
    agent {
        label 'docker-build'
    }

    environment {
        dockerhub_repo = "deephdc/deep-oc-obj_detect_pytorch"
        base_tag = "1.4-cuda10.1-cudnn7-runtime"
        dockerhub_repo_cicd = "deephdc/ci_cd-obj_detect_pytorch"
    }

    stages {
        stage('Validate metadata') {
            steps {
                checkout scm
                sh 'deep-app-schema-validator metadata.json'
            }
        }
        stage('Docker image building and delivery') {
            when {
                allOf {
                    anyOf {
                       branch 'master'
                       branch 'test'
                       buildingTag()
                    }
                    anyOf {
                       changeset 'Dockerfile'
                       changeset 'Jenkinsfile'
                       triggeredBy 'UpstreamCause'
                       triggeredBy 'TimerTrigger'
                       triggeredBy cause: "UserIdCause", detail: "orviz"
                    }
                }
            }
            steps{
                checkout scm
                script {
                    // build different tags
                    id = "${env.dockerhub_repo}"

                    if (env.BRANCH_NAME == 'master') {
                       // CPU (aka latest, i.e. default)
                       // GPU : pytorch allows to run same image on CPU or GPU
                       id_cpu_gpu = DockerBuild(id,
                                                tag: ['latest', 'cpu', 'gpu'], 
                                                build_args: ["tag=${env.base_tag}",
                                                             "branch=master"])
                    }

                    if (env.BRANCH_NAME == 'test') {
                       // CPU + GPU
                       id_cpu_gpu = DockerBuild(id,
                                                tag: ['test', 'cpu-test', 'gpu-test'], 
                                                build_args: ["tag=${env.base_tag}",
                                                             "branch=test"])
                    }


                    DockerPush(id_cpu_gpu)
                }
            }
            post {
                failure {
                    DockerClean()
                }
                always {
                    cleanWs()
                }
            }
        }

        stage('Docker image for CI/CD building and delivery') {
            when {
                allOf {
                    anyOf {
                       branch 'master'
                       branch 'test'
                       buildingTag()
                    }
                    anyOf {
                       changeset 'Dockerfile.cicd'
                       changeset 'Jenkinsfile'
                    }
                }
            }
            steps{
                checkout scm
                script {
                    // build Docker image for CI/CD
                    // default: image=ubuntu, tag=18.04
                    id = "${env.dockerhub_repo_cicd}"
                    if (env.BRANCH_NAME == 'master') {
                       id_cicd = DockerBuild(id,
                                             tag: ['latest', 'master'], 
                                             build_args: ["image=ubuntu",
                                                          "tag=18.04"],
                                             dockerfile_path: "Dockerfile.cicd")
                    }
                    if (env.BRANCH_NAME == 'test') {
                       id_cicd = DockerBuild(id,
                                             tag: ['test'], 
                                             build_args: ["image=ubuntu",
                                                          "tag=18.04"],
                                             dockerfile_path: "Dockerfile.cicd")
                    }

                    DockerPush(id_cicd)
                }
            }
            post {
                failure {
                    DockerClean()
                }
                always {
                    cleanWs()
                }
            }
        }


        stage("Render metadata on the marketplace") {
            when {
                allOf {
                    branch 'master'
                    changeset 'metadata.json'
                }
            }
            steps {
                script {
                    def job_result = JenkinsBuildJob("Pipeline-as-code/deephdc.github.io/pelican")
                    job_result_url = job_result.absoluteUrl
                }
            }
        }
    }
}
