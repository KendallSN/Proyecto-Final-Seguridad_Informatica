FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y openssh-server sudo &&     mkdir /var/run/sshd &&     useradd -m -s /bin/bash testuser &&     echo 'testuser:letmein' | chpasswd &&     sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config &&     sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config &&     ssh-keygen -A
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
