---
sidebar_position: 1
---

# Basic Gitlab CI-CD pipeline

Here we can see a Gitlab pipeline file that will build and deploy a docs website as Gitlab static pages:

```yaml title="/project-folder/.gitlab-ci.yml"
image: node:18.18.0

stages:
  - build
  - deploy

variables:
  NPM_VERSION: "9.8.1"

cache:
  paths:
    - node_modules/

build:
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - build

pages:
  stage: deploy
  script:
    - rm -rf public
    - mv build public
  artifacts:
    paths:
      - public
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

After pushing some changes the pipeline runned and passed. <br/>

![pipeline](../../static/img/ci-cd-basic-pipelines.png)

As we could see above, there was also an issue during the build phase of one of the previus pipeline runs, but it was fixed.

This is how the page deployed as static Gitlab page looks:

![pipeline2](../../static/img/ci-cd-basic-pipelines-result.png)


<br/>
Here is the same file, but with comments explaining how it works: <br/>


```yaml title="/project-folder/.gitlab-ci.yml"
# Use Node.js 18.18.0 as the base image for all jobs
image: node:18.18.0

# Define the stages of our pipeline in order of execution
stages:
  - build
  - deploy

# Set environment variables for use in the pipeline
variables:
  NPM_VERSION: "9.8.1"  # Specify the version of npm to use

# Configure caching to speed up subsequent pipeline runs
cache:
  paths:
    - node_modules/  # Cache the node_modules directory

# Define the build job
build:
  stage: build  # Assign this job to the build stage
  script:
    - npm ci  # Install dependencies using 'npm ci' for reproducible builds
    - npm run build  # Run the build script defined in package.json
  artifacts:
    paths:
      - build  # Store the build output as an artifact for use in later stages

# Define the deploy job
pages:
  stage: deploy  # Assign this job to the deploy stage
  script:
    - rm -rf public  # Remove existing public directory
    - mv build public  # Rename 'build' directory to 'public' for GitLab Pages
  artifacts:
    paths:
      - public  # Store the public directory as an artifact for GitLab Pages
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Only run on the default branch (e.g., main or master)
```