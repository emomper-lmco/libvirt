#! /bin/bash
#helper script to build and run the containerized libvirt-lmm

CONTAINER="libvirt"
BUILD_ARTIFACTS_LOCATION="./dist/x86_64/"

function destroyContainer () {
    if [ "$(docker ps -f name=$1)" ]
    then
        echo "stopping previous running $1 container..."
        docker kill $1 > /dev/null
        docker rm $1 > /dev/null
        echo "done"
    fi
}

function printHelp () {
    echo "$CONTAINER container make script"
    echo ""
    echo "make.sh [option] [build image] (arguments)"
    echo ""
    echo "options:"
    echo "-h, --help show 	help"
    echo "-b, --build 		build libvirt"
    echo "-c, --command 		run command within running container"
    echo "-d --destroy          destroys running and build containers"
    echo "--rebuild         project rebuild "
    echo ""
    echo "build images:"
    echo "7.5			rhel 7.5 build image"
    echo "7.6			rhel 7.6 build image"
    echo "8			rhel 8 build image"
}

if [ "$#" -eq 0 ]
then
    printHelp
    exit 1
fi

while test $# -gt 0; do
    case "$1" in
        -h|--help)

	    printHelp

	    shift
	    ;;

	-b|--build)

	    shift

	    if [ ! -d dist ]; then
	        mkdir ./dist/
	    fi

        running_containers=$(docker ps -a --format '{{.Names}}')

        if [[ $running_containers != *'$CONTAINER-builder'* ]]
        then
            echo "no running build container run the --rebuild command first."
            exit 1;
        fi

        args="$*"

        if [[ $args == *'coverage'* ]]
        then
            docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) $CONTAINER-builder ./configure --enable-test-coverage --without-dtrace
        fi

        docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) $CONTAINER-builder make $args
        make_status=$?
        if (make_status != 0) 
         then
            exit $make_status
        fi

        if [[ $args == *'rpm'* ]]
        then
            docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) $CONTAINER-builder cp -R $HOME/rpmbuild/RPMS/x86_64 ./dist/
        fi

        docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) $CONTAINER-builder echo -e "\e[32mCurrently in Docker container\e[39m"
        docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) $CONTAINER-builder bash 


	    shift
	    ;;

	-r|--run)

	    destroyContainer $CONTAINER-runner 

        if ! curl http://registry.oa.net/testing/CentOS/7Server/sre-policy-tool-3.6.4-1.el7.x86_64.rpm -o sre-policy-tool.rpm
            then
                echo -e "\e[91mUnable to pull sre-policy-tool rpm\e[39m"
                exit 1
            fi

                $(docker ps -a --format '{{.Names}}')

        if ( [ !  -z "$1" ] && [ "$1" == "7.5" ]  || [ "$1" == "7.6" ] || [ "$1" == "8" ] )
	    then
	        echo -e "\e[91mUsing \e[1m$1 \e[0m\e[91mbuild environment \e[39m "
		docker build -t $CONTAINER-runner --build-arg ENV_VERSION=$1 --no-cache .
	    else
		echo -e "\e[91mUsing \e[1m7.5 \e[0m\e[91mbuild environment \e[39m "
		docker build -t $CONTAINER-runner --build-arg ENV_VERSION=7.5 --no-cache .
	    fi


        if ! docker run -itd --privileged --name $CONTAINER-runner -v "`pwd`/dist:/dist/" $CONTAINER-runner;	
            then
                echo -e "\e[91m$CONTAINER-runner image does not exist run a build then try again\e[39m"
                exit 1
            fi

	    docker exec -it $CONTAINER-runner cp -r $BUILD_ARTIFACTS_LOCATION /dist/

	    echo -e "\e[92m$CONTAINER-runner container running\e[39m"

	    shift
	    ;;

    -c|--command)
        
        running_containers=$(docker ps -a --format '{{.Names}}')
        
        if [[ $2 == "runner" ]]
        then 

            if [[ $running_containers != *$CONTAINER'-runner'* ]]
            then
                echo "no runner containers present run the --run command first."
                exit 1;
            fi

            docker exec -it $CONTAINER-runner "${@:3}"

        else
            if [[ $running_containers != *$CONTAINER'-builder'* ]]
            then
                echo "no running build container run the --config command first."
                exit 1;
            fi
            if [[ $2 == "builder" ]]
            then
                docker exec -u $(id -u ${USER}):$(id -g ${USER}) -it $CONTAINER-builder "${@:3}"
            else
                docker exec -u $(id -u ${USER}):$(id -g ${USER}) -it $CONTAINER-builder "${@:2}"
            fi
        fi

        shift
        ;;

    --rebuild)

        shift

        destroyContainer libvirt-builder

        if ( [ !  -z "$1" ] && [ "$1" == "7.5" ]  || [ "$1" == "7.6" ] || [ "$1" == "8" ] )
	    then
	        echo -e "\e[91mUsing \e[1m$1 \e[0m\e[91mbuild environment \e[39m "
            docker pull registry.oa.net:5000/lmco/builder-base-image/rhel${1}:4.5.0
            docker run -dit  --name libvirt-builder -v $(pwd):/home/builder/:Z -v /mnt:/mnt:Z registry.oa.net:5000/lmco/builder-base-image/rhel${1}:4.5.0 /bin/bash
            
            shift
	    else
		    echo -e "\e[91mUsing \e[1m7.5 \e[0m\e[91mbuild environment \e[39m "
            docker pull registry.oa.net:5000/lmco/builder-base-image/rhel7.5:4.5.0
            docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -dit --name libvirt-builder -v $(pwd):/home/builder/:Z -v /mnt:/mnt:Z registry.oa.net:5000/lmco/builder-base-image/rhel7.5:4.5.0 /bin/bash
	    fi

        add_user='/bin/bash -c "groupadd -g $(id -g ${USER}) $(whoami); adduser -g $(id -g ${USER}) -u $(id -u ${USER}) ${USER}"'

        run_add_user="docker exec -ti libvirt-builder $add_user"
        eval $run_add_user

        #to debug test files
        # docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) libvirt-builder test "alias add-gdb=\"sed -i '/exec.*progdir.*program.*/i gdb \$progdir/\$program' \$1\""
        # docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) libvirt-builder cat /home/josue.martinez/.bashrc
        
        # args="$*"

        # docker exec -ti -u $(id -u ${USER}):$(id -g ${USER}) libvirt-builder ./autogen.sh $args

        shift
        ;;

    -d|--destroy)

          
        if [[ $2 == "runner" ]]
        then 
            destroyContainer $CONTAINER-runner
        else
            destroyContainer $CONTAINER-builder
        fi
        shift
        ;;

	*)
        break
	    ;;

    esac
done

exit 0
