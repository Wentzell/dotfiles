#!/bin/bash

# Environment settings
module unload devenv
module load devenv/clang-py3-mkl

# Set this variable to your desired install directory
INSTALL_PREFIX=$HOME/opt/triqs_unstable

# Set the number of cores for the compilation
NCORES=40

# Clone the git repositories
git clone github:TRIQS/triqs triqs.src --branch=unstable
git clone github:TRIQS/ctint ctint.src --branch=unstable
git clone github:TRIQS/cthyb cthyb.src --branch=unstable
git clone github:TRIQS/ctseg ctseg.src --branch=unstable
git clone github:TRIQS/tprf tprf.src --branch=unstable
git clone github:TRIQS/dft_tools dft_tools.src --branch=unstable
git clone github:TRIQS/maxent maxent.src --branch=master
git clone github:TRIQS/omegamaxent_interface omegamaxent_interface.src --branch=unstable
#git clone github:TRIQS/w2dynamics_interface w2dynamics_interface.src --branch=unstable

for i in triqs ctint cthyb ctseg tprf dft_tools maxent omegamaxent_interface; do
  # Configure
  mkdir -p $i.build && cd $i.build
  cmake ../$i.src -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX -DBuild_Deps=Always -DBuild_Tests=OFF
  #
  # Build and install
  make -j$NCORES && make install
  cd ../
  #
  source $INSTALL_PREFIX/share/triqsvars.sh
done

find $INSTALL_PREFIX -type d -exec chmod o=rx {} \
find $INSTALL_PREFIX/bin -type f -exec chmod o=rx {} \
find $INSTALL_PREFIX -type f -exec chmod o=r {} \

# w2dynamics separately as we need to build with only one core
git clone github:TRIQS/w2dynamics_interface w2dynamics_interface.src --branch=3.0.x
mkdir -p w2dynamics_interface.build && cd w2dynamics_interface.build
cmake ../w2dynamics_interface.src -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX -DBuild_Deps=Always -DBuild_Tests=OFF
make -j1 && make install
cd ../
