FROM nvcr.io/nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04

# install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common \
    libsm6 cmake ffmpeg git less openjdk-11-jre-headless nano libsm6 libxext6 libxrender-dev \
    curl && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:deadsnakes/ppa &&  \
    apt-get install -y build-essential python3.7 python3.7-dev python3-pip && \
    curl -O https://bootstrap.pypa.io/get-pip.py && \
    python3.7 get-pip.py && \
    rm -rf /var/lib/apt/lists/*

RUN pip3.7 install --upgrade pip
RUN pip3.7 install torch==1.8.1+cu101 torchvision==0.9.1+cu101 torchaudio==0.8.1 \
-f https://download.pytorch.org/whl/torch_stable.html
RUN pip3.7 install torchserve transformers torch-model-archiver nvgpu

# create model-store folder
RUN mkdir -p /home/model-store

# copy model artifacts, custom handler and other dependencies
COPY ./config.properties /home/model-store/
COPY ./dcgan_handler.py /home/model-store/
COPY ./models.zip /home/model-store/
COPY ./DCGAN_fashionGen.pth /home/model-store/

# expose health and prediction listener ports from the image
EXPOSE 5000
EXPOSE 5001

# create model archive file packaging model artifacts and dependencies
RUN torch-model-archiver \
                     --model-name=dcgan.mar \
                     --version=1.0 \
                     --serialized-file=/home/model-store/DCGAN_fashionGen.pth \
                     --handler=/home/model-store/dcgan_handler.py \
                     --extra-files=/home/model-store/models.zip \
                     --export-path=/home/model-store \
                     --force

# run Torchserve HTTP serve to respond to prediction requests
CMD ["sh", "-c", "torchserve --start --ts-config=/home/model-store/config.properties \
--models dcgan.mar --model-store /home/model-store && sleep infinity"]