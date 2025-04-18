FROM jenkins/inbound-agent:latest-jdk21

 USER root

 # Install Docker CLI, Git, and other dependencies
 RUN apt-get update && apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg \
     lsb-release \
     qemu-user-static \
     binfmt-support \
     sudo \
     git \
     # Add more memory management tools for ARM emulation
     procps \
     sysstat \
     pigz \
     && \
     mkdir -p /etc/apt/keyrings && \
     curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
     $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
     apt-get update && \
     apt-get install -y docker-ce-cli docker-buildx-plugin && \
     apt-get clean

 # Enhanced Git configuration
 RUN git config --system user.email "jenkins@example.com" && \
     git config --system user.name "Jenkins" && \
     git config --system core.longpaths true && \
     git config --system http.sslVerify true && \
     git config --system init.defaultBranch main && \
     git config --system --add safe.directory '*'

 # Create directory for Docker config
 RUN mkdir -p /home/jenkins/.docker && \
     chown -R jenkins:jenkins /home/jenkins/.docker

 # Create workspace directories with proper permissions
 RUN mkdir -p /home/jenkins/agent/workspace && \
     chown -R jenkins:jenkins /home/jenkins/agent && \
     chmod -R 755 /home/jenkins/agent

 # Create a startup script to fix Docker socket permissions and prepare workspace
 RUN echo '#!/bin/bash\n\
 # Fix Docker socket permissions\n\
 if [ -S /var/run/docker.sock ]; then\n\
   DOCKER_GID=$(stat -c "%g" /var/run/docker.sock)\n\
   if [ "$DOCKER_GID" != "0" ]; then\n\
     if ! getent group $DOCKER_GID > /dev/null; then\n\
       groupadd -g $DOCKER_GID docker-external\n\
     fi\n\
     usermod -aG $DOCKER_GID jenkins\n\
   fi\n\
   chmod 666 /var/run/docker.sock\n\
 fi\n\
 \n\
 # Ensure workspace directory exists and has correct permissions\n\
 mkdir -p /home/jenkins/agent/workspace\n\
 chown -R jenkins:jenkins /home/jenkins/agent\n\
 chmod -R 755 /home/jenkins/agent\n\
 \n\
 # Fix Git safe.directory configuration for the workspace\n\
 sudo -u jenkins git config --global --add safe.directory "*"\n\
 sudo -u jenkins git config --global --add safe.directory "/home/jenkins/agent/workspace"\n\
 \n\
 # Verify Git is working properly\n\
 echo "Checking Git configuration:"\n\
 sudo -u jenkins git config --list\n\
 \n\
 # Setup based on AGENT_ROLE environment variable\n\
 if [ "$AGENT_ROLE" = "arm" ]; then\n\
   echo "Running on native ARM hardware, no emulation needed..."\n\
   # Optimize system for native ARM performance\n\
   echo "Optimizing for native ARM execution"\n\
   # Set ARM-specific optimizations if needed\n\
 elif [ "$AGENT_ROLE" = "arm_optimized" ] || [ "$AGENT_ROLE" = "multiarch" ]; then\n\
   echo "Setting up enhanced QEMU for ARM builds..."\n\
   docker run --rm --privileged tonistiigi/binfmt:latest --install arm64 || docker run --rm --privileged multiarch/qemu-user-static --reset -p yes\n\
   # Optimize system for QEMU performance\n\
   echo 10 > /proc/sys/vm/nr_hugepages || true\n\
   echo 1024 > /proc/sys/vm/max_map_count || true\n\
   echo 1 > /proc/sys/vm/overcommit_memory || true\n\
   # Increase shared memory for ARM builds\n\
   mount -o remount,size=4G /dev/shm || true\n\
 fi\n\
 \n\
 # Execute the original entrypoint\n\
 exec /usr/local/bin/jenkins-agent "$@"' > /usr/local/bin/docker-entrypoint.sh && \
     chmod +x /usr/local/bin/docker-entrypoint.sh

 # Add jenkins to sudoers for the startup script
 RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

 # Create a .gitconfig in jenkins home directory
 RUN echo "[user]\n\
     name = Jenkins\n\
     email = jenkins@example.com\n\
 [core]\n\
     longpaths = true\n\
 [safe]\n\
     directory = *" > /home/jenkins/.gitconfig && \
     chown jenkins:jenkins /home/jenkins/.gitconfig

 # Switch back to jenkins user
 USER jenkins

 # Set Docker experimental features and buildkit
 ENV DOCKER_CLI_EXPERIMENTAL=enabled \
     DOCKER_BUILDKIT=1 \
     AGENT_ROLE=multiarch

 # Use our custom entrypoint
 ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
