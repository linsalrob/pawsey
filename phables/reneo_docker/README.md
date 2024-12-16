# Creating a singularity image

1. You need a (temporary) machine that you have sudo access to. The best option is to make an AWS or Google Cloud instance. It doesn't need to be huge, althogh I generally increase the disk size so that you have enough additional storage (~100GB)

2. Boot up the image and get docker up and running


```
sudo -H bash
apt install -y docker.io
```

3. Make a directory and create a [Dockerfile](Dockerfile) that will install your code. This example installs Reneo from conda.

4. Build the dockerfile

```
docker build -t reneo .
```

5. Test the docker build

In our install Dockerfile we create several directories in the dockerimage, and we need to link those to real places on the computer. **Note:** the links need to be full paths, not relative links

```
sudo docker run --volume=$PWD/Sim_Phage:/opt/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro reneo reneo run --input /opt/Sim_Phage/assembly_graph_after_simplification.gfa --reads /opt/Sim_Phage/reads/ --output /opt/Sim_Phage/phables
```




    2  ls
    3  docker build -t phables .
    4  ls
    5  docker run --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables test
    6  ls
    7  history
    8  vi Dockerfile 
    9  ls
   10  ls Sim_Phage/
   11  sudo docker run --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables run --input Sim_Phage/assembly_graph_after_simplification.gfa --reads Sim_Phage/reads/ 
   12  sudo docker run --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables test
   13  sudo docker run --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro "phables run --input Sim_Phage/assembly_graph_after_simplification.gfa --reads Sim_Phage/reads/"
   14  sudo docker run --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input Sim_Phage/assembly_graph_after_simplification.gfa --reads Sim_Phage/reads/ 
   15  sudo docker run --volume=Sim_Phage:Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input Sim_Phage/assembly_graph_after_simplification.gfa --reads Sim_Phage/reads/
   16  sudo docker run --volume=Sim_Phage:/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /Sim_Phage/assembly_graph_after_simplification.gfa --reads /Sim_Phage/reads/
   17  sudo docker run --volume=Sim_Phage:/Sim_Phage --volume=Sim_Phage/reads:/Sim_Phage/reads --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /Sim_Phage/assembly_graph_after_simplification.gfa --reads /Sim_Phage/reads/
   18  sudo docker run --volume=Sim_Phage:/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /Sim_Phage/assembly_graph_after_simplification.gfa --reads /Sim_Phage/reads/
   19  sudo docker run --volume=Sim_Phage:/opt/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /opt/Sim_Phage/assembly_graph_after_simplification.gfa --reads /opt/Sim_Phage/reads/
   20  ls Sim_Phage/reads/
   21  sudo docker run --volume=Sim_Phage:/opt/Sim_Phage phables ls /opt
   22  sudo docker run --volume=Sim_Phage:/opt/Sim_Phage phables ls /opt/Sim_Phage
   23  sudo docker run --volume=$PWD/Sim_Phage:/opt/Sim_Phage phables ls /opt/Sim_Phage
   24  sudo docker run --volume=$PWD/Sim_Phage:/opt/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /opt/Sim_Phage/assembly_graph_after_simplification.gfa --reads /opt/Sim_Phage/reads/
   25  ls
   26  mkdir Sim_Phage/phables
   27  sudo docker run --volume=$PWD/Sim_Phage:/opt/Sim_Phage --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro phables phables run --input /opt/Sim_Phage/assembly_graph_after_simplification.gfa --reads /opt/Sim_Phage/reads/ --ouput /opt/Sim_Phage/phables
   29  ls
   30  ls Sim_Phage/
   31  ls Sim_Phage/phables/
   32  less Sim_Phage/phables/config.yaml 
   33  vi Dockerfile 
   34  docker build -t phables .
   35  vi Dockerfile 
   36  docker build -t phables .
   37  vi Dockerfile 
   38  docker build -t phables .
   39  vi Dockerfile 
   40  sudo apt install -y vim
   41  vim Dockerfile 
   42  docker build -t phables .
   43  vi Dockerfile 
   44  docker build -t phables .
   45  ls
   46  sudo shutdown -h now
   47  docker ps
   48  docker images
   49  docker tag phables linsalrob/phables
   50  docker push linsalrob/phables:v0.2_testy
   51  docker push linsalrob/phables
   52  docker tag phables linsalrob/phables:v0.2_testy
   53  docker push linsalrob/phables:v0.2_testy
   54  docker login -u linsalrob
   55  docker push linsalrob/phables:v0.2_testy
   56  ls
   57  less Dockerfile 
   58  history
   59  docker ps
   60  docker images
   61   docker tag phables linsalrob/phables:v0.3_sansconda
   62  docker push linsalrob/phables:v0.3_sansconda
   63  docker tag phables linsalrob/phables:v0.4_sleeky
   64  docker push linsalrob/phables:v0.4_sleeky
   65  docker tag phables linsalrob/phables:v0.5_sneaky_sleeky
   66  docker push linsalrob/phables:v0.5_sneaky_sleeky
   67  docker tag phables linsalrob/phables:v0.6_gogo
   68  docker push linsalrob/phables:v0.6_gogo
   69  history
   70  history > sudo_history


### Deleting all docker images

If you run out of disk space, you can delete all your docker images with this command. Use with care!

```
docker images | awk '{print $3}' | grep -v IM | xargs docker rmi -f {}
```
