FROM ubuntu
RUN apt-get update
RUN apt-get install -y python2.7
RUN apt-get install -y python-pip
RUN apt-get install -y build-essential
RUN apt-get install -y python-dev
RUN apt-get install -y libssl-dev
RUN apt-get install -y libffi-dev
RUN apt-get install -y sudo
RUN apt-get install -y git
RUN pip install virtualenv
RUN pip install 'tox!=2.4.0,>=2.3'
RUN pip install 'jenkinsapi'
RUN useradd jenkins --shell /bin/bash --create-home --uid 500
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
