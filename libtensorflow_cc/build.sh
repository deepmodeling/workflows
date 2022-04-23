#!/bin/bash

set -ex


export PREFIX=/usr/local
export SRC_DIR=/tensorflow
export cuda_compiler_version=None
curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.11.0/bazelisk-linux-amd64 --output $PREFIX/bin/bazel
chmod +x $PREFIX/bin/bazel

git clone https://github.com/tensorflow/tensorflow $SRC_DIR -b v2.8.0 --depth 1

cd $SRC_DIR

#sed -i -e "s/GRPCIO_VERSION/${grpc_cpp}/" tensorflow/tools/pip_package/setup.py

# do not build with MKL support
export TF_NEED_MKL=1
export BAZEL_MKL_OPT=""

mkdir -p ./bazel_output_base
export BAZEL_OPTS=""
export CC_OPT_FLAGS="${CFLAGS}"

# Quick debug:
# cp -r ${RECIPE_DIR}/build.sh . && bazel clean && bash -x build.sh --logging=6 | tee log.txt
# Dependency graph:
# bazel query 'deps(//tensorflow/tools/lib_package:libtensorflow)' --output graph > graph.in
export LDFLAGS="${LDFLAGS} -lrt"


# If you really want to see what is executed, add --subcommands
BUILD_OPTS="
    --logging=6
    --verbose_failures
    --config=opt
	--config=mkl
    --define=PREFIX=${PREFIX}
    --config=noaws
	--copt=-mtune=generic
	--local_ram_resources=2048
	--local_cpu_resources=4
	"

export TF_ENABLE_XLA=0
export BUILD_TARGET="//tensorflow:libtensorflow_cc.so"

# Python settings
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_CUDA_CLANG=0
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0

# Get rid of unwanted defaults


if [[ ${cuda_compiler_version} != "None" ]]; then
    export GCC_HOST_COMPILER_PATH="${GCC}"
    export GCC_HOST_COMPILER_PREFIX="$(dirname ${GCC})"

    export TF_CUDA_PATHS="${PREFIX},/usr/local/cuda,/usr"
    export TF_NEED_CUDA=1
    export TF_CUDA_VERSION="${cuda_compiler_version}"
    export TF_CUDNN_VERSION="${cudnn}"
    export TF_NCCL_VERSION=$(pkg-config nccl --modversion | grep -Po '\d+\.\d+')

    export LDFLAGS="${LDFLAGS//-Wl,-z,now/-Wl,-z,lazy}"
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell"

    if [[ ${cuda_compiler_version} == 10.* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,compute_75
    elif [[ ${cuda_compiler_version} == 11.0* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,sm_80,compute_80
    elif [[ ${cuda_compiler_version} == 11.1 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,sm_80,sm_86,compute_86
    elif [[ ${cuda_compiler_version} == 11.2 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,sm_80,sm_86,compute_86
    elif [[ ${cuda_compiler_version} == 11.3 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,sm_80,sm_86,compute_86
    else
        echo "unsupported cuda version."
        exit 1
    fi
fi

./configure

# build using bazel
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} ${BUILD_TARGET}

# build a whl file

#cp $SRC_DIR/bazel-bin/tensorflow/tools/lib_package/libtensorflow.tar.gz $SRC_DIR
mkdir -p $SRC_DIR/libtensorflow_cc_output/lib
cp -d bazel-bin/tensorflow/libtensorflow_cc.so* $SRC_DIR/libtensorflow_cc_output/lib/
cp -d bazel-bin/tensorflow/libtensorflow_framework.so* $SRC_DIR/libtensorflow_cc_output/lib/
cp -d $SRC_DIR/libtensorflow_cc_output/lib/libtensorflow_framework.so.2 $SRC_DIR/libtensorflow_cc_output/lib/libtensorflow_framework.so
# Copy openmp libraries
cp -d bazel-out/k8-opt/bin/external/llvm_openmp/libiomp5.so $SRC_DIR/libtensorflow_cc_output/lib/libiomp5.so
# Make writable so patchelf can do its magic
chmod u+w $SRC_DIR/libtensorflow_cc_output/lib/libtensorflow*

mkdir -p $SRC_DIR/libtensorflow_cc_output/include/tensorflow
rsync -avzh --exclude '_virtual_includes/' --exclude 'pip_package/' --exclude 'lib_package/' --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-bin/ $SRC_DIR/libtensorflow_cc_output/include
rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/cc $SRC_DIR/libtensorflow_cc_output/include/tensorflow/
rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/core $SRC_DIR/libtensorflow_cc_output/include/tensorflow/
rsync -avzh --include '*/' --include '*' --exclude '*.cc' third_party/ $SRC_DIR/libtensorflow_cc_output/include/third_party/
rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-tensorflow/external/eigen_archive/Eigen/ $SRC_DIR/libtensorflow_cc_output/include/Eigen/
rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-tensorflow/external/eigen_archive/unsupported/ $SRC_DIR/libtensorflow_cc_output/include/unsupported/
rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-tensorflow/external/com_google_protobuf/src/google/ $SRC_DIR/libtensorflow_cc_output/include/google/
rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-tensorflow/external/com_google_absl/absl/ $SRC_DIR/libtensorflow_cc_output/include/absl/
pushd $SRC_DIR/libtensorflow_cc_output
  tar cf ../libtensorflow_cc_output.tar .
popd
chmod -R u+rw $SRC_DIR/libtensorflow_cc_output
rm -r $SRC_DIR/libtensorflow_cc_output

tar -C ${PREFIX} -xf $SRC_DIR/libtensorflow_cc_output.tar
rm -rf $SRC_DIR
rm -rf ~/.cache
