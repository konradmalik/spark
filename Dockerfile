# ==================================================================
# module list
# ------------------------------------------------------------------
# python                    3.7    (apt)
# java+scala                8;2.12 (apt)
# Spark+utility             2.4.5  (apt+pip)
# ==================================================================

FROM ubuntu:18.04
ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_INSTALL="apt-get update && apt-get install -y --no-install-recommends --fix-missing"
ENV PIP_INSTALL="python -m pip --no-cache-dir install --upgrade"
ENV GIT_CLONE="git clone --depth 10"

RUN rm -rf /var/lib/apt/lists/* \
           /etc/apt/sources.list.d/cuda.list \
           /etc/apt/sources.list.d/nvidia-ml.list

# ==================================================================
# tools
# ------------------------------------------------------------------
RUN eval $APT_INSTALL \
        build-essential \
        apt-utils \
        ca-certificates \
        sudo \
        wget \
        git \
        vim \
        curl \
        unzip \
        unrar \
        cmake \
		tmux

# ==================================================================
# python
# ------------------------------------------------------------------
ENV PYTHON_COMPAT_VERSION=3.7
RUN eval $APT_INSTALL \
        software-properties-common && \
	add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
	eval $APT_INSTALL \
        python${PYTHON_COMPAT_VERSION} \
        python${PYTHON_COMPAT_VERSION}-dev \
        python3-distutils-extra \
		libblas-dev liblapack-dev libatlas-base-dev gfortran \
        && \
    wget -O ~/get-pip.py \
        https://bootstrap.pypa.io/get-pip.py && \
    python${PYTHON_COMPAT_VERSION} ~/get-pip.py && \
    ln -s /usr/bin/python${PYTHON_COMPAT_VERSION} /usr/local/bin/python3 && \
    ln -s /usr/bin/python${PYTHON_COMPAT_VERSION} /usr/local/bin/python

# ==================================================================
# Java and scala
# ------------------------------------------------------------------
ENV JAVA_VERSION=8
ENV SCALA_VERSION=2.12.11
ENV SCALA_COMPAT_VERSION=2.12
ENV SBT_VERSION=1.3.8
RUN eval $APT_INSTALL \
        openjdk-$JAVA_VERSION-jdk && \
    curl -LO www.scala-lang.org/files/archive/scala-$SCALA_VERSION.deb && \
	dpkg -i scala-$SCALA_VERSION.deb && \
    curl -LO https://bintray.com/artifact/download/sbt/debian/sbt-$SBT_VERSION.deb && \
	dpkg -i sbt-$SBT_VERSION.deb && \
    rm -rf *.deb
ENV JAVA_HOME /usr/lib/jvm/java-$JAVA_VERSION-openjdk-amd64

# ==================================================================
# Spark (with pyspark and koalas)
# ------------------------------------------------------------------
# HADOOP
ENV HADOOP_VERSION 2.10.0
ENV HADOOP_ARCHIVE=https://www-eu.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
ENV HADOOP_HOME /usr/local/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin
RUN curl -sL $HADOOP_ARCHIVE | tar -xz -C /usr/local/

# SPARK
ENV SPARK_VERSION 2.4.5
ENV SPARK_ARCHIVE=https://downloads.apache.org/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-without-hadoop-scala-$SCALA_COMPAT_VERSION.tgz
ENV SPARK_HOME /usr/local/spark-${SPARK_VERSION}-bin-without-hadoop-scala-${SCALA_COMPAT_VERSION}
ENV SPARK_LOG=/tmp
ENV SPARK_HOST=
ENV SPARK_MASTER=
ENV SPARK_WORKER_CORES=
ENV SPARK_WORKER_MEMORY=
ENV PATH $PATH:${SPARK_HOME}/bin
RUN curl -sL $SPARK_ARCHIVE | tar -zx -C /usr/local/

# add here jars necessary to use azure blob storage and amazon s3 with spark
ENV AWS_HADOOP_ARCHIVE=https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/$HADOOP_VERSION/hadoop-aws-$HADOOP_VERSION.jar
# below version must be exact as maven says that above was compiled with!
ENV AWS_VERSION=1.11.271
ENV AWS_ARCHIVE=https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk/$AWS_VERSION/aws-java-sdk-$AWS_VERSION.jar
ENV AZURE_HADOOP_ARCHIVE=https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/$HADOOP_VERSION/hadoop-azure-$HADOOP_VERSION.jar
# below version must be exact as maven says that above was compiled with!
ENV AZURE_VERSION=7.0.0
ENV AZURE_ARCHIVE=https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/$AZURE_VERSION/azure-storage-$AZURE_VERSION.jar
# also add cassandra connector and dependencies
ENV SPARK_CASSANDRA_ARCHIVE=https://repo1.maven.org/maven2/com/datastax/spark/spark-cassandra-connector_$SCALA_COMPAT_VERSION/2.4.3/spark-cassandra-connector_$SCALA_COMPAT_VERSION-2.4.3.jar
ENV TWITTER_ARCHIVE=https://repo1.maven.org/maven2/com/twitter/jsr166e/1.1.0/jsr166e-1.1.0.jar
# add spark excel support
ENV SPARK_EXCEL_ARCHIVE=https://repo1.maven.org/maven2/com/crealytics/spark-excel_$SCALA_COMPAT_VERSION/0.13.1/spark-excel_$SCALA_COMPAT_VERSION-0.13.1.jar
ENV XMLBEANS_ARCHIVE=https://repo1.maven.org/maven2/org/apache/xmlbeans/xmlbeans/3.1.0/xmlbeans-3.1.0.jar
ENV POI_OOXML_SCHEMAS_ARCHIVE=https://repo1.maven.org/maven2/org/apache/poi/poi-ooxml-schemas/4.1.1/poi-ooxml-schemas-4.1.1.jar
RUN cd $SPARK_HOME/jars && \
    curl -LO $AWS_ARCHIVE && \
    curl -LO $AWS_HADOOP_ARCHIVE && \
    curl -LO $AZURE_ARCHIVE && \
    curl -LO $AZURE_HADOOP_ARCHIVE && \
    curl -LO $SPARK_CASSANDRA_ARCHIVE && \
    curl -LO $TWITTER_ARCHIVE && \
    curl -LO $SPARK_EXCEL_ARCHIVE

# Pyspark related stuff
RUN $PIP_INSTALL koalas cassandra-driver
# make sure your PYTHONPATH can find the PySpark and Py4J under $SPARK_HOME/python/lib:
RUN cp $(ls $SPARK_HOME/python/lib/py4j*) $SPARK_HOME/python/lib/py4j-src.zip
ENV PYTHONPATH $SPARK_HOME/python/lib/pyspark.zip:$SPARK_HOME/python/lib/py4j-src.zip:$PYTHONPATH

# ==================================================================
# config & cleanup
# ------------------------------------------------------------------
RUN ldconfig && \
    apt-get clean && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* ~/*

# add default user
ENV DEFAULT_USER=spark
COPY scripts/add-user.sh add-user.sh
RUN chmod +x add-user.sh && ./add-user.sh $DEFAULT_USER

# make spark dir owned by that user
RUN chown -R $DEFAULT_USER:$DEFAULT_USER $SPARK_HOME

# Add Tini and entrypoint
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /tini && chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/tini", "--", "/docker-entrypoint.sh"]

# copy run scripts
COPY scripts/run-* /
RUN chmod +x /run-*

# run as non-root
USER $DEFAULT_USER

# spark ui
EXPOSE 4040
# spark master
EXPOSE 7077
# spark worker
EXPOSE 8081