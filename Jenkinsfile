#!groovy

@Library('github.com/fedora-ci/jenkins-pipeline-library@prototype') _

def imageName = 'quay.io/fedoraci/rpminspect'
def imageTag

def commitId
def gitUrl


pipeline {

    agent {
        label 'fedora-ci-agent'
    }

    stages {
        stage('Init') {
            steps {
                script {
                    shortCommitId = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    gitUrl = getGitUrl()
                }
            }
        }

        stage('Build and Push') {
            steps {
                script {
                    if (isPullRequest()) {
                        imageTag = "pr-${env.CHANGE_ID}"
                    } else {
                        imageTag = shortCommitId
                    }
                }

                buildImageAndPushToRegistry(
                    imageName: imageName,
                    imageTag: imageTag,
                    pushSecret: env.QUAY_PUSH_SECRET_NAME,
                    gitUrl: gitUrl,
                    gitRef: shortCommitId,
                    buildName: 'rpmdeplint-image',
                    openshiftProject: env.OPENSHIFT_PROJECT_NAME
                )
            }
        }

        stage('Test') {
            steps {
                sh('./runtest.sh')
            }
        }
    }

    post { 
        success {
            script {
                if (isPullRequest()) {
                    echo 'TODO: comment on the pull request in GitHub...'
                }
            }
        }
    }
}
