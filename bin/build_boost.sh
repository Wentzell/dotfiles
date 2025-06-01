# ── Build configuration ────────────────────────────────────────────────────────
RELEASE=boost-1.88.0
INSTALL_DIR=$HOME/opt/$RELEASE-$CC
THREADS=40 # adjust to the machine you build on

# ── Obtain the Boost sources ───────────────────────────────────────────────────
git clone https://github.com/boostorg/boost \
          --branch $RELEASE --depth 1 --recursive
cd boost

# ── Configure Boost.Build ──────────────────────────────────────────────────────

# Cf. https://github.com/boostorg/boost/wiki/Getting-Started%3A-Overview#installing-boost
./bootstrap.sh --with-toolset=$CC --with-python=$(which python3)

# Enable automatic MPI detection
echo "using mpi ;" >> project-config.jam   # one-liner that turns MPI on

# ── Build & install ────────────────────────────────────────────────────────────
./b2 toolset=$CC cxxflags="$CXXFLAGS" linkflags="$LDFLAGS" --prefix=$INSTALL_DIR -j$THREADS install
