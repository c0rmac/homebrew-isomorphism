class IsomorphismTorch < Formula
  desc "Hardware-accelerated C++ tensor math library — LibTorch backend"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "3b0c9af0914eb29e23219c89dca1e2519c5451014e64a5aa06f58a209a93b365"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "libomp"
  depends_on "pytorch"
  depends_on "abseil"  # transitive dep of LibTorch protobuf

  def install
    libomp        = Formula["libomp"].opt_prefix
    torch_prefix  = Formula["pytorch"].opt_prefix
    abseil_prefix = Formula["abseil"].opt_prefix

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_TORCH=ON",
      "-DCMAKE_PREFIX_PATH=#{torch_prefix};#{abseil_prefix};#{HOMEBREW_PREFIX}",
      "-Dabsl_DIR=#{abseil_prefix}/lib/cmake/absl",
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp -I#{libomp}/include",
      "-DOpenMP_CXX_LIB_NAMES=omp",
      "-DOpenMP_omp_LIBRARY=#{libomp}/lib/libomp.dylib",
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    torch = Formula["pytorch"].opt_prefix

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
           "-I#{torch}/include",
           "-I#{torch}/include/torch/csrc/api/include",
           "-L#{lib}", "-lisomorphism_torch",
           "-L#{torch}/lib", "-ltorch", "-ltorch_cpu", "-lc10",
           "-o", "test"
    system "./test"
  end
end
