## Save the dockers
```
sudo docker save -o ran-base_18.tar ran-base:18
sudo docker save -o ran-build_18.tar ran-build:18
sudo docker save -o oai-gnb_18.tar oai-gnb:18
```
## Spilt a file
```
split --verbose -b99M oai-gnb_latest.tar oai-gnb_latest.tar.
```
## Recombine
```
cat oai-gnb_latest.tar.a? > oai-gnb_latest_18.tar
```
## Create Docker image
```
sudo docker load --input oai-gnb_latest_18.tar
sudo docker tag <Image-ID> oai-gnb:latest
```

