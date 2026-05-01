class IsomorphismEigen < Formula
  desc "Hardware-accelerated C++ tensor math library — Eigen CPU backend"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "3b0c9af0914eb29e23219c89dca1e2519c5451014e64a5aa06f58a209a93b365"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "libomp"
  depends_on "eigen"

  def install
    libomp = Formula["libomp"].opt_prefix
    eigen  = Formula["eigen"].opt_include

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_EIGEN=ON",
      "-DCMAKE_PREFIX_PATH=#{Formula["eigen"].opt_prefix};#{HOMEBREW_PREFIX}",
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp -I#{libomp}/include",
      "-DOpenMP_CXX_LIB_NAMES=omp",
      "-DOpenMP_omp_LIBRARY=#{libomp}/lib/libomp.dylib",
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    eigen = Formula["eigen"].opt_include

    (testpath/"test.cpp").write <<~EOS
      #include <isomorphism/math.hpp>
      #include <vector>
      int main() {
        auto t = isomorphism::math::full({2, 3}, 1.0f, isomorphism::DType::Float32);
        return t.size() == 6 ? 0 : 1;
      }
    EOS

    system ENV.cxx, "-std=c++20", "test.cpp",
           "-I#{include}",
           "-I#{eigen}/eigen3",
           "-L#{lib}", "-lisomorphism_eigen",
           "-o", "test"
    system "./test"
  end
end
