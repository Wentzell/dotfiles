# Install dir
PREFIX=~/opt/python3_mkl

# Set Up Proper Build Environment
export PYTHONPATH=$PREFIX:$PYTHONPATH
export CC=clang
export CXX=clang++
export FC=gfortran
export CXXFLAGS="-fopenmp -stdlib=libc++ -O3 -march=broadwell -fPIC"
export CFLAGS="-fopenmp -O3 -march=broadwell -fPIC"
export FFLAGS="-fopenmp -O3 -march=broadwell -fPIC"
export LDFLAGS="-fPIC -shared"

NCORES=40

# C.f. https://software.intel.com/content/www/us/en/develop/articles/numpyscipy-with-intel-mkl.html

# Numpy Install
rm -r numpy-*
NPY_VER=1.21.1
wget https://github.com/numpy/numpy/releases/download/v$NPY_VER/numpy-$NPY_VER.tar.gz
tar -xvf numpy-$NPY_VER.tar.gz
cd numpy-$NPY_VER
ln -s ../site.cfg
python setup.py build -j$NCORES install --prefix=$PREFIX
cd ../

# Scipy Install
rm -r scipy-*
SCPY_VER=1.7.1
wget https://github.com/scipy/scipy/releases/download/v$SCPY_VER/scipy-$SCPY_VER.tar.gz
tar -xvf scipy-$SCPY_VER.tar.gz
cd scipy-$SCPY_VER
ln -s ../site.cfg
python setup.py build -j$NCORES install --prefix=$PREFIX
cd ../
