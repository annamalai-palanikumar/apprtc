FROM golang:1.17.5-alpine3.15

RUN apk add --no-cache git curl python2 build-base nginx

RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-367.0.0-linux-x86_64.tar.gz --output gcloud.tar.gz \
    && tar -xf gcloud.tar.gz \
    && google-cloud-sdk/bin/gcloud components install app-engine-python-extras app-engine-python cloud-datastore-emulator --quiet \
    && rm -f gcloud.tar.gz

RUN mkdir -p /home/apprtc

ADD . /home/apprtc/

RUN python /home/apprtc/build/build_app_engine_package.py /home/apprtc/src/ /home/apprtc/out/ \
    && curl https://webrtc.github.io/adapter/adapter-latest.js --output /home/apprtc/src/web_app/js/adapter.js \
    && cp /home/apprtc/src/web_app/js/*.js /home/apprtc/out/js/

RUN echo -e "#!/bin/sh\n" > /go/start.sh \
    && echo -e "`pwd`/google-cloud-sdk/bin/dev_appserver.py --host 0.0.0.0 /home/apprtc/out/app.yaml &\n" >> /go/start.sh

RUN export GOPATH=$HOME/goWorkspace/ \
    && go env -w GO111MODULE=off
    
RUN ln -s /home/apprtc/src/collider/collidermain $GOPATH/src \
    && ln -s /home/apprtc/src/collider/collidertest $GOPATH/src \
    && ln -s /home/apprtc/src/collider/collider $GOPATH/src \
    && cd $GOPATH/src \
    && go get collidermain \
    && go install collidermain

RUN echo -e "$GOPATH/bin/collidermain -port=8089 -tls=false -room-server=http://localhost &\n" >> /go/start.sh
    
RUN ls /home

RUN echo -e "wait -n\n" >> /go/start.sh \
    && echo -e "exit $?\n" >> /go/start.sh \
    && chmod +x /go/start.sh

CMD /go/start.sh