FROM jenkins/jenkins:lts-alpine-jdk25

# Skip the setup wizard so this boots straight into a configured Jenkins.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Tell the Configuration-as-Code plugin where to find its config.
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml

# Install plugins at build time (so startup needs no update center).
# Comments in plugins.txt are fine; the CLI ignores them.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Seed every job under jobs/ deterministically. Files under
# /usr/share/jenkins/ref are copied into $JENKINS_HOME on first boot,
# even when a volume is mounted.
COPY jobs/ /usr/share/jenkins/ref/jobs/
